"""Proves the Phase 10 atomicity fix against real PostgreSQL transaction
behavior: a Collection mutation and the achievement evaluation/unlock it may
cause must commit or roll back together, never independently -- see
docs/DECISIONS.md for why (a two-transaction version can silently lose a
permanently-earned achievement if evaluation fails after the mutation
commits and the condition is reversed before anything retries).

Uses a single real connection wrapped as a fake pool (CollectionService's
internal scoped_connection then opens a real, transaction-scoped savepoint
on it), inside an outer rolled-back transaction -- same technique as
tests/integration/test_collection_concurrency.py -- so nothing here is ever
actually committed to the database.

Requires INTEGRATION_DATABASE_URL only. Never DATABASE_URL/SEED_DATABASE_URL.
"""

import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

from app.repositories.achievements import AchievementsRepository
from app.repositories.collection import CollectionRepository
from app.schemas.collection import CollectionStateUpdate
from app.services.achievement_evaluator import AchievementEvaluator
from app.services.collection import CollectionService

from .disposable_db import connection_kwargs, ensure_users

pytestmark = pytest.mark.integration

_USER_ID = "11111111-1111-1111-1111-111111111111"


class _SingleConnectionPool:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


class _FailingEvaluator:
    """Stands in for AchievementEvaluator to prove the Collection mutation
    rolls back when evaluation fails -- the real evaluator's own logic is
    covered by tests/services/test_achievement_evaluator_service.py.
    """

    async def evaluate_and_unlock(self, conn: asyncpg.Connection, *, user_id: str) -> None:
        raise RuntimeError("simulated evaluator failure")


async def _in_rolled_back_transaction(dsn: str, body) -> None:
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    transaction = conn.transaction()
    await transaction.start()
    try:
        await ensure_users(conn, _USER_ID)
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


def _make_service(conn: asyncpg.Connection, evaluator=None) -> CollectionService:
    pool = _SingleConnectionPool(conn)
    evaluator = evaluator or AchievementEvaluator(AchievementsRepository())
    return CollectionService(CollectionRepository(pool), pool, evaluator)


async def _collection_row_count(conn: asyncpg.Connection, *, user_id: str, beer_id: str) -> int:
    return await conn.fetchval(
        "select count(*) from public.user_beer_collection where user_id = $1 and beer_id = $2",
        user_id,
        beer_id,
    )


async def _unlocked_keys(conn: asyncpg.Connection, *, user_id: str) -> set[str]:
    rows = await conn.fetch(
        "select achievement_key from public.user_achievements where user_id = $1", user_id
    )
    return {row["achievement_key"] for row in rows}


def test_successful_mutation_commits_collection_state_and_unlock_together(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        service = _make_service(conn)

        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=True)
        )

        assert await _collection_row_count(conn, user_id=_USER_ID, beer_id=beer_id) == 1
        assert "collection_first_favorite" in await _unlocked_keys(conn, user_id=_USER_ID)

    _run(integration_dsn, body)


def test_evaluator_failure_rolls_back_the_collection_mutation_too(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        service = _make_service(conn, evaluator=_FailingEvaluator())

        with pytest.raises(RuntimeError):
            await service.set_state(
                user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=True)
            )

        # The Collection upsert ran on the same (now rolled-back) savepoint
        # as the failed evaluation -- it must not have survived either.
        assert await _collection_row_count(conn, user_id=_USER_ID, beer_id=beer_id) == 0
        assert await _unlocked_keys(conn, user_id=_USER_ID) == set()

    _run(integration_dsn, body)


def test_repeated_qualifying_mutations_never_duplicate_or_change_unlocked_at(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        service = _make_service(conn)

        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=True)
        )
        first_unlocked_at = await conn.fetchval(
            "select unlocked_at from public.user_achievements "
            "where user_id = $1 and achievement_key = 'collection_first_favorite'",
            _USER_ID,
        )

        # Unfavorite, then favorite again -- two more qualifying evaluations.
        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=False)
        )
        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=True)
        )

        rows = await conn.fetch(
            "select unlocked_at from public.user_achievements "
            "where user_id = $1 and achievement_key = 'collection_first_favorite'",
            _USER_ID,
        )
        assert len(rows) == 1
        assert rows[0]["unlocked_at"] == first_unlocked_at

    _run(integration_dsn, body)


def test_unfavoriting_after_unlock_does_not_delete_or_modify_the_achievement_row(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await _as_backend_role(conn)
        service = _make_service(conn)

        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=True)
        )
        await service.set_state(
            user_id=_USER_ID, beer_id=beer_id, payload=CollectionStateUpdate(is_favorite=False)
        )

        # Collection state is gone (both flags false -> row deleted, per
        # existing Phase 7 behavior)...
        assert await _collection_row_count(conn, user_id=_USER_ID, beer_id=beer_id) == 0
        # ...but the permanent unlock remains.
        assert "collection_first_favorite" in await _unlocked_keys(conn, user_id=_USER_ID)

    _run(integration_dsn, body)
