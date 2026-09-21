"""Security regression audit of the database boundary, against the DISPOSABLE
database (never the dev project or production).

What it locks down, in the order the checks appear:

1. Inventory  -- the exact set of `public` tables, and that RLS is on for all.
2. Privileges -- table x role x privilege for anon, authenticated,
   beerapp_backend and beerapp_seed; nothing granted to PUBLIC.
3. Roles      -- least-privilege attributes, no role memberships.
4. Policies   -- the exact set of RLS policies per table.
5. Behaviour  -- the catalog is unwritable by beerapp_backend; contributions are
   SELECT+INSERT only; owner-only rows on every user-owned table; anon /
   authenticated are locked out of the API-only tables; profiles owner-only.
6. Cascades   -- every user-owned FK to auth.users cascades (account deletion).
7. Contract   -- the FK / unique constraint NAMES the Stage 2 error translation
   depends on exist, and real violations translate as the services expect.
8. Functions  -- every function in `private`: fixed search_path on SECURITY
   DEFINER, intended EXECUTE grants only, and nothing unintended reachable now
   that beerapp_backend has USAGE on schema `private`.

A NEW table, function or policy makes these fail until it is reviewed and added
to the audited lists below -- that is the point.

Limitation: run against a PostgreSQL scaffold, not a full Supabase project (see
docs/DATABASE.md). The scaffold reproduces Supabase's default privileges on new
`public` tables, so the migrations' explicit REVOKEs are tested against them.
"""

from uuid import UUID, uuid4

import asyncpg
import pytest

from app.errors import NotFoundError, SessionInvalidError
from app.schemas.contributions import BeerContributionCreate
from app.services import beer_logs as beer_logs_service
from app.services import collection as collection_service
from app.services import contributions as contributions_service
from app.services.db_errors import translate_beer_write_foreign_key_violation

from .disposable_db import run_rolled_back

pytestmark = pytest.mark.integration

_USER_A = "aaaaaaaa-0000-4000-8000-00000000000a"
_USER_B = "bbbbbbbb-0000-4000-8000-00000000000b"
_MISSING_USER = "cccccccc-0000-4000-8000-00000000000c"  # never in auth.users
_MISSING_ID = UUID("dddddddd-0000-4000-8000-00000000000d")

ROLES = ("anon", "authenticated", "beerapp_backend", "beerapp_seed")
PRIVILEGES = ("SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER")
_COLUMN_LEVEL = ("SELECT", "INSERT", "UPDATE", "REFERENCES")

CATALOG = ("countries", "beer_styles", "breweries", "beers")
FULL_ACCESS_OWNED = ("user_beer_logs", "user_beer_collection")
INSERT_ONLY_OWNED = ("user_achievements", "beer_contributions", "brewery_contributions")
BACKEND_OWNED = FULL_ACCESS_OWNED + INSERT_ONLY_OWNED
ALL_TABLES = CATALOG + BACKEND_OWNED + ("profiles",)

# -- helpers ----------------------------------------------------------------------


async def _denied(conn: asyncpg.Connection, sql: str, *args) -> None:
    """The statement must fail with insufficient_privilege (a missing grant AND a
    row-level-security violation both use SQLSTATE 42501). A savepoint keeps the
    surrounding transaction usable afterwards."""
    with pytest.raises(asyncpg.InsufficientPrivilegeError):
        async with conn.transaction():
            await conn.execute(sql, *args)


async def _as(conn: asyncpg.Connection, role: str) -> None:
    await conn.execute(f"set local role {role}")


async def _identity(conn: asyncpg.Connection, user_id: str | None) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id or "")


def _expected_privileges() -> dict[str, dict[str, set[str]]]:
    expected = {role: {table: set() for table in ALL_TABLES} for role in ROLES}
    expected["authenticated"]["profiles"] = {"SELECT", "UPDATE"}  # direct-Supabase table
    for table in CATALOG:
        expected["beerapp_backend"][table] = {"SELECT"}
        expected["beerapp_seed"][table] = {"SELECT", "INSERT", "UPDATE", "DELETE"}
    for table in FULL_ACCESS_OWNED:
        expected["beerapp_backend"][table] = {"SELECT", "INSERT", "UPDATE", "DELETE"}
    for table in INSERT_ONLY_OWNED:
        expected["beerapp_backend"][table] = {"SELECT", "INSERT"}
    return expected


# -- 1. inventory -------------------------------------------------------------------


def test_public_schema_contains_exactly_the_audited_tables_and_nothing_else(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select relname, relkind::text as kind from pg_class "
            "where relnamespace = 'public'::regnamespace and relkind in ('r','p','v','m','f','S')"
        )
        assert {r["relname"] for r in rows if r["kind"] in ("r", "p")} == set(ALL_TABLES)
        # A view would run with its OWNER's rights and sidestep RLS; a sequence or a
        # foreign table is an unaudited grant surface. None may exist.
        assert [r["relname"] for r in rows if r["kind"] not in ("r", "p")] == []

    run_rolled_back(integration_dsn, body)


def test_row_level_security_is_enabled_on_every_public_table(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select relname, relrowsecurity from pg_class "
            "where relnamespace = 'public'::regnamespace and relkind = 'r'"
        )
        assert {r["relname"]: r["relrowsecurity"] for r in rows} == {t: True for t in ALL_TABLES}

    run_rolled_back(integration_dsn, body)


# -- 2. privileges --------------------------------------------------------------------


@pytest.mark.parametrize("role", ROLES)
def test_table_privileges_match_the_audited_matrix(integration_dsn, role):
    async def body(conn):
        actual: dict[str, set[str]] = {}
        for table in ALL_TABLES:
            granted = set()
            for privilege in PRIVILEGES:
                has = await conn.fetchval(
                    "select has_table_privilege($1, $2, $3)", role, f"public.{table}", privilege
                )
                if not has and privilege in _COLUMN_LEVEL:
                    # a column-level grant would not show up as a table privilege
                    has = await conn.fetchval(
                        "select has_any_column_privilege($1, $2, $3)",
                        role,
                        f"public.{table}",
                        privilege,
                    )
                if has:
                    granted.add(privilege)
            actual[table] = granted
        assert actual == _expected_privileges()[role]

    run_rolled_back(integration_dsn, body)


def test_nothing_in_public_is_granted_to_the_public_pseudo_role(integration_dsn):
    async def body(conn):
        offenders = await conn.fetch(
            "select c.relname from pg_class c, aclexplode(c.relacl) a "
            "where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' "
            "and a.grantee = 0"
        )
        assert offenders == []
        column_offenders = await conn.fetch(
            "select c.relname, att.attname from pg_attribute att "
            "join pg_class c on c.oid = att.attrelid, aclexplode(att.attacl) a "
            "where c.relnamespace = 'public'::regnamespace and a.grantee = 0"
        )
        assert column_offenders == []

    run_rolled_back(integration_dsn, body)


# -- 3. roles --------------------------------------------------------------------------


@pytest.mark.parametrize("role", ["beerapp_backend", "beerapp_seed"])
def test_service_roles_are_least_privilege(integration_dsn, role):
    async def body(conn):
        attrs = await conn.fetchrow(
            "select rolsuper, rolcreatedb, rolcreaterole, rolbypassrls, rolreplication, "
            "rolcanlogin from pg_roles where rolname = $1",
            role,
        )
        assert dict(attrs) == {
            "rolsuper": False,
            "rolcreatedb": False,
            "rolcreaterole": False,
            "rolbypassrls": False,
            "rolreplication": False,
            "rolcanlogin": True,
        }
        # Membership would inherit privileges and silently invalidate the matrix.
        memberships = await conn.fetch(
            "select roleid::regrole::text as granted from pg_auth_members "
            "where member = $1::regrole",
            role,
        )
        assert memberships == []

    run_rolled_back(integration_dsn, body)


@pytest.mark.parametrize("role", ["anon", "authenticated"])
def test_supabase_client_roles_cannot_bypass_rls_or_login_directly(integration_dsn, role):
    async def body(conn):
        attrs = await conn.fetchrow(
            "select rolsuper, rolbypassrls, rolcanlogin from pg_roles where rolname = $1", role
        )
        assert dict(attrs) == {"rolsuper": False, "rolbypassrls": False, "rolcanlogin": False}

    run_rolled_back(integration_dsn, body)


# -- 4. policies ------------------------------------------------------------------------

_EXPECTED_POLICIES = (
    {
        ("beer_contributions", "backend_insert_own", "INSERT", "{beerapp_backend}"),
        ("beer_contributions", "backend_select_own", "SELECT", "{beerapp_backend}"),
        ("brewery_contributions", "backend_insert_own", "INSERT", "{beerapp_backend}"),
        ("brewery_contributions", "backend_select_own", "SELECT", "{beerapp_backend}"),
        ("user_achievements", "backend_insert_own", "INSERT", "{beerapp_backend}"),
        ("user_achievements", "backend_select_own", "SELECT", "{beerapp_backend}"),
        ("user_beer_logs", "backend_owns_rows", "ALL", "{beerapp_backend}"),
        ("user_beer_collection", "backend_owns_rows", "ALL", "{beerapp_backend}"),
        ("profiles", "select_own", "SELECT", "{public}"),
        ("profiles", "update_own", "UPDATE", "{public}"),
    }
    | {(t, "select_for_backend", "SELECT", "{beerapp_backend}") for t in CATALOG}
    | {(t, "write_for_seed", "ALL", "{beerapp_seed}") for t in CATALOG}
)


def test_rls_policies_are_exactly_the_audited_set(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select tablename, policyname, cmd, roles::text as roles from pg_policies "
            "where schemaname = 'public'"
        )
        assert {(r["tablename"], r["policyname"], r["cmd"], r["roles"]) for r in rows} == (
            _EXPECTED_POLICIES
        )

    run_rolled_back(integration_dsn, body)


def test_owner_policies_are_keyed_on_the_request_identity_not_a_blanket_true(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select tablename, policyname, qual, with_check from pg_policies "
            "where schemaname = 'public'"
        )
        for row in rows:
            table, policy = row["tablename"], row["policyname"]
            expression = f"{row['qual'] or ''} {row['with_check'] or ''}"
            if table in BACKEND_OWNED:
                assert "app.user_id" in expression, f"{table}.{policy} is not owner-scoped"
                assert "true" not in (row["qual"] or "").replace("true)", ""), (table, policy)
            elif table == "profiles":
                assert "auth.uid()" in expression, f"{table}.{policy} is not owner-scoped"
            if table.endswith("_contributions") and policy == "backend_insert_own":
                assert "pending" in expression, f"{table} insert is not pinned to 'pending'"

    run_rolled_back(integration_dsn, body)


# -- 5. behaviour ---------------------------------------------------------------------------


@pytest.mark.parametrize("table", CATALOG)
def test_the_backend_role_cannot_write_the_canonical_catalog(integration_dsn, table):
    async def body(conn):
        await _as(conn, "beerapp_backend")
        await _denied(conn, f"insert into public.{table} default values")
        await _denied(conn, f"update public.{table} set created_at = created_at")
        await _denied(conn, f"delete from public.{table}")
        await _denied(conn, f"truncate public.{table}")
        # ...but it can read (that is the whole point of the role).
        await conn.fetch(f"select 1 from public.{table} limit 1")

    run_rolled_back(integration_dsn, body)


def test_the_seed_role_can_write_the_catalog_but_touches_no_user_data(integration_dsn):
    async def body(conn):
        await _as(conn, "beerapp_seed")
        await conn.execute(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Seed Test Land', 'Europe')"
        )
        for table in BACKEND_OWNED + ("profiles",):
            await _denied(conn, f"select 1 from public.{table}")

    run_rolled_back(integration_dsn, body)


@pytest.mark.parametrize("table", ["beer_contributions", "brewery_contributions"])
def test_contribution_tables_are_select_and_insert_only_for_the_backend_role(
    integration_dsn, table
):
    async def body(conn):
        await _as(conn, "beerapp_backend")
        await _identity(conn, _USER_A)
        await conn.fetch(f"select 1 from public.{table} limit 1")  # SELECT is allowed
        await _denied(conn, f"update public.{table} set created_at = created_at")
        await _denied(conn, f"delete from public.{table}")
        await _denied(conn, f"truncate public.{table}")

    run_rolled_back(integration_dsn, body, users=(_USER_A,))


@pytest.mark.parametrize("role", ["anon", "authenticated"])
@pytest.mark.parametrize("table", [t for t in ALL_TABLES if t != "profiles"])
def test_client_roles_have_no_access_to_any_api_only_table(integration_dsn, role, table):
    async def body(conn):
        await _as(conn, role)
        await _denied(conn, f"select 1 from public.{table}")
        await _denied(conn, f"insert into public.{table} default values")
        await _denied(conn, f"delete from public.{table}")

    run_rolled_back(integration_dsn, body)


async def _seed_one_row_per_owned_table(conn, user_id: str, beer_id, tag: str) -> None:
    await conn.execute(
        "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)", user_id, beer_id
    )
    await conn.execute(
        "insert into public.user_beer_collection (user_id, beer_id, is_favorite, favorited_at) "
        "values ($1, $2, true, now())",
        user_id,
        beer_id,
    )
    await conn.execute(
        "insert into public.user_achievements (user_id, achievement_key) values ($1, $2)",
        user_id,
        f"audit_{tag}",
    )
    await conn.execute(
        "insert into public.beer_contributions (user_id, official_name, proposed_brewery_name) "
        "values ($1, $2, 'Some Brewery')",
        user_id,
        f"Audit Beer {tag}",
    )
    await conn.execute(
        "insert into public.brewery_contributions (user_id, name, proposed_country_name) "
        "values ($1, $2, 'Some Land')",
        user_id,
        f"Audit Brewery {tag}",
    )


async def _seed_catalog_beer(conn) -> UUID:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Audit Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Audit Brewery', $1) returning id",
        country_id,
    )
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ('Audit Beer', $1) "
        "returning id",
        brewery_id,
    )


def test_every_user_owned_table_is_owner_only_for_the_backend_role(integration_dsn):
    async def body(conn):
        beer_id = await _seed_catalog_beer(conn)
        await _seed_one_row_per_owned_table(conn, _USER_A, beer_id, "a")
        await _seed_one_row_per_owned_table(conn, _USER_B, beer_id, "b")

        await _as(conn, "beerapp_backend")
        for table in BACKEND_OWNED:
            # Deliberately NO `where user_id`: RLS alone must scope the result.
            await _identity(conn, _USER_A)
            owners = {r["user_id"] for r in await conn.fetch(f"select user_id from public.{table}")}
            assert owners == {UUID(_USER_A)}, f"{table} leaked another user's rows"

            await _identity(conn, None)
            assert await conn.fetch(f"select 1 from public.{table}") == [], (
                f"{table} visible with no identity"
            )

            # A row owned by someone else cannot be forged.
            await _identity(conn, _USER_A)
            forged = {
                "user_beer_logs": ("insert into public.user_beer_logs (user_id, beer_id) "
                                   "values ($1, $2)", (_USER_B, beer_id)),
                "user_beer_collection": ("insert into public.user_beer_collection "
                                         "(user_id, beer_id, is_favorite, favorited_at) "
                                         "values ($1, $2, true, now())", (_USER_B, beer_id)),
                "user_achievements": ("insert into public.user_achievements "
                                      "(user_id, achievement_key) values ($1, 'forged')",
                                      (_USER_B,)),
                "beer_contributions": ("insert into public.beer_contributions "
                                       "(user_id, official_name, proposed_brewery_name) "
                                       "values ($1, 'Forged', 'X')", (_USER_B,)),
                "brewery_contributions": ("insert into public.brewery_contributions "
                                          "(user_id, name, proposed_country_name) "
                                          "values ($1, 'Forged', 'X')", (_USER_B,)),
            }[table]  # fmt: skip
            await _denied(conn, forged[0], *forged[1])

        # Update/delete where the table allows them: someone else's rows are untouched.
        for table in FULL_ACCESS_OWNED:
            await _identity(conn, _USER_A)
            assert await conn.execute(
                f"delete from public.{table} where user_id = $1", _USER_B
            ) == ("DELETE 0")

    run_rolled_back(integration_dsn, body, users=(_USER_A, _USER_B))


def test_profiles_are_owner_only_for_authenticated_and_closed_to_anon(integration_dsn):
    async def body(conn):
        assert await conn.fetchval("select count(*) from public.profiles") == 2

        await _as(conn, "authenticated")
        await conn.execute("select set_config('request.jwt.claim.sub', $1, true)", _USER_A)
        visible = {r["id"] for r in await conn.fetch("select id from public.profiles")}
        assert visible == {UUID(_USER_A)}
        assert (
            await conn.execute(
                "update public.profiles set display_name = 'hijack' where id = $1", _USER_B
            )
            == "UPDATE 0"
        )
        assert (
            await conn.execute(
                "update public.profiles set display_name = 'mine' where id = $1", _USER_A
            )
            == "UPDATE 1"
        )
        await _denied(conn, "insert into public.profiles (id) values ($1)", str(uuid4()))
        await _denied(conn, "delete from public.profiles")

        await conn.execute("reset role")
        await _as(conn, "anon")
        await _denied(conn, "select 1 from public.profiles")

    run_rolled_back(integration_dsn, body, users=(_USER_A, _USER_B))


# -- 6. cascades: account deletion ---------------------------------------------------------


_EXPECTED_USER_FOREIGN_KEYS = {
    ("beer_contributions", "beer_contributions_user_id_fkey"),
    ("brewery_contributions", "brewery_contributions_user_id_fkey"),
    ("profiles", "profiles_id_fkey"),
    ("user_achievements", "user_achievements_user_id_fkey"),
    ("user_beer_collection", "user_beer_collection_user_id_fkey"),
    ("user_beer_logs", "user_beer_logs_user_id_fkey"),
}


def test_every_foreign_key_to_auth_users_cascades_and_none_is_unaudited(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select conrelid::regclass::text as tbl, conname, confdeltype::text as rule "
            "from pg_constraint where contype = 'f' and confrelid = 'auth.users'::regclass"
        )
        assert {(r["tbl"], r["conname"]) for r in rows} == _EXPECTED_USER_FOREIGN_KEYS
        assert {r["rule"] for r in rows} == {"c"}  # ON DELETE CASCADE, all of them

    run_rolled_back(integration_dsn, body)


def test_deleting_an_auth_user_removes_every_row_the_user_owns(integration_dsn):
    """The behaviour behind DELETE /account: the Supabase Admin API deletes the
    auth.users row and the database does the rest."""

    async def body(conn):
        beer_id = await _seed_catalog_beer(conn)
        await _seed_one_row_per_owned_table(conn, _USER_A, beer_id, "a")
        await _seed_one_row_per_owned_table(conn, _USER_B, beer_id, "b")
        owned = BACKEND_OWNED + ("profiles",)

        async def count(table: str, user_id: str) -> int:
            column = "id" if table == "profiles" else "user_id"
            return await conn.fetchval(
                f"select count(*) from public.{table} where {column} = $1", user_id
            )

        for table in owned:
            assert await count(table, _USER_A) == 1, f"setup: no {table} row for A"

        await conn.execute("delete from auth.users where id = $1", _USER_A)

        for table in owned:
            assert await count(table, _USER_A) == 0, f"{table} survived account deletion"
            assert await count(table, _USER_B) == 1, f"{table}: another user's row was removed"
        # The canonical catalog is untouched by deleting a user.
        assert await conn.fetchval("select count(*) from public.beers where id = $1", beer_id) == 1

    run_rolled_back(integration_dsn, body, users=(_USER_A, _USER_B))


# -- 7. the constraint-name contract behind Stage 2's error translation ----------------------


_FOREIGN_KEY_CONTRACT = [
    # (constraint, table, column, referenced table)
    ("user_beer_logs_beer_id_fkey", "user_beer_logs", "beer_id", "beers"),
    ("user_beer_logs_user_id_fkey", "user_beer_logs", "user_id", "users"),
    ("user_beer_collection_beer_id_fkey", "user_beer_collection", "beer_id", "beers"),
    ("user_beer_collection_user_id_fkey", "user_beer_collection", "user_id", "users"),
    ("beer_contributions_user_id_fkey", "beer_contributions", "user_id", "users"),
    ("beer_contributions_brewery_id_fkey", "beer_contributions", "brewery_id", "breweries"),
    ("beer_contributions_style_id_fkey", "beer_contributions", "style_id", "beer_styles"),
    ("brewery_contributions_user_id_fkey", "brewery_contributions", "user_id", "users"),
    ("brewery_contributions_country_id_fkey", "brewery_contributions", "country_id", "countries"),
]


@pytest.mark.parametrize("name,table,column,referenced", _FOREIGN_KEY_CONTRACT)
def test_the_foreign_key_names_the_services_translate_exist(
    integration_dsn, name, table, column, referenced
):
    async def body(conn):
        row = await conn.fetchrow(
            "select conrelid::regclass::text as tbl, confrelid::regclass::text as ref, "
            "(select attname from pg_attribute where attrelid = conrelid and attnum = conkey[1]) "
            "as col from pg_constraint where conname = $1 and contype = 'f'",
            name,
        )
        assert row is not None, f"foreign key {name} does not exist"
        assert (row["tbl"], row["col"]) == (table, column)
        assert row["ref"].split(".")[-1] == referenced

    run_rolled_back(integration_dsn, body)


def test_the_service_constants_agree_with_the_database(integration_dsn):
    async def body(conn):
        names = {r["conname"] for r in await conn.fetch("select conname from pg_constraint")}
        assert beer_logs_service._BEER_FOREIGN_KEY in names
        assert collection_service._BEER_FOREIGN_KEY in names
        assert set(contributions_service._FOREIGN_KEY_ENTITY) <= names

        unique_indexes = {
            r["indexname"]
            for r in await conn.fetch(
                "select indexname from pg_indexes where schemaname = 'public' "
                "and indexdef like 'CREATE UNIQUE INDEX%'"
            )
        }
        assert set(contributions_service._OWN_DUPLICATE_INDEXES) <= unique_indexes

    run_rolled_back(integration_dsn, body)


async def _capture_fk_violation(conn, sql: str, *args) -> asyncpg.ForeignKeyViolationError:
    try:
        async with conn.transaction():
            await conn.execute(sql, *args)
    except asyncpg.ForeignKeyViolationError as exc:
        return exc
    raise AssertionError("expected a foreign key violation")


@pytest.mark.parametrize(
    "table,constraint_prefix,insert_sql",
    [
        (
            "user_beer_logs",
            "user_beer_logs",
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
        ),
        (
            "user_beer_collection",
            "user_beer_collection",
            "insert into public.user_beer_collection (user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
        ),
    ],
)
def test_real_violations_on_personal_tables_translate_as_the_services_expect(
    integration_dsn, table, constraint_prefix, insert_sql
):
    beer_constraint = (
        beer_logs_service._BEER_FOREIGN_KEY
        if table == "user_beer_logs"
        else collection_service._BEER_FOREIGN_KEY
    )

    async def body(conn):
        beer_id = await _seed_catalog_beer(conn)
        await _as(conn, "beerapp_backend")

        # A still-valid token for a DELETED account: the caller's user row is gone.
        await _identity(conn, _MISSING_USER)
        deleted_account = await _capture_fk_violation(conn, insert_sql, _MISSING_USER, beer_id)
        assert deleted_account.constraint_name == f"{constraint_prefix}_user_id_fkey"
        translated = translate_beer_write_foreign_key_violation(
            deleted_account, beer_constraint=beer_constraint, beer_id=beer_id
        )
        assert isinstance(translated, SessionInvalidError)

        # A real user naming a beer that is not in the catalog.
        await _identity(conn, _USER_A)
        unknown_beer = await _capture_fk_violation(conn, insert_sql, _USER_A, _MISSING_ID)
        assert unknown_beer.constraint_name == f"{constraint_prefix}_beer_id_fkey"
        translated = translate_beer_write_foreign_key_violation(
            unknown_beer, beer_constraint=beer_constraint, beer_id=_MISSING_ID
        )
        assert isinstance(translated, NotFoundError)
        assert str(translated) == f"Beer {_MISSING_ID} not found"

    run_rolled_back(integration_dsn, body, users=(_USER_A,))


def test_real_violations_on_contributions_translate_as_the_service_expects(integration_dsn):
    payload = BeerContributionCreate(official_name="Audit Beer", brewery_id=_MISSING_ID)
    insert = (
        "insert into public.beer_contributions (user_id, official_name, brewery_id) "
        "values ($1, 'Audit Beer', $2)"
    )

    async def body(conn):
        beer_id = await _seed_catalog_beer(conn)
        brewery_id = await conn.fetchval(
            "select brewery_id from public.beers where id = $1", beer_id
        )
        await _as(conn, "beerapp_backend")

        await _identity(conn, _MISSING_USER)
        deleted_account = await _capture_fk_violation(conn, insert, _MISSING_USER, brewery_id)
        assert deleted_account.constraint_name == "beer_contributions_user_id_fkey"
        assert isinstance(
            contributions_service._translate_foreign_key_violation(deleted_account, payload),
            SessionInvalidError,
        )

        await _identity(conn, _USER_A)
        unknown_brewery = await _capture_fk_violation(conn, insert, _USER_A, _MISSING_ID)
        assert unknown_brewery.constraint_name == "beer_contributions_brewery_id_fkey"
        translated = contributions_service._translate_foreign_key_violation(
            unknown_brewery, payload
        )
        assert isinstance(translated, NotFoundError)

    run_rolled_back(integration_dsn, body, users=(_USER_A,))


# -- 8. functions: SECURITY DEFINER, search_path, EXECUTE, the private schema -----------------

_AUDITED_PRIVATE_FUNCTIONS = {
    "handle_new_user",  # SECURITY DEFINER auth.users trigger (profile creation)
    "set_updated_at",  # plain trigger function (updated_at maintenance)
    "other_user_pending_beer_barcode_exists",  # SECURITY DEFINER boolean helper (Phase 13)
}
_INTENDED_HELPER = "other_user_pending_beer_barcode_exists"


async def _functions(conn, schemas=("public", "private")):
    return await conn.fetch(
        "select p.oid, n.nspname, p.proname, p.prosecdef, p.proconfig, "
        "t.typname as rettype, pg_get_userbyid(p.proowner) as owner "
        "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
        "join pg_type t on t.oid = p.prorettype where n.nspname = any($1)",
        list(schemas),
    )


def test_the_private_schema_contains_exactly_the_audited_functions(integration_dsn):
    async def body(conn):
        rows = await _functions(conn, ("private",))
        assert {r["proname"] for r in rows} == _AUDITED_PRIVATE_FUNCTIONS

    run_rolled_back(integration_dsn, body)


def test_there_are_no_functions_in_the_public_schema(integration_dsn):
    # Supabase would grant EXECUTE on any new public function to anon/authenticated
    # by default, and PostgREST would expose it as an RPC endpoint.
    async def body(conn):
        assert [r["proname"] for r in await _functions(conn, ("public",))] == []

    run_rolled_back(integration_dsn, body)


def test_every_security_definer_function_pins_an_empty_search_path(integration_dsn):
    async def body(conn):
        definers = [r for r in await _functions(conn) if r["prosecdef"]]
        assert {r["proname"] for r in definers} == {"handle_new_user", _INTENDED_HELPER}
        for row in definers:
            assert row["nspname"] == "private"  # never in an API-exposed schema
            assert list(row["proconfig"] or []) == ['search_path=""'], row["proname"]
            assert row["owner"] == "postgres"

    run_rolled_back(integration_dsn, body)


async def _executors(conn, oid) -> dict[str, bool]:
    return {
        role: await conn.fetchval(
            "select has_function_privilege($1, $2::oid, 'EXECUTE')", role, oid
        )
        for role in ROLES
    }


async def _public_can_execute(conn, oid) -> bool:
    # proacl NULL means the default ACL, which grants EXECUTE to PUBLIC.
    return await conn.fetchval(
        "select p.proacl is null or exists ("
        "select 1 from aclexplode(p.proacl) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'"
        ") from pg_proc p where p.oid = $1::oid",
        oid,
    )


def test_handle_new_user_is_executable_by_no_role_but_its_owner(integration_dsn):
    async def body(conn):
        row = next(
            r for r in await _functions(conn, ("private",)) if r["proname"] == "handle_new_user"
        )
        assert await _public_can_execute(conn, row["oid"]) is False
        assert await _executors(conn, row["oid"]) == {role: False for role in ROLES}

    run_rolled_back(integration_dsn, body)


def test_the_pending_barcode_helper_is_executable_only_by_the_backend_role_and_its_owner(
    integration_dsn,
):
    async def body(conn):
        row = next(
            r for r in await _functions(conn, ("private",)) if r["proname"] == _INTENDED_HELPER
        )
        assert await _public_can_execute(conn, row["oid"]) is False
        assert await _executors(conn, row["oid"]) == {
            "anon": False,
            "authenticated": False,
            "beerapp_backend": True,
            "beerapp_seed": False,
        }
        acl_grantees = {
            r["grantee"]
            for r in await conn.fetch(
                "select pg_get_userbyid(a.grantee) as grantee from pg_proc p, "
                "aclexplode(p.proacl) a where p.oid = $1::oid and a.privilege_type = 'EXECUTE'",
                row["oid"],
            )
        }
        assert acl_grantees == {"postgres", "beerapp_backend"}

    run_rolled_back(integration_dsn, body)


def test_private_schema_is_usable_only_by_the_backend_role_and_creatable_by_none(integration_dsn):
    async def body(conn):
        for role in ROLES:
            usage = await conn.fetchval("select has_schema_privilege($1, 'private', 'USAGE')", role)
            create = await conn.fetchval(
                "select has_schema_privilege($1, 'private', 'CREATE')", role
            )
            assert (usage, create) == (role == "beerapp_backend", False), role
        public_grants = await conn.fetchval(
            "select count(*) from pg_namespace n, aclexplode(n.nspacl) a "
            "where n.nspname = 'private' and a.grantee = 0"
        )
        assert public_grants == 0

    run_rolled_back(integration_dsn, body)


def test_no_private_function_is_executable_by_public(integration_dsn):
    """PostgreSQL grants EXECUTE on every new function to PUBLIC unless it is
    revoked, so each function in `private` needs an explicit REVOKE. This is the
    regression test for private.set_updated_at(), which was missed until
    migration 20260921100000."""

    async def body(conn):
        for row in await _functions(conn, ("private",)):
            assert await _public_can_execute(conn, row["oid"]) is False, (
                f"PUBLIC can execute private.{row['proname']}"
            )

    run_rolled_back(integration_dsn, body)


def test_set_updated_at_is_executable_by_no_role_but_its_owner(integration_dsn):
    async def body(conn):
        row = next(
            r for r in await _functions(conn, ("private",)) if r["proname"] == "set_updated_at"
        )
        assert await _public_can_execute(conn, row["oid"]) is False
        assert await _executors(conn, row["oid"]) == {role: False for role in ROLES}
        # The owner keeps EXECUTE (it created the triggers and still can).
        assert row["owner"] == "postgres"
        assert await conn.fetchval(
            "select has_function_privilege('postgres', $1::oid, 'EXECUTE')", row["oid"]
        )
        acl = {
            r["grantee"]
            for r in await conn.fetch(
                "select pg_get_userbyid(a.grantee) as grantee from pg_proc p, "
                "aclexplode(p.proacl) a where p.oid = $1::oid and a.privilege_type = 'EXECUTE'",
                row["oid"],
            )
        }
        assert acl == {"postgres"}
        # The function itself is unchanged: not a SECURITY DEFINER, fixed search_path.
        assert row["prosecdef"] is False
        assert list(row["proconfig"] or []) == ['search_path=""']

    run_rolled_back(integration_dsn, body)


def test_usage_on_private_exposes_nothing_beyond_the_intended_helper(integration_dsn):
    """beerapp_backend has USAGE on schema `private` (Phase 13) so it can call the
    boolean helper. Every private function it can execute must be EXACTLY that
    helper -- no PUBLIC-EXECUTE leftovers.

    History: this test used to tolerate private.set_updated_at() (PUBLIC EXECUTE;
    a trigger function, so not exploitable). Migration 20260921100000 revoked that
    privilege and this now asserts the strict set.
    """

    async def body(conn):
        reachable = {
            row["proname"]
            for row in await _functions(conn, ("private",))
            if await conn.fetchval(
                "select has_function_privilege('beerapp_backend', $1::oid, 'EXECUTE')", row["oid"]
            )
        }
        assert reachable == {_INTENDED_HELPER}

    run_rolled_back(integration_dsn, body)


_PRIVATE_CALLS = (
    "select private.other_user_pending_beer_barcode_exists('4006381333931')",
    "select private.handle_new_user()",
    "select private.set_updated_at()",
)


@pytest.mark.parametrize("role", ["anon", "authenticated", "beerapp_seed"])
def test_unintended_roles_cannot_reach_anything_in_private(integration_dsn, role):
    async def body(conn):
        await _as(conn, role)
        for call in _PRIVATE_CALLS:
            await _denied(conn, call)

    run_rolled_back(integration_dsn, body)


def test_the_backend_role_can_call_only_the_intended_private_helper(integration_dsn):
    async def body(conn):
        await _as(conn, "beerapp_backend")
        await _identity(conn, _USER_A)
        assert await conn.fetchval(_PRIVATE_CALLS[0]) is False  # fails closed: no such pending row
        await _denied(conn, _PRIVATE_CALLS[1])
        await _denied(conn, _PRIVATE_CALLS[2])

    run_rolled_back(integration_dsn, body, users=(_USER_A,))


# -- the updated_at triggers keep working after the REVOKE ---------------------------------

_UPDATED_AT_TABLES = {
    "profiles",
    "countries",
    "beer_styles",
    "breweries",
    "beers",
    "user_beer_logs",
    "user_beer_collection",
}


def test_all_seven_updated_at_triggers_still_reference_the_function(integration_dsn):
    async def body(conn):
        rows = await conn.fetch(
            "select c.relname, t.tgname, t.tgenabled::text as enabled from pg_trigger t "
            "join pg_class c on c.oid = t.tgrelid "
            "where t.tgfoid = 'private.set_updated_at()'::regprocedure and not t.tgisinternal"
        )
        assert {r["relname"] for r in rows} == _UPDATED_AT_TABLES
        assert {r["enabled"] for r in rows} == {"O"}  # enabled, fire on origin
        assert all(r["tgname"].endswith("_set_updated_at") for r in rows)

    run_rolled_back(integration_dsn, body)


async def _seed_updatable_rows(conn) -> dict[str, str]:
    """One row per trigger-carrying table, all with updated_at pushed a day into
    the past (triggers are disabled just for that backdating, then re-enabled)."""
    beer_id = await _seed_catalog_beer(conn)
    brewery_id = await conn.fetchval("select brewery_id from public.beers where id = $1", beer_id)
    country_id = await conn.fetchval(
        "select country_id from public.breweries where id = $1", brewery_id
    )
    style_id = await conn.fetchval(
        "insert into public.beer_styles (name) values ('Audit Style') returning id"
    )
    log_id = await conn.fetchval(
        "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2) returning id",
        _USER_A,
        beer_id,
    )
    collection_id = await conn.fetchval(
        "insert into public.user_beer_collection (user_id, beer_id, is_favorite, favorited_at) "
        "values ($1, $2, true, now()) returning id",
        _USER_A,
        beer_id,
    )
    for table in _UPDATED_AT_TABLES:
        await conn.execute(f"alter table public.{table} disable trigger user")
        await conn.execute(f"update public.{table} set updated_at = now() - interval '1 day'")
        await conn.execute(f"alter table public.{table} enable trigger user")
    return {
        "profiles": _USER_A,
        "countries": str(country_id),
        "beer_styles": str(style_id),
        "breweries": str(brewery_id),
        "beers": str(beer_id),
        "user_beer_logs": str(log_id),
        "user_beer_collection": str(collection_id),
    }


# (table, the role that really writes it in production, the SET clause it performs)
_TRIGGER_CASES = [
    ("profiles", "authenticated", "display_name = 'x'"),
    ("countries", "beerapp_seed", "name = name || ' x'"),
    ("beer_styles", "beerapp_seed", "name = name || ' x'"),
    ("breweries", "beerapp_seed", "name = name || ' x'"),
    ("beers", "beerapp_seed", "official_name = 'x'"),
    ("user_beer_logs", "beerapp_backend", "review = 'x'"),
    ("user_beer_collection", "beerapp_backend", "is_wishlist = true, wishlisted_at = now()"),
]


@pytest.mark.parametrize(
    "table,role,assignment", _TRIGGER_CASES, ids=[case[0] for case in _TRIGGER_CASES]
)
def test_the_updated_at_trigger_fires_for_its_real_writer_without_execute_privilege(
    integration_dsn, table, role, assignment
):
    async def body(conn):
        row_id = (await _seed_updatable_rows(conn))[table]
        backdated = await conn.fetchval(f"select updated_at from public.{table} limit 1")
        assert await conn.fetchval("select $1 < now() - interval '23 hours'", backdated)

        # The precondition that makes this test meaningful: the writing role holds no
        # EXECUTE privilege on the trigger function at all...
        assert (
            await conn.fetchval(
                "select has_function_privilege($1, 'private.set_updated_at()', 'EXECUTE')", role
            )
            is False
        )

        # ...yet its UPDATE still fires the trigger.
        await _as(conn, role)
        await _identity(conn, _USER_A)
        await conn.execute("select set_config('request.jwt.claim.sub', $1, true)", _USER_A)
        update = f"update public.{table} set {assignment} where id = $1"
        assert await conn.execute(update, row_id) == "UPDATE 1"
        await conn.execute("reset role")

        after = await conn.fetchval(f"select updated_at from public.{table} where id = $1", row_id)
        assert await conn.fetchval("select $1 > now() - interval '1 hour'", after), (
            f"{table}.updated_at was not refreshed by its trigger"
        )

    run_rolled_back(integration_dsn, body, users=(_USER_A,))


def test_the_owner_can_still_create_a_trigger_that_uses_the_function(integration_dsn):
    async def body(conn):
        await conn.execute(
            "create table public.trigger_probe (id int primary key, updated_at timestamptz)"
        )
        await conn.execute(
            "create trigger trigger_probe_set_updated_at before update on public.trigger_probe "
            "for each row execute function private.set_updated_at()"
        )
        await conn.execute("insert into public.trigger_probe values (1, now() - interval '1 day')")
        await conn.execute("update public.trigger_probe set id = id where id = 1")
        assert await conn.fetchval(
            "select updated_at > now() - interval '1 hour' from public.trigger_probe"
        )

    run_rolled_back(integration_dsn, body)
