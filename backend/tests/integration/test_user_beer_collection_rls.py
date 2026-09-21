"""Proves the user_beer_collection RLS backstop itself -- not just that the
repository's own `WHERE user_id = $N` filtering happens to work. Every test
here deliberately issues unfiltered or cross-identity SQL that a correct
repository would never write, to prove the database refuses it regardless.
Mirrors tests/integration/test_user_beer_logs_rls.py exactly, for the second
table on this pattern.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 7's migrations applied, whose connecting role can `SET ROLE
beerapp_backend`. Never run against DATABASE_URL/SEED_DATABASE_URL or the
shared dev project.
"""

import asyncio

import asyncpg
import pytest

from .disposable_db import connection_kwargs, ensure_users, remove_users

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"


async def _in_rolled_back_transaction(dsn: str, body) -> None:
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    transaction = conn.transaction()
    await transaction.start()
    try:
        await ensure_users(conn, _USER_A, _USER_B)
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
    await conn.execute("set local role beerapp_backend")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


def test_backend_role_can_crud_its_own_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)

        row_id = await conn.fetchval(
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now()) returning id",
            _USER_A,
            beer_id,
        )
        row = await conn.fetchrow(
            "select id from public.user_beer_collection where id = $1", row_id
        )
        assert row is not None

        await conn.execute(
            "update public.user_beer_collection "
            "set is_wishlist = true, wishlisted_at = now() where id = $1",
            row_id,
        )
        result = await conn.execute("delete from public.user_beer_collection where id = $1", row_id)
        assert result == "DELETE 1"

    _run(integration_dsn, body)


def test_unfiltered_select_as_other_user_sees_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        # Deliberately no WHERE user_id at all, to prove RLS -- not this
        # query's own filter -- is what restricts visibility.
        rows = await conn.fetch("select id from public.user_beer_collection")
        assert rows == []

    _run(integration_dsn, body)


def test_unfiltered_update_as_other_user_affects_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        result = await conn.execute(
            "update public.user_beer_collection set is_wishlist = true, wishlisted_at = now()"
        )
        assert result == "UPDATE 0"

        await _set_identity(conn, _USER_A)
        row = await conn.fetchrow("select is_wishlist from public.user_beer_collection limit 1")
        assert row["is_wishlist"] is False

    _run(integration_dsn, body)


def test_unfiltered_delete_as_other_user_affects_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
            _USER_A,
            beer_id,
        )

        await _set_identity(conn, _USER_B)
        result = await conn.execute("delete from public.user_beer_collection")
        assert result == "DELETE 0"

    _run(integration_dsn, body)


def test_insert_with_foreign_user_id_is_rejected_by_with_check(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_B)

        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_beer_collection "
                "(user_id, beer_id, is_favorite, favorited_at) "
                "values ($1, $2, true, now())",
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
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
            _USER_A,
            beer_id,
        )

        await conn.execute("select set_config('app.user_id', '', true)")
        rows = await conn.fetch("select id from public.user_beer_collection")
        assert rows == []
        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_beer_collection "
                "(user_id, beer_id, is_favorite, favorited_at) "
                "values ($1, $2, true, now())",
                _USER_A,
                beer_id,
            )

    _run(integration_dsn, body)


def test_no_session_level_leakage_across_committed_transactions(integration_dsn):
    """The one test in this file that cannot be verified inside a single
    rolled-back transaction -- mirrors
    test_user_beer_logs_rls.py::test_no_session_level_leakage_across_committed_transactions.
    """

    async def body() -> None:
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        row_id = beer_id = brewery_id = country_id = None
        try:
            await ensure_users(conn, _USER_A)
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
                row_id = await conn.fetchval(
                    "insert into public.user_beer_collection "
                    "(user_id, beer_id, is_favorite, favorited_at) "
                    "values ($1, $2, true, now()) returning id",
                    _USER_A,
                    beer_id,
                )

            async with conn.transaction():
                normalized = await conn.fetchval(
                    "select nullif(current_setting('app.user_id', true), '')"
                )
                assert normalized is None
                # The connecting admin role bypasses RLS, so re-adopt the
                # backend role WITHOUT an identity: if the previous
                # transaction's identity had leaked, its row would be
                # visible here.
                await _as_backend_role(conn)
                rows = await conn.fetch("select id from public.user_beer_collection")
                assert rows == []
        finally:
            if row_id is not None:
                async with conn.transaction():
                    await _as_backend_role(conn)
                    await _set_identity(conn, _USER_A)
                    await conn.execute(
                        "delete from public.user_beer_collection where id = $1", row_id
                    )
            if beer_id is not None:
                await conn.execute("delete from public.beers where id = $1", beer_id)
            if brewery_id is not None:
                await conn.execute("delete from public.breweries where id = $1", brewery_id)
            if country_id is not None:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await remove_users(conn, _USER_A)
            await conn.close()

    asyncio.run(body())
