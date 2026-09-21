from urllib.parse import unquote, urlsplit

import asyncpg

from app.config import Settings


def parse_dsn_kwargs(database_url: str) -> dict:
    """Parses a postgresql:// DSN into explicit asyncpg connection kwargs
    rather than passing the DSN string straight through.

    asyncpg's own DSN-string parser does not reliably decode a
    percent-encoded password containing URL-reserved characters (`@`, `=`,
    `\\`) -- confirmed against this project's actual generated role
    passwords, which produced `InvalidPasswordError` via `dsn=` even though
    the same credentials connect successfully as explicit kwargs. Python's
    standard library `urlsplit`/`unquote` parse it correctly, so DSNs are
    always decomposed this way rather than passed through as a raw string.
    """
    parts = urlsplit(database_url)
    return {
        "user": unquote(parts.username or ""),
        "password": unquote(parts.password or ""),
        "host": parts.hostname,
        "port": parts.port,
        "database": parts.path.lstrip("/"),
    }


class AcquireTimeoutPool:
    """A thin proxy over an asyncpg pool that gives every `acquire()` a
    timeout by default.

    asyncpg's `Pool.acquire()` waits indefinitely when all connections are
    busy. Every repository calls `pool.acquire()` (directly, or through
    `scoped_connection`), so bounding it in one place -- instead of editing a
    dozen call sites -- keeps a saturated pool from hanging requests. On
    timeout asyncpg raises `TimeoutError`, which the API reports as a
    sanitized 503 (see app/errors.py). Everything else delegates untouched.
    """

    def __init__(self, pool: asyncpg.Pool, acquire_timeout: float) -> None:
        self._pool = pool
        self._acquire_timeout = acquire_timeout

    def acquire(self, *, timeout: float | None = None):
        return self._pool.acquire(timeout=self._acquire_timeout if timeout is None else timeout)

    def __getattr__(self, name: str):
        return getattr(self._pool, name)


async def create_pool(settings: Settings) -> AcquireTimeoutPool:
    """Create the runtime connection pool as the least-privilege
    `beerapp_backend` role (see docs/DATABASE.md). SSL is required
    explicitly here rather than relied upon from the DSN, so it can't be
    silently dropped by editing DATABASE_URL.

    Bounded on every axis: `timeout` caps opening a connection,
    `command_timeout` caps each statement, and the returned pool caps how long
    a request waits for a free connection.
    """
    pool = await asyncpg.create_pool(
        **parse_dsn_kwargs(settings.database_url),
        min_size=settings.db_pool_min_size,
        max_size=settings.db_pool_max_size,
        ssl="require",
        statement_cache_size=settings.db_statement_cache_size,
        timeout=settings.db_connect_timeout_seconds,
        command_timeout=settings.db_command_timeout_seconds,
    )
    return AcquireTimeoutPool(pool, settings.db_acquire_timeout_seconds)
