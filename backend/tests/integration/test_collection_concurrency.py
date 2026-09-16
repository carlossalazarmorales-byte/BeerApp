"""Proves CollectionRepository.set_state's atomic upsert-then-delete design
is race-safe under real concurrent transactions -- see docs/DECISIONS.md for
the full derivation of the four required scenarios (A-D). These need two
genuinely separate connections/transactions racing on the same
(user_id, beer_id) row -- a single connection's savepoints can't model real
blocking/concurrency -- so unlike most tests in this suite these commit real
rows and clean up explicitly in a `finally`, mirroring
test_user_beer_logs_rls.py::test_no_session_level_leakage_across_committed_transactions.

Requires INTEGRATION_DATABASE_URL only. Never DATABASE_URL/SEED_DATABASE_URL.
"""

import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

from app.db import parse_dsn_kwargs
from app.repositories.collection import CollectionRepository

pytestmark = pytest.mark.integration

_USER_ID = "11111111-1111-1111-1111-111111111111"

# Races only sometimes manifest -- repeat each scenario so a flaky
# non-atomic implementation would be caught, not just occasionally pass.
_ITERATIONS = 10


class _SingleConnectionPool:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


async def _set_state(dsn: str, *, beer_id: str, is_favorite, is_wishlist) -> None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        async with conn.transaction():
            await conn.execute("set local role beerapp_backend")
            repository = CollectionRepository(_SingleConnectionPool(conn))
            await repository.set_state(
                user_id=_USER_ID, beer_id=beer_id, is_favorite=is_favorite, is_wishlist=is_wishlist
            )
    finally:
        await conn.close()


async def _seed_beer(dsn: str) -> str:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) "
            "values ('Test Brewery', $1) returning id",
            country_id,
        )
        return await conn.fetchval(
            "insert into public.beers (official_name, brewery_id) "
            "values ('Test Beer', $1) returning id",
            brewery_id,
        )
    finally:
        await conn.close()


async def _cleanup(dsn: str, beer_id: str) -> None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        await conn.execute(
            "delete from public.user_beer_collection where user_id = $1 and beer_id = $2",
            _USER_ID,
            beer_id,
        )
        row = await conn.fetchrow("select brewery_id from public.beers where id = $1", beer_id)
        await conn.execute("delete from public.beers where id = $1", beer_id)
        if row is not None:
            brewery = await conn.fetchrow(
                "select country_id from public.breweries where id = $1", row["brewery_id"]
            )
            await conn.execute("delete from public.breweries where id = $1", row["brewery_id"])
            if brewery is not None:
                await conn.execute(
                    "delete from public.countries where id = $1", brewery["country_id"]
                )
    finally:
        await conn.close()


async def _reset_row(dsn: str, beer_id: str, *, is_favorite: bool, is_wishlist: bool) -> None:
    """Deletes any existing row, then re-establishes the exact initial
    state each scenario needs, via one uncontended call (no concurrency here
    -- this is setup, not the thing under test).
    """
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        await conn.execute(
            "delete from public.user_beer_collection where user_id = $1 and beer_id = $2",
            _USER_ID,
            beer_id,
        )
    finally:
        await conn.close()
    if is_favorite or is_wishlist:
        await _set_state(dsn, beer_id=beer_id, is_favorite=is_favorite, is_wishlist=is_wishlist)


async def _read_state(dsn: str, beer_id: str) -> tuple[bool, bool] | None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        row = await conn.fetchrow(
            "select is_favorite, is_wishlist from public.user_beer_collection "
            "where user_id = $1 and beer_id = $2",
            _USER_ID,
            beer_id,
        )
        return None if row is None else (row["is_favorite"], row["is_wishlist"])
    finally:
        await conn.close()


async def _row_count(dsn: str, beer_id: str) -> int:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    try:
        return await conn.fetchval(
            "select count(*) from public.user_beer_collection where user_id = $1 and beer_id = $2",
            _USER_ID,
            beer_id,
        )
    finally:
        await conn.close()


def test_repeated_identical_patch_is_idempotent_and_does_not_bump_timestamp(integration_dsn):
    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None)
            conn = await asyncpg.connect(**parse_dsn_kwargs(integration_dsn), ssl="require")
            try:
                first = await conn.fetchrow(
                    "select favorited_at from public.user_beer_collection "
                    "where user_id = $1 and beer_id = $2",
                    _USER_ID,
                    beer_id,
                )
            finally:
                await conn.close()

            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None)
            conn = await asyncpg.connect(**parse_dsn_kwargs(integration_dsn), ssl="require")
            try:
                second = await conn.fetchrow(
                    "select favorited_at, is_favorite from public.user_beer_collection "
                    "where user_id = $1 and beer_id = $2",
                    _USER_ID,
                    beer_id,
                )
            finally:
                await conn.close()

            assert second["is_favorite"] is True
            assert second["favorited_at"] == first["favorited_at"]
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


def test_setting_one_flag_never_disturbs_the_other(integration_dsn):
    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=None, is_wishlist=True)
            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None)

            state = await _read_state(integration_dsn, beer_id)
            assert state == (True, True)
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


def test_clearing_last_true_flag_deletes_the_row(integration_dsn):
    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None)
            await _set_state(integration_dsn, beer_id=beer_id, is_favorite=False, is_wishlist=None)

            state = await _read_state(integration_dsn, beer_id)
            assert state is None
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


# -- the four required concurrency scenarios ---------------------------------


def test_scenario_a_concurrent_favorite_true_and_wishlist_false(integration_dsn):
    """Initial {false, true}; concurrent favorite=true / wishlist=false ->
    {true, false}.
    """

    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            for _ in range(_ITERATIONS):
                await _reset_row(integration_dsn, beer_id, is_favorite=False, is_wishlist=True)

                await asyncio.gather(
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None
                    ),
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=None, is_wishlist=False
                    ),
                )

                assert await _row_count(integration_dsn, beer_id) <= 1
                assert await _read_state(integration_dsn, beer_id) == (True, False)
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


def test_scenario_b_concurrent_first_writes_favorite_true_and_wishlist_true(integration_dsn):
    """No row; concurrent favorite=true / wishlist=true -> exactly one row,
    both true.
    """

    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            for _ in range(_ITERATIONS):
                await _reset_row(integration_dsn, beer_id, is_favorite=False, is_wishlist=False)

                await asyncio.gather(
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=True, is_wishlist=None
                    ),
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=None, is_wishlist=True
                    ),
                )

                assert await _row_count(integration_dsn, beer_id) == 1
                assert await _read_state(integration_dsn, beer_id) == (True, True)
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


def test_scenario_c_concurrent_clears_from_both_true_results_in_no_row(integration_dsn):
    """Initial {true, true}; concurrent favorite=false / wishlist=false ->
    no row.
    """

    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            for _ in range(_ITERATIONS):
                await _reset_row(integration_dsn, beer_id, is_favorite=True, is_wishlist=True)

                await asyncio.gather(
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=False, is_wishlist=None
                    ),
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=None, is_wishlist=False
                    ),
                )

                assert await _row_count(integration_dsn, beer_id) == 0
                assert await _read_state(integration_dsn, beer_id) is None
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())


def test_scenario_d_concurrent_first_writes_favorite_false_and_wishlist_true(integration_dsn):
    """No row; concurrent favorite=false / wishlist=true -> exactly one
    row, {false, true}.
    """

    async def scenario() -> None:
        beer_id = await _seed_beer(integration_dsn)
        try:
            for _ in range(_ITERATIONS):
                await _reset_row(integration_dsn, beer_id, is_favorite=False, is_wishlist=False)

                await asyncio.gather(
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=False, is_wishlist=None
                    ),
                    _set_state(
                        integration_dsn, beer_id=beer_id, is_favorite=None, is_wishlist=True
                    ),
                )

                assert await _row_count(integration_dsn, beer_id) == 1
                assert await _read_state(integration_dsn, beer_id) == (False, True)
        finally:
            await _cleanup(integration_dsn, beer_id)

    asyncio.run(scenario())
