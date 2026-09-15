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


async def create_pool(settings: Settings) -> asyncpg.Pool:
    """Create the runtime connection pool as the least-privilege
    `beerapp_backend` role (see docs/DATABASE.md). SSL is required
    explicitly here rather than relied upon from the DSN, so it can't be
    silently dropped by editing DATABASE_URL.
    """
    return await asyncpg.create_pool(
        **parse_dsn_kwargs(settings.database_url),
        min_size=settings.db_pool_min_size,
        max_size=settings.db_pool_max_size,
        ssl="require",
        statement_cache_size=settings.db_statement_cache_size,
    )
