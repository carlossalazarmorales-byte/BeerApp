from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import asyncpg


@asynccontextmanager
async def scoped_connection(
    pool: asyncpg.Pool, user_id: str, *, isolation: str | None = None
) -> AsyncIterator[asyncpg.Connection]:
    """Acquires a pooled connection, opens a transaction, and sets
    app.user_id via SET LOCAL for the RLS policies on user-owned tables
    (user_beer_logs, user_beer_collection). Transaction-scoped, never
    session-level -- the pool reuses physical connections across unrelated
    requests/users, and SET LOCAL is automatically unset at COMMIT/ROLLBACK,
    exactly when the connection returns to the pool. Callers still filter
    `where user_id = $N` explicitly on every query in addition to this --
    RLS is a backstop, not a replacement for careful queries.

    Extracted from BeerLogRepository._scoped (Phase 6) once a second
    consumer (CollectionRepository, Phase 7) needed the identical mechanism
    -- see docs/DECISIONS.md.

    `isolation` defaults to None, which leaves every existing caller's
    behavior (plain READ COMMITTED) exactly as it was before this parameter
    existed. It exists so a read-only, multi-statement aggregate (Phase 9's
    StatisticsRepository) can opt into "repeatable_read" to guarantee all of
    its statements observe one consistent snapshot, without changing
    behavior for any other feature -- see docs/DECISIONS.md.
    """
    async with pool.acquire() as conn:
        async with conn.transaction(isolation=isolation):
            await conn.execute("select set_config('app.user_id', $1, true)", user_id)
            yield conn
