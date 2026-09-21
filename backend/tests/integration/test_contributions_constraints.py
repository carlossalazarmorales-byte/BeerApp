"""Proves the Phase 13 contribution tables' own constraints: CHECKs, the
own-duplicate partial unique indexes, the deliberately NON-unique pending
barcode index, FK delete rules, and the moderation-lifecycle CHECKs. Runs as
the disposable database's admin role (row-level security and role grants are
covered separately in test_contributions_rls.py).

Unlike the older integration tests, every user here is a real auth.users row
-- user_id is a foreign key to auth.users, so a made-up UUID is rejected.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 13's migrations applied. Never run against DATABASE_URL/
SEED_DATABASE_URL or the shared dev project.
"""

import asyncio
from decimal import Decimal

import asyncpg
import pytest

from .disposable_db import connection_kwargs

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"

_INSERT_BEER = (
    "insert into public.beer_contributions "
    "(user_id, official_name, brewery_id, proposed_brewery_name, style_id, "
    "proposed_style_name, abv, barcode) values ($1, $2, $3, $4, $5, $6, $7, $8)"
)
_INSERT_BREWERY = (
    "insert into public.brewery_contributions "
    "(user_id, name, country_id, proposed_country_name, region, city) "
    "values ($1, $2, $3, $4, $5, $6)"
)


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
    """Asserts one statement is rejected without poisoning the enclosing
    transaction (a savepoint), so several rejections fit in one test.
    """
    with pytest.raises(error):
        async with conn.transaction():
            await conn.execute(sql, *args)


async def _seed_user(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("insert into auth.users (id) values ($1)", user_id)


async def _seed_catalog(conn: asyncpg.Connection) -> dict:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Test Brewery', $1) returning id",
        country_id,
    )
    style_id = await conn.fetchval(
        "insert into public.beer_styles (name) values ('Test Style') returning id"
    )
    beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ('Canon Beer', $1) "
        "returning id",
        brewery_id,
    )
    return {
        "country_id": country_id,
        "brewery_id": brewery_id,
        "style_id": style_id,
        "beer_id": beer_id,
    }


async def _beer(
    conn: asyncpg.Connection,
    user_id: str = _USER_A,
    name: str = "Test Beer",
    *,
    brewery_id=None,
    proposed_brewery_name=None,
    style_id=None,
    proposed_style_name=None,
    abv=None,
    barcode=None,
) -> None:
    await conn.execute(
        _INSERT_BEER,
        user_id,
        name,
        brewery_id,
        proposed_brewery_name,
        style_id,
        proposed_style_name,
        abv,
        barcode,
    )


async def _brewery(
    conn: asyncpg.Connection,
    user_id: str = _USER_A,
    name: str = "Test Brewery Suggestion",
    *,
    country_id=None,
    proposed_country_name=None,
    region=None,
    city=None,
) -> None:
    await conn.execute(
        _INSERT_BREWERY, user_id, name, country_id, proposed_country_name, region, city
    )


# --- beer_contributions ----------------------------------------------------


def test_beer_contribution_defaults_to_pending_and_unreviewed(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _beer(conn, brewery_id=cat["brewery_id"])
        row = await conn.fetchrow(
            "select status, reviewed_at, review_note, created_at from public.beer_contributions"
        )
        assert row["status"] == "pending"
        assert row["reviewed_at"] is None
        assert row["review_note"] is None
        assert row["created_at"] is not None

    _run(integration_dsn, body)


def test_beer_contribution_accepts_a_proposed_brewery_and_proposed_style(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _beer(
            conn, proposed_brewery_name="Brand New Brewery", proposed_style_name="Weird Style"
        )
        assert await conn.fetchval("select count(*) from public.beer_contributions") == 1

    _run(integration_dsn, body)


def test_beer_contribution_requires_exactly_one_of_brewery_id_or_proposed_name(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        # both
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "Both", cat["brewery_id"], "Also Named", None, None, None, None,
        )  # fmt: skip
        # neither
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "Neither", None, None, None, None, None, None,
        )  # fmt: skip

    _run(integration_dsn, body)


def test_beer_contribution_style_id_and_proposed_style_are_mutually_exclusive(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "Both styles", cat["brewery_id"], None, cat["style_id"], "Other", None, None,
        )  # fmt: skip
        # Style is optional: omitting both, or giving exactly one, is fine.
        await _beer(conn, name="No style", brewery_id=cat["brewery_id"])
        await _beer(conn, name="Canonical style", brewery_id=cat["brewery_id"],
                    style_id=cat["style_id"])  # fmt: skip

    _run(integration_dsn, body)


def test_beer_contribution_abv_bounds(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _beer(conn, name="Zero", brewery_id=cat["brewery_id"], abv=Decimal("0"))
        await _beer(conn, name="Max", brewery_id=cat["brewery_id"], abv=Decimal("99.99"))
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "Negative", cat["brewery_id"], None, None, None, Decimal("-0.5"), None,
        )  # fmt: skip
        # numeric(4,2) itself cannot hold 100+, same as public.beers.abv --
        # the API schema caps at 99.99 so this can never reach the database.
        await _expect(
            conn, asyncpg.NumericValueOutOfRangeError, _INSERT_BEER,
            _USER_A, "Huge", cat["brewery_id"], None, None, None, Decimal("150"), None,
        )  # fmt: skip

    _run(integration_dsn, body)


@pytest.mark.parametrize(
    "barcode", ["12345", "1234567", "123456789012", "12345678901234", "ABCDEFGH", "4006381 33393"]
)
def test_beer_contribution_rejects_non_canonical_barcode_shapes(integration_dsn, barcode):
    """12-digit UPC-A is rejected on purpose: only the canonical (13-digit,
    zero-prefixed) form is ever stored -- backend/app/services/barcode.py.
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "Bad code", cat["brewery_id"], None, None, None, None, barcode,
        )  # fmt: skip

    _run(integration_dsn, body)


def test_beer_contribution_accepts_canonical_8_and_13_digit_barcodes(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _beer(conn, name="EAN-8", brewery_id=cat["brewery_id"], barcode="96385074")
        await _beer(conn, name="EAN-13", brewery_id=cat["brewery_id"], barcode="4006381333931")

    _run(integration_dsn, body)


def test_beer_contribution_name_must_be_non_blank_and_at_most_200_chars(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "   ", None, "Some Brewery", None, None, None, None,
        )  # fmt: skip
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BEER,
            _USER_A, "x" * 201, None, "Some Brewery", None, None, None, None,
        )  # fmt: skip
        await _beer(conn, name="x" * 200, proposed_brewery_name="Some Brewery")

    _run(integration_dsn, body)


def test_beer_contribution_moderation_lifecycle_checks(integration_dsn):
    """The full pending/approved/rejected lifecycle is modeled now, but each
    state must carry exactly the columns it implies.
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        base = "insert into public.beer_contributions " \
               "(user_id, official_name, proposed_brewery_name, status, reviewed_at, " \
               "review_note, resolved_beer_id) values ($1, $2, 'B', $3, $4, $5, $6)"  # fmt: skip
        now = await conn.fetchval("select now()")

        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n1", "bogus", None, None, None
        )  # unknown status
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            base,
            _USER_A,
            "n2",
            "approved",
            None,
            None,
            cat["beer_id"],
        )  # no reviewed_at
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n3", "pending", now, None, None
        )  # pending yet reviewed
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n4", "pending", None, "note", None
        )  # pending with a note
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n5", "approved", now, None, None
        )  # approved, nothing resolved
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            base,
            _USER_A,
            "n6",
            "rejected",
            now,
            None,
            cat["beer_id"],
        )  # rejected but resolved
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n7", "rejected", now, "x" * 501, None
        )  # note too long

        await conn.execute(base, _USER_A, "ok-approved", "approved", now, "merged", cat["beer_id"])
        await conn.execute(base, _USER_A, "ok-rejected", "rejected", now, "not a beer", None)

    _run(integration_dsn, body)


def test_beer_contribution_own_pending_duplicate_is_unique_per_user(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _seed_user(conn, _USER_B)
        cat = await _seed_catalog(conn)

        await _beer(conn, name="Hazy IPA", brewery_id=cat["brewery_id"])
        # Case and edge whitespace do not make it a different suggestion.
        await _expect(
            conn, asyncpg.UniqueViolationError, _INSERT_BEER,
            _USER_A, "  hazy ipa ", cat["brewery_id"], None, None, None, None, None,
        )  # fmt: skip
        # A different user may submit the very same thing.
        await _beer(conn, user_id=_USER_B, name="Hazy IPA", brewery_id=cat["brewery_id"])

        # Same guard for the free-text-brewery form.
        await _beer(conn, name="Stout", proposed_brewery_name="New Brewery")
        await _expect(
            conn, asyncpg.UniqueViolationError, _INSERT_BEER,
            _USER_A, "STOUT", None, " new brewery", None, None, None, None,
        )  # fmt: skip

    _run(integration_dsn, body)


def test_beer_contribution_own_duplicate_guard_only_covers_pending_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _beer(conn, name="Hazy IPA", brewery_id=cat["brewery_id"])
        # Simulate a moderator rejecting it (admin role, outside the app path).
        await conn.execute(
            "update public.beer_contributions set status = 'rejected', reviewed_at = now()"
        )
        # A fresh pending suggestion of the same thing is now allowed.
        await _beer(conn, name="Hazy IPA", brewery_id=cat["brewery_id"])

    _run(integration_dsn, body)


def test_two_users_may_have_the_same_barcode_pending(integration_dsn):
    """Decision: allow-and-flag, not hard-block. There is deliberately no
    unique index on a pending barcode (docs/DECISIONS.md).
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _seed_user(conn, _USER_B)
        cat = await _seed_catalog(conn)
        await _beer(conn, _USER_A, "One", brewery_id=cat["brewery_id"], barcode="4006381333931")
        await _beer(conn, _USER_B, "Two", brewery_id=cat["brewery_id"], barcode="4006381333931")
        count = await conn.fetchval(
            "select count(*) from public.beer_contributions where barcode = '4006381333931'"
        )
        assert count == 2

    _run(integration_dsn, body)


def test_pending_barcode_index_exists_and_is_not_unique(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        is_unique = await conn.fetchval(
            "select i.indisunique from pg_index i "
            "join pg_class c on c.oid = i.indexrelid "
            "where c.relname = 'beer_contributions_pending_barcode_idx'"
        )
        assert is_unique is False

    _run(integration_dsn, body)


def test_beer_contribution_catalog_fks_are_restrict(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _beer(conn, brewery_id=cat["brewery_id"], style_id=cat["style_id"])
        # A referenced brewery/style cannot be deleted out from under a
        # contribution (matches every other FK onto the catalog).
        await _expect(
            conn, asyncpg.ForeignKeyViolationError,
            "delete from public.beer_styles where id = $1", cat["style_id"],
        )  # fmt: skip
        await _expect(
            conn, asyncpg.ForeignKeyViolationError,
            "delete from public.breweries where id = $1", cat["brewery_id"],
        )  # fmt: skip

    _run(integration_dsn, body)


def test_beer_contribution_foreign_keys_have_stable_names(integration_dsn):
    """The service maps ForeignKeyViolationError by constraint name, so the
    names are part of the contract.
    """

    async def body(conn: asyncpg.Connection) -> None:
        names = {
            r["conname"]
            for r in await conn.fetch(
                "select conname from pg_constraint "
                "where conrelid = 'public.beer_contributions'::regclass and contype = 'f'"
            )
        }
        assert {
            "beer_contributions_user_id_fkey",
            "beer_contributions_brewery_id_fkey",
            "beer_contributions_style_id_fkey",
            "beer_contributions_resolved_beer_id_fkey",
        } <= names

    _run(integration_dsn, body)


# --- brewery_contributions -------------------------------------------------


def test_brewery_contribution_defaults_to_pending_and_unreviewed(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _brewery(conn, country_id=cat["country_id"], region="R", city="C")
        row = await conn.fetchrow("select status, reviewed_at from public.brewery_contributions")
        assert row["status"] == "pending"
        assert row["reviewed_at"] is None

    _run(integration_dsn, body)


def test_brewery_contribution_requires_exactly_one_of_country_id_or_proposed_name(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        await _brewery(conn, name="Proposed only", proposed_country_name="Atlantis")
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BREWERY,
            _USER_A, "Both", cat["country_id"], "Atlantis", None, None,
        )  # fmt: skip
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BREWERY,
            _USER_A, "Neither", None, None, None, None,
        )  # fmt: skip

    _run(integration_dsn, body)


def test_brewery_contribution_text_length_checks(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        cid = cat["country_id"]
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BREWERY, _USER_A, "  ", cid, None, None, None
        )  # blank name
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            _INSERT_BREWERY,
            _USER_A,
            "x" * 201,
            cid,
            None,
            None,
            None,
        )  # name too long
        await _expect(
            conn, asyncpg.CheckViolationError, _INSERT_BREWERY, _USER_A, "ok", cid, None, " ", None
        )  # blank region
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            _INSERT_BREWERY,
            _USER_A,
            "ok",
            cid,
            None,
            None,
            "c" * 101,
        )  # city too long
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            _INSERT_BREWERY,
            _USER_A,
            "ok",
            None,
            "p" * 101,
            None,
            None,
        )  # proposed country too long

    _run(integration_dsn, body)


def test_brewery_contribution_moderation_lifecycle_checks(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        cat = await _seed_catalog(conn)
        now = await conn.fetchval("select now()")
        base = "insert into public.brewery_contributions " \
               "(user_id, name, proposed_country_name, status, reviewed_at, review_note, " \
               "resolved_brewery_id) values ($1, $2, 'X', $3, $4, $5, $6)"  # fmt: skip

        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n1", "bogus", None, None, None
        )
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n2", "approved", now, None, None
        )  # approved, nothing resolved
        await _expect(
            conn, asyncpg.CheckViolationError, base, _USER_A, "n3", "pending", None, "note", None
        )
        await _expect(
            conn,
            asyncpg.CheckViolationError,
            base,
            _USER_A,
            "n4",
            "rejected",
            now,
            None,
            cat["brewery_id"],
        )
        await conn.execute(base, _USER_A, "ok-a", "approved", now, None, cat["brewery_id"])
        await conn.execute(base, _USER_A, "ok-r", "rejected", now, "duplicate", None)

    _run(integration_dsn, body)


def test_brewery_contribution_own_pending_duplicate_is_unique_per_user(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _seed_user(conn, _USER_B)
        cat = await _seed_catalog(conn)

        await _brewery(conn, name="Hop House", country_id=cat["country_id"])
        await _expect(
            conn, asyncpg.UniqueViolationError, _INSERT_BREWERY,
            _USER_A, " HOP HOUSE", cat["country_id"], None, None, None,
        )  # fmt: skip
        await _brewery(conn, user_id=_USER_B, name="Hop House", country_id=cat["country_id"])

        await _brewery(conn, name="Hop House", proposed_country_name="Atlantis")
        await _expect(
            conn, asyncpg.UniqueViolationError, _INSERT_BREWERY,
            _USER_A, "hop house", None, " atlantis ", None, None,
        )  # fmt: skip

    _run(integration_dsn, body)


def test_brewery_contribution_foreign_keys_have_stable_names(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        names = {
            r["conname"]
            for r in await conn.fetch(
                "select conname from pg_constraint "
                "where conrelid = 'public.brewery_contributions'::regclass and contype = 'f'"
            )
        }
        assert {
            "brewery_contributions_user_id_fkey",
            "brewery_contributions_country_id_fkey",
            "brewery_contributions_resolved_brewery_id_fkey",
        } <= names

    _run(integration_dsn, body)


# --- account deletion (Phase 12 cascade) -----------------------------------


@pytest.mark.parametrize("table", ["beer_contributions", "brewery_contributions"])
def test_contribution_user_id_foreign_key_is_cascade(integration_dsn, table):
    """Verified via pg_constraint metadata (confdeltype = 'c'), like the
    older user_beer_logs/user_beer_collection cascade tests, so DELETE
    /account stays complete now that contributions are user-owned.
    """

    async def body(conn: asyncpg.Connection) -> None:
        delete_rule = await conn.fetchval(
            # ::text -- confdeltype is the internal "char" type, which asyncpg
            # returns as bytes rather than str.
            "select confdeltype::text from pg_constraint "
            f"where conrelid = 'public.{table}'::regclass "
            "and confrelid = 'auth.users'::regclass"
        )
        assert delete_rule == "c"

    _run(integration_dsn, body)


def test_deleting_a_user_removes_their_contributions_and_nothing_else(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _seed_user(conn, _USER_A)
        await _seed_user(conn, _USER_B)
        cat = await _seed_catalog(conn)
        await _beer(conn, _USER_A, "A beer", brewery_id=cat["brewery_id"])
        await _beer(conn, _USER_B, "B beer", brewery_id=cat["brewery_id"])
        await _brewery(conn, _USER_A, "A brewery", country_id=cat["country_id"])
        await _brewery(conn, _USER_B, "B brewery", country_id=cat["country_id"])

        await conn.execute("delete from auth.users where id = $1", _USER_A)

        assert (
            await conn.fetchval(
                "select count(*) from public.beer_contributions where user_id = $1", _USER_A
            )
            == 0
        )
        assert (
            await conn.fetchval(
                "select count(*) from public.brewery_contributions where user_id = $1", _USER_A
            )
            == 0
        )
        assert await conn.fetchval("select count(*) from public.beer_contributions") == 1
        assert await conn.fetchval("select count(*) from public.brewery_contributions") == 1
        # The canonical catalog is untouched by any of this.
        assert await conn.fetchval("select count(*) from public.beers") == 1
        assert await conn.fetchval("select count(*) from public.breweries") == 1

    _run(integration_dsn, body)
