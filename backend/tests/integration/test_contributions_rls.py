"""Proves the Phase 13 contribution tables' RLS/grant shape and the
boolean-only cross-user barcode function -- not just that the repository's
own filtering happens to work. Every test deliberately issues unfiltered,
cross-identity or forged SQL that a correct repository would never write, to
prove the database refuses it regardless.

Mirrors test_user_achievements_rls.py (insert-only user-owned table), with
real auth.users rows because user_id is a foreign key.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 13's migrations applied, whose connecting role can `SET ROLE
beerapp_backend`/`anon`/`authenticated`/`beerapp_seed`. Never run against
DATABASE_URL/SEED_DATABASE_URL or the shared dev project.
"""

import asyncio

import asyncpg
import pytest

from .disposable_db import connection_kwargs

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"
_BARCODE = "4006381333931"
_FUNCTION = "private.other_user_pending_beer_barcode_exists"

_TABLES = ["beer_contributions", "brewery_contributions"]

# One minimal, valid pending insert per table, taking user_id as $1.
_INSERT_PENDING = {
    "beer_contributions": (
        "insert into public.beer_contributions (user_id, official_name, proposed_brewery_name) "
        "values ($1, 'A Beer', 'A Brewery')"
    ),
    "brewery_contributions": (
        "insert into public.brewery_contributions (user_id, name, proposed_country_name) "
        "values ($1, 'A Brewery', 'A Land')"
    ),
}
# A row that satisfies every table CHECK yet is already approved -- only the
# INSERT policy's `status = 'pending'` can stop it. $1 = user_id, $2 = the
# canonical row it claims to have resolved to.
_INSERT_APPROVED = {
    "beer_contributions": (
        "insert into public.beer_contributions "
        "(user_id, official_name, proposed_brewery_name, status, reviewed_at, resolved_beer_id) "
        "values ($1, 'A Beer', 'A Brewery', 'approved', now(), $2)"
    ),
    "brewery_contributions": (
        "insert into public.brewery_contributions "
        "(user_id, name, proposed_country_name, status, reviewed_at, resolved_brewery_id) "
        "values ($1, 'A Brewery', 'A Land', 'approved', now(), $2)"
    ),
}


async def _in_rolled_back_transaction(dsn: str, body) -> None:
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    transaction = conn.transaction()
    await transaction.start()
    try:
        await body(conn)
    finally:
        await transaction.rollback()
        await conn.close()


def _run(dsn: str, body) -> None:
    asyncio.run(_in_rolled_back_transaction(dsn, body))


async def _expect(conn: asyncpg.Connection, error: type[Exception], sql: str, *args) -> None:
    """One rejected statement inside a savepoint, so the transaction survives."""
    with pytest.raises(error):
        async with conn.transaction():
            await conn.execute(sql, *args)


async def _as_role(conn: asyncpg.Connection, role: str) -> None:
    await conn.execute(f"set local role {role}")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


async def _seed_users(conn: asyncpg.Connection) -> None:
    for user_id in (_USER_A, _USER_B):
        await conn.execute("insert into auth.users (id) values ($1)", user_id)


async def _seed_canonical(conn: asyncpg.Connection) -> dict:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Canon Brewery', $1) returning id",
        country_id,
    )
    beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ('Canon Beer', $1) "
        "returning id",
        brewery_id,
    )
    return {"beer_contributions": beer_id, "brewery_contributions": brewery_id}


async def _seed_beer_contribution(
    conn: asyncpg.Connection, user_id: str, barcode: str | None, *, status: str = "pending"
) -> None:
    """Admin-role seeding (before any SET ROLE) so a row can start out
    approved/rejected, which the app's own INSERT path can never do.
    """
    await conn.execute(
        "insert into public.beer_contributions "
        "(user_id, official_name, proposed_brewery_name, barcode, status, reviewed_at) "
        "values ($1, $2, 'Some Brewery', $3, $4, "
        "case when $4 = 'pending' then null else now() end)",
        user_id,
        f"Beer {user_id[:2]} {status}",
        barcode,
        status,
    )


# --- row-level security on both tables -------------------------------------


@pytest.mark.parametrize("table", _TABLES)
def test_backend_role_can_insert_and_select_its_own_rows(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)

        await conn.execute(_INSERT_PENDING[table], _USER_A)
        rows = await conn.fetch(f"select id, status from public.{table}")
        assert len(rows) == 1
        assert rows[0]["status"] == "pending"

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_unfiltered_select_as_other_user_sees_nothing(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)
        await conn.execute(_INSERT_PENDING[table], _USER_A)

        await _set_identity(conn, _USER_B)
        # Deliberately no WHERE user_id: RLS, not this query, must hide it.
        assert await conn.fetch(f"select id from public.{table}") == []

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_insert_with_foreign_user_id_is_rejected_by_with_check(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_B)

        await _expect(conn, asyncpg.InsufficientPrivilegeError, _INSERT_PENDING[table], _USER_A)

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_insert_cannot_forge_an_already_approved_status(integration_dsn, table):
    """Status is server-controlled at the database level: even a row that
    passes every table CHECK is refused unless it is pending.
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        canonical = await _seed_canonical(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)

        await _expect(
            conn,
            asyncpg.InsufficientPrivilegeError,
            _INSERT_APPROVED[table],
            _USER_A,
            canonical[table],
        )

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_identity_absent_or_cleared_denies_all_rows_without_raising(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)
        await conn.execute(_INSERT_PENDING[table], _USER_A)

        await conn.execute("select set_config('app.user_id', '', true)")
        assert await conn.fetch(f"select id from public.{table}") == []
        await _expect(conn, asyncpg.InsufficientPrivilegeError, _INSERT_PENDING[table], _USER_A)

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_backend_role_cannot_update_a_contribution(integration_dsn, table):
    """A user cannot approve their own submission: no UPDATE grant exists."""

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)
        await conn.execute(_INSERT_PENDING[table], _USER_A)

        await _expect(
            conn,
            asyncpg.InsufficientPrivilegeError,
            f"update public.{table} set status = 'pending'",
        )

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_backend_role_cannot_delete_a_contribution(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)
        await conn.execute(_INSERT_PENDING[table], _USER_A)

        await _expect(conn, asyncpg.InsufficientPrivilegeError, f"delete from public.{table}")

    _run(integration_dsn, body)


@pytest.mark.parametrize("role", ["anon", "authenticated", "beerapp_seed"])
@pytest.mark.parametrize("table", _TABLES)
def test_other_roles_have_no_access_at_all(integration_dsn, table, role):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _as_role(conn, role)
        await _expect(conn, asyncpg.InsufficientPrivilegeError, f"select id from public.{table}")
        await _expect(conn, asyncpg.InsufficientPrivilegeError, _INSERT_PENDING[table], _USER_A)

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", _TABLES)
def test_row_level_security_is_enabled(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        enabled = await conn.fetchval(
            "select relrowsecurity from pg_class where oid = $1::regclass", f"public.{table}"
        )
        assert enabled is True

    _run(integration_dsn, body)


# --- grants -----------------------------------------------------------------


@pytest.mark.parametrize("table", _TABLES)
def test_backend_role_has_only_select_and_insert_on_contributions(integration_dsn, table):
    async def body(conn: asyncpg.Connection) -> None:
        granted = {
            privilege
            for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES")
            if await conn.fetchval(
                "select has_table_privilege('beerapp_backend', $1, $2)",
                f"public.{table}",
                privilege,
            )
        }
        assert granted == {"SELECT", "INSERT"}

    _run(integration_dsn, body)


@pytest.mark.parametrize("table", ["countries", "beer_styles", "breweries", "beers"])
def test_backend_role_still_cannot_write_any_catalog_table(integration_dsn, table):
    """The exit criterion, at the privilege level: contributions never gain
    a path to overwrite the canonical catalog.
    """

    async def body(conn: asyncpg.Connection) -> None:
        for privilege in ("INSERT", "UPDATE", "DELETE", "TRUNCATE"):
            assert not await conn.fetchval(
                "select has_table_privilege('beerapp_backend', $1, $2)",
                f"public.{table}",
                privilege,
            )
        assert await conn.fetchval(
            "select has_table_privilege('beerapp_backend', $1, 'SELECT')", f"public.{table}"
        )

    _run(integration_dsn, body)


# --- private.other_user_pending_beer_barcode_exists -------------------------


def test_function_is_true_when_another_user_has_the_barcode_pending(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_B)

        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is True

    _run(integration_dsn, body)


def test_function_ignores_the_callers_own_pending_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_A)

        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is False

    _run(integration_dsn, body)


@pytest.mark.parametrize("status", ["approved", "rejected"])
def test_function_ignores_other_users_non_pending_rows(integration_dsn, status):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        canonical = await _seed_canonical(conn)
        if status == "approved":
            await conn.execute(
                "insert into public.beer_contributions "
                "(user_id, official_name, proposed_brewery_name, barcode, status, reviewed_at, "
                "resolved_beer_id) values ($1, 'x', 'b', $2, 'approved', now(), $3)",
                _USER_A,
                _BARCODE,
                canonical["beer_contributions"],
            )
        else:
            await _seed_beer_contribution(conn, _USER_A, _BARCODE, status="rejected")
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_B)

        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is False

    _run(integration_dsn, body)


def test_function_is_false_for_a_different_or_null_barcode(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_B)

        assert await conn.fetchval(f"select {_FUNCTION}($1)", "96385074") is False
        assert await conn.fetchval(f"select {_FUNCTION}($1)", None) is False

    _run(integration_dsn, body)


def test_function_fails_closed_when_identity_is_absent_or_cleared(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, "beerapp_backend")

        # Never set in this transaction.
        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is False
        # Set, then cleared to the empty string.
        await conn.execute("select set_config('app.user_id', '', true)")
        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is False

    _run(integration_dsn, body)


def test_function_does_not_widen_row_visibility(integration_dsn):
    """The whole point of using a function instead of a broader policy: the
    caller learns one boolean, and still cannot read the other user's row.
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, "beerapp_backend")
        await _set_identity(conn, _USER_B)

        assert await conn.fetchval(f"select {_FUNCTION}($1)", _BARCODE) is True
        assert await conn.fetch("select * from public.beer_contributions") == []
        assert (
            await conn.fetch("select * from public.beer_contributions where barcode = $1", _BARCODE)
            == []
        )

    _run(integration_dsn, body)


def test_function_is_a_minimal_security_definer_with_a_fixed_search_path(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        row = await conn.fetchrow(
            "select p.prosecdef, p.prorettype::regtype::text as returns, "
            "p.pronargs, p.proconfig, p.proargtypes::text as argtypes, "
            "n.nspname as schema "
            "from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
            "where p.proname = 'other_user_pending_beer_barcode_exists'"
        )
        assert row is not None
        assert row["schema"] == "private"
        assert row["prosecdef"] is True
        assert row["returns"] == "boolean"
        assert row["pronargs"] == 1  # the barcode only -- caller identity comes from app.user_id
        assert row["proconfig"] is not None
        assert 'search_path=""' in list(row["proconfig"])

    _run(integration_dsn, body)


def test_function_execute_is_granted_only_to_the_backend_role(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        signature = f"{_FUNCTION}(text)"
        assert await conn.fetchval(
            "select has_function_privilege('beerapp_backend', $1, 'EXECUTE')", signature
        )
        for role in ("anon", "authenticated", "beerapp_seed"):
            assert not await conn.fetchval(
                "select has_function_privilege($1, $2, 'EXECUTE')", role, signature
            )
        # PUBLIC (grantee oid 0) must not hold EXECUTE either: a function's
        # default ACL is NULL, which means PUBLIC may execute, so an explicit
        # non-null ACL without a PUBLIC entry is what proves the revoke ran.
        public_can_execute = await conn.fetchval(
            "select p.proacl is null or exists ("
            "  select 1 from aclexplode(p.proacl) a where a.grantee = 0 "
            "  and a.privilege_type = 'EXECUTE') "
            "from pg_proc p where p.oid = $1::regprocedure",
            signature,
        )
        assert public_can_execute is False

    _run(integration_dsn, body)


@pytest.mark.parametrize("role", ["anon", "authenticated"])
def test_client_roles_cannot_call_the_function(integration_dsn, role):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_users(conn)
        await _seed_beer_contribution(conn, _USER_A, _BARCODE)
        await _as_role(conn, role)
        await _expect(conn, asyncpg.InsufficientPrivilegeError, f"select {_FUNCTION}($1)", _BARCODE)

    _run(integration_dsn, body)
