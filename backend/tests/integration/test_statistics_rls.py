"""Proves the RLS backstop for Statistics aggregates -- that every aggregate
query StatisticsRepository issues is restricted by the database itself, not
merely by the repository's own `WHERE user_id = $N`, and that
StatisticsRepository.get_statistics() end-to-end never mixes one user's
numbers into another's response. Mirrors
tests/integration/test_user_beer_collection_rls.py's structure and style.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with all
migrations applied, whose connecting role can `SET ROLE beerapp_backend`.
Never run against DATABASE_URL/SEED_DATABASE_URL or the shared dev project.
"""

import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

from app.repositories.statistics import StatisticsRepository

from .disposable_db import connection_kwargs, ensure_users, remove_users

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"


class _SingleConnectionPool:
    """Stands in for the app's pool: the repository acquires the connection AS
    `beerapp_backend` (so RLS applies together with the repository's own
    filtering, exactly as in production) and returns it as the connecting admin
    role on exit, which is what test setup and cleanup need.
    """

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn
        self._depth = 0

    @asynccontextmanager
    async def acquire(self):
        if self._depth == 0:
            await self._conn.execute("set role beerapp_backend")
        self._depth += 1
        try:
            yield self._conn
        finally:
            self._depth -= 1
            if self._depth == 0:
                await self._conn.execute("reset role")


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set local role beerapp_backend")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


async def _seed_beer(conn: asyncpg.Connection, *, name: str = "Test Beer") -> str:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ($1, $2) returning id",
        f"{name} Brewery",
        country_id,
    )
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ($1, $2) returning id",
        name,
        brewery_id,
    )


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


# -- unfiltered aggregate queries only reflect the caller's own rows --------


def test_unfiltered_count_as_user_a_excludes_user_bs_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)

        await _set_identity(conn, _USER_A)
        for _ in range(2):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                beer_id,
            )

        await _set_identity(conn, _USER_B)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_B,
            beer_id,
        )

        await _set_identity(conn, _USER_A)
        # Deliberately unfiltered -- the same shape of statement
        # StatisticsRepository's overview query runs -- to prove RLS, not
        # this test's own WHERE clause, is what restricts the count.
        total = await conn.fetchval("select count(*) from public.user_beer_logs")
        assert total == 2

    _run(integration_dsn, body)


def test_unfiltered_favorites_aggregate_as_user_a_excludes_user_b(integration_dsn):
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
        await conn.execute(
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, favorited_at) "
            "values ($1, $2, true, now())",
            _USER_B,
            beer_id,
        )

        await _set_identity(conn, _USER_A)
        count = await conn.fetchval(
            "select count(*) from public.user_beer_collection where is_favorite = true"
        )
        assert count == 1

    _run(integration_dsn, body)


def test_identity_cleared_denies_all_rows_for_aggregate_without_raising(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
            _USER_A,
            beer_id,
        )

        await conn.execute("select set_config('app.user_id', '', true)")
        total = await conn.fetchval("select count(*) from public.user_beer_logs")
        assert total == 0

    _run(integration_dsn, body)


def test_no_session_level_leakage_across_committed_transactions_for_aggregate(integration_dsn):
    """The one test in this file that cannot be verified inside a single
    rolled-back transaction -- mirrors
    test_user_beer_collection_rls.py::test_no_session_level_leakage_across_committed_transactions.
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
                    "insert into public.user_beer_logs (user_id, beer_id) "
                    "values ($1, $2) returning id",
                    _USER_A,
                    beer_id,
                )

            async with conn.transaction():
                normalized = await conn.fetchval(
                    "select nullif(current_setting('app.user_id', true), '')"
                )
                assert normalized is None
                # The connecting admin role bypasses RLS: re-adopt the backend role
                # WITHOUT an identity, so a leaked identity would show its row.
                await _as_backend_role(conn)
                total = await conn.fetchval("select count(*) from public.user_beer_logs")
                assert total == 0
        finally:
            if row_id is not None:
                async with conn.transaction():
                    await _as_backend_role(conn)
                    await _set_identity(conn, _USER_A)
                    await conn.execute("delete from public.user_beer_logs where id = $1", row_id)
            if beer_id is not None:
                await conn.execute("delete from public.beers where id = $1", beer_id)
            if brewery_id is not None:
                await conn.execute("delete from public.breweries where id = $1", brewery_id)
            if country_id is not None:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await remove_users(conn, _USER_A)
            await conn.close()

    asyncio.run(body())


# -- end-to-end: StatisticsRepository.get_statistics never cross-contaminates -


def test_get_statistics_never_mixes_two_users_data(integration_dsn):
    """StatisticsRepository._scoped() opens its transaction at REPEATABLE
    READ, which Postgres refuses to change on a nested transaction/SAVEPOINT
    -- so this test runs seeding, both get_statistics() calls, and cleanup
    as separate top-level transactions on the connection (same reasoning as
    tests/integration/test_statistics_queries.py's _seed_and_get_statistics),
    rather than the single-rolled-back-transaction pattern used above.
    """

    async def run():
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        beer_a = beer_b = brewery_a = brewery_b = country_id = None
        try:
            await ensure_users(conn, _USER_A, _USER_B)
            async with conn.transaction():
                country_id = await conn.fetchval(
                    "insert into public.countries (iso_code, name, continent) "
                    "values ('ZZ', 'Test Land', 'Europe') returning id"
                )
                brewery_a = await conn.fetchval(
                    "insert into public.breweries (name, country_id) "
                    "values ('Brewery A', $1) returning id",
                    country_id,
                )
                brewery_b = await conn.fetchval(
                    "insert into public.breweries (name, country_id) "
                    "values ('Brewery B', $1) returning id",
                    country_id,
                )
                beer_a = await conn.fetchval(
                    "insert into public.beers (official_name, brewery_id) "
                    "values ('Beer A', $1) returning id",
                    brewery_a,
                )
                beer_b = await conn.fetchval(
                    "insert into public.beers (official_name, brewery_id) "
                    "values ('Beer B', $1) returning id",
                    brewery_b,
                )

                await _as_backend_role(conn)
                await _set_identity(conn, _USER_A)
                for _ in range(2):
                    await conn.execute(
                        "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                        _USER_A,
                        beer_a,
                    )
                await conn.execute(
                    "insert into public.user_beer_collection "
                    "(user_id, beer_id, is_favorite, favorited_at) "
                    "values ($1, $2, true, now())",
                    _USER_A,
                    beer_a,
                )

                await _set_identity(conn, _USER_B)
                await conn.execute(
                    "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                    _USER_B,
                    beer_b,
                )
                await conn.execute(
                    "insert into public.user_beer_collection "
                    "(user_id, beer_id, is_favorite, favorited_at) "
                    "values ($1, $2, true, now())",
                    _USER_B,
                    beer_b,
                )

            repository = StatisticsRepository(_SingleConnectionPool(conn))
            stats_a = await repository.get_statistics(user_id=_USER_A)
            stats_b = await repository.get_statistics(user_id=_USER_B)
            return stats_a, stats_b
        finally:
            async with conn.transaction():
                await _as_backend_role(conn)
                for user_id, beer_id in ((_USER_A, beer_a), (_USER_B, beer_b)):
                    if beer_id is None:
                        continue
                    await _set_identity(conn, user_id)
                    await conn.execute(
                        "delete from public.user_beer_logs where user_id = $1 and beer_id = $2",
                        user_id,
                        beer_id,
                    )
                    await conn.execute(
                        "delete from public.user_beer_collection "
                        "where user_id = $1 and beer_id = $2",
                        user_id,
                        beer_id,
                    )
            for beer_id in (beer_a, beer_b):
                if beer_id is not None:
                    await conn.execute("delete from public.beers where id = $1", beer_id)
            for brewery_id in (brewery_a, brewery_b):
                if brewery_id is not None:
                    await conn.execute("delete from public.breweries where id = $1", brewery_id)
            if country_id is not None:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await remove_users(conn, _USER_A, _USER_B)
            await conn.close()

    stats_a, stats_b = asyncio.run(run())

    assert stats_a["overview"]["total_logs"] == 2
    assert stats_a["favorites"]["favorite_brewery"] == "Brewery A"
    assert stats_b["overview"]["total_logs"] == 1
    assert stats_b["favorites"]["favorite_brewery"] == "Brewery B"
