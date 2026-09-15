"""Proves the user_beer_logs RLS backstop itself -- not just that the
repository's own `WHERE user_id = $N` filtering happens to work. Every test
here deliberately issues unfiltered or cross-identity SQL that a correct
repository would never write, to prove the database refuses it regardless.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 6's migrations applied, whose connecting role can `SET ROLE
beerapp_backend` (a superuser, or a role explicitly GRANTed membership --
see docs/DATABASE.md). Never run against DATABASE_URL/SEED_DATABASE_URL or
the shared dev project.
"""

import asyncio

import asyncpg
import pytest

from app.db import parse_dsn_kwargs

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"


async def _in_rolled_back_transaction(dsn: str, body) -> None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    transaction = conn.transaction()
    await transaction.start()
    try:
        await body(conn)
    finally:
        await transaction.rollback()
        await conn.close()


def _run(dsn: str, body) -> None:
    asyncio.run(_in_rolled_back_transaction(dsn, body))


async def _seed_beer(conn: asyncpg.Connection) -> str:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Test Brewery', $1) returning id",
        country_id,
    )
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ('Test Beer', $1) "
        "returning id",
        brewery_id,
    )


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    """Impersonates beerapp_backend for the rest of the enclosing
    transaction, so these tests exercise its exact RLS-restricted view
    without a second connection/credential. SET LOCAL ROLE is
    transaction-scoped, same as the app.user_id GUC it interacts with.
    """
    await conn.execute("set local role beerapp_backend")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


def test_backend_role_can_crud_its_own_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)

        log_id = await conn.fetchval(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2) returning id",
            _USER_A,
            beer_id,
        )
        row = await conn.fetchrow("select id from public.user_beer_logs where id = $1", log_id)
        assert row is not None

        await conn.execute(
            "update public.user_beer_logs set review = 'updated' where id = $1", log_id
        )
        result = await conn.execute("delete from public.user_beer_logs where id = $1", log_id)
        assert result == "DELETE 1"

    _run(integration_dsn, body)


def test_unfiltered_select_as_other_user_sees_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        # Deliberately no WHERE user_id at all, to prove RLS -- not this
        # query's own filter -- is what restricts visibility.
        rows = await conn.fetch("select id from public.user_beer_logs")
        assert rows == []

    _run(integration_dsn, body)


def test_unfiltered_update_as_other_user_affects_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        result = await conn.execute("update public.user_beer_logs set review = 'hijacked'")
        assert result == "UPDATE 0"

        await _set_identity(conn, _USER_A)
        row = await conn.fetchrow("select review from public.user_beer_logs limit 1")
        assert row["review"] is None

    _run(integration_dsn, body)


def test_unfiltered_delete_as_other_user_affects_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        result = await conn.execute("delete from public.user_beer_logs")
        assert result == "DELETE 0"

    _run(integration_dsn, body)


def test_insert_with_foreign_user_id_is_rejected_by_with_check(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_B)

        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                beer_id,
            )

    _run(integration_dsn, body)


def test_identity_absent_or_cleared_denies_all_rows_without_raising(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_A,
            beer_id,
        )

        # A genuinely fresh connection never calls set_config at all, so
        # current_setting('app.user_id', true) returns NULL there --
        # trivially satisfied by nullif(NULL, '') = NULL and not worth a
        # separate assertion. What actually needs proving is the case the
        # nullif(..., '') fix targets: a custom GUC that reads back as an
        # empty string rather than NULL. Both must fail closed identically
        # -- zero rows, no cast error -- since nullif() normalizes them to
        # the same NULL before the ::uuid cast ever runs.
        await conn.execute("select set_config('app.user_id', '', true)")
        rows = await conn.fetch("select id from public.user_beer_logs")
        assert rows == []
        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                beer_id,
            )

    _run(integration_dsn, body)


def test_no_session_level_leakage_across_committed_transactions(integration_dsn):
    """The one test in this file that cannot be verified inside a single
    rolled-back transaction: the property under test is specifically about
    what survives a real COMMIT on a reused connection. Runs against the
    disposable INTEGRATION_DATABASE_URL only (never DATABASE_URL/
    SEED_DATABASE_URL), and cleans up its own committed row explicitly in a
    finally block rather than relying on a rollback.
    """

    async def body() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(integration_dsn), ssl="require")
        log_id = beer_id = brewery_id = country_id = None
        try:
            async with conn.transaction():
                country_id = await conn.fetchval(
                    "insert into public.countries (iso_code, name, continent) "
                    "values ('ZZ', 'Test Land', 'Europe') returning id"
                )
                brewery_id = await conn.fetchval(
                    "insert into public.breweries (name, country_id) "
                    "values ('Test Brewery', $1) returning id",
                    country_id,
                )
                beer_id = await conn.fetchval(
                    "insert into public.beers (official_name, brewery_id) "
                    "values ('Test Beer', $1) returning id",
                    brewery_id,
                )
                await _as_backend_role(conn)
                await _set_identity(conn, _USER_A)
                log_id = await conn.fetchval(
                    "insert into public.user_beer_logs (user_id, beer_id) "
                    "values ($1, $2) returning id",
                    _USER_A,
                    beer_id,
                )
            # Transaction above committed. SET LOCAL's scope (both the role
            # switch and app.user_id) ends here, so neither must carry over
            # to the next transaction on this same, reused connection.

            async with conn.transaction():
                normalized = await conn.fetchval(
                    "select nullif(current_setting('app.user_id', true), '')"
                )
                assert normalized is None
                rows = await conn.fetch("select id from public.user_beer_logs")
                assert rows == []
        finally:
            # Cleanup runs as the connection's original (elevated) role --
            # SET LOCAL ROLE beerapp_backend from above no longer applies
            # once its transaction committed, and beerapp_backend couldn't
            # delete catalog rows regardless (SELECT-only there).
            if log_id is not None:
                async with conn.transaction():
                    await _as_backend_role(conn)
                    await _set_identity(conn, _USER_A)
                    await conn.execute("delete from public.user_beer_logs where id = $1", log_id)
            if beer_id is not None:
                await conn.execute("delete from public.beers where id = $1", beer_id)
            if brewery_id is not None:
                await conn.execute("delete from public.breweries where id = $1", brewery_id)
            if country_id is not None:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await conn.close()

    asyncio.run(body())
