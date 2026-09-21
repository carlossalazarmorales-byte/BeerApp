"""Proves the user_achievements RLS/grant shape itself -- not just that the
repository's own filtering happens to work. Adapted from
test_user_beer_logs_rls.py / test_user_beer_collection_rls.py for the
two-command-specific-policy shape (backend_select_own / backend_insert_own)
and the deliberate absence of UPDATE/DELETE grants (see docs/DECISIONS.md):
achievements are permanent once unlocked, so revocation/rewriting must be
impossible at the database level, not merely by application convention.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with
Phase 10's migrations applied, whose connecting role can `SET ROLE
beerapp_backend`. Never run against DATABASE_URL/SEED_DATABASE_URL or the
shared dev project.
"""

import asyncio

import asyncpg
import pytest

from .disposable_db import connection_kwargs, ensure_users

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"
_KEY = "collection_first_favorite"


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


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set local role beerapp_backend")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


def test_backend_role_can_insert_and_select_its_own_rows(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)

        row_id = await conn.fetchval(
            "insert into public.user_achievements (user_id, achievement_key) "
            "values ($1, $2) returning id",
            _USER_A,
            _KEY,
        )
        row = await conn.fetchrow("select id from public.user_achievements where id = $1", row_id)
        assert row is not None

    _run(integration_dsn, body)


def test_unfiltered_select_as_other_user_sees_nothing(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_achievements (user_id, achievement_key) values ($1, $2)",
            _USER_A,
            _KEY,
        )

        await _set_identity(conn, _USER_B)
        # Deliberately no WHERE user_id at all, to prove RLS (backend_select_own)
        # -- not this query's own filter -- is what restricts visibility.
        rows = await conn.fetch("select id from public.user_achievements")
        assert rows == []

    _run(integration_dsn, body)


def test_insert_with_foreign_user_id_is_rejected_by_with_check(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_B)

        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_achievements (user_id, achievement_key) values ($1, $2)",
                _USER_A,
                _KEY,
            )

    _run(integration_dsn, body)


def test_identity_absent_or_cleared_denies_all_rows_without_raising(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        await conn.execute(
            "insert into public.user_achievements (user_id, achievement_key) values ($1, $2)",
            _USER_A,
            _KEY,
        )

        await conn.execute("select set_config('app.user_id', '', true)")
        rows = await conn.fetch("select id from public.user_achievements")
        assert rows == []
        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "insert into public.user_achievements (user_id, achievement_key) values ($1, $2)",
                _USER_A,
                _KEY,
            )

    _run(integration_dsn, body)


def test_backend_role_cannot_update(integration_dsn):
    """No backend_owns_rows-style UPDATE policy or grant exists at all for
    this table -- separate test from the DELETE case below since a
    privilege error aborts the rest of the enclosing transaction.
    """

    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        row_id = await conn.fetchval(
            "insert into public.user_achievements (user_id, achievement_key) "
            "values ($1, $2) returning id",
            _USER_A,
            _KEY,
        )

        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute(
                "update public.user_achievements set achievement_key = 'other' where id = $1",
                row_id,
            )

    _run(integration_dsn, body)


def test_backend_role_cannot_delete(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)
        row_id = await conn.fetchval(
            "insert into public.user_achievements (user_id, achievement_key) "
            "values ($1, $2) returning id",
            _USER_A,
            _KEY,
        )

        with pytest.raises(asyncpg.InsufficientPrivilegeError):
            await conn.execute("delete from public.user_achievements where id = $1", row_id)

    _run(integration_dsn, body)


def test_repeated_insert_of_the_same_key_is_a_no_op_and_preserves_unlocked_at(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await _as_backend_role(conn)
        await _set_identity(conn, _USER_A)

        first = await conn.fetchrow(
            "insert into public.user_achievements (user_id, achievement_key) "
            "values ($1, $2) "
            "on conflict (user_id, achievement_key) do nothing "
            "returning id, unlocked_at",
            _USER_A,
            _KEY,
        )
        assert first is not None

        second = await conn.fetchrow(
            "insert into public.user_achievements (user_id, achievement_key) "
            "values ($1, $2) "
            "on conflict (user_id, achievement_key) do nothing "
            "returning id, unlocked_at",
            _USER_A,
            _KEY,
        )
        assert second is None  # ON CONFLICT DO NOTHING -- no second row, nothing returned

        rows = await conn.fetch(
            "select id, unlocked_at from public.user_achievements "
            "where user_id = $1 and achievement_key = $2",
            _USER_A,
            _KEY,
        )
        assert len(rows) == 1
        assert rows[0]["unlocked_at"] == first["unlocked_at"]

    _run(integration_dsn, body)
