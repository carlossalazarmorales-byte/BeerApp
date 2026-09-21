"""Guard that keeps the integration suite off any shared or real database.

Several integration tests deliberately issue SQL a correct repository would
never write, and a few commit real rows. They must therefore only ever run
against a disposable database (a local Supabase stack, or a local Postgres
scaffold) -- never the shared dev project, never production.

This module is pure (no I/O) so the rules are unit-testable in the default
suite. Error messages carry variable names and hosts only, never credentials.
"""

import asyncio
from urllib.parse import parse_qs, urlsplit

import asyncpg

from app.db import parse_dsn_kwargs

LOOPBACK_HOSTS = frozenset({"localhost", "127.0.0.1", "::1"})

# Opt-in for a dedicated, hosted, disposable test database. Off by default so
# a mis-set INTEGRATION_DATABASE_URL can never silently reach a remote server.
ALLOW_REMOTE_ENV_VAR = "INTEGRATION_DATABASE_ALLOW_REMOTE"


class NotDisposableDatabaseError(Exception):
    """INTEGRATION_DATABASE_URL does not point at a disposable database."""


def _host(dsn: str | None) -> str | None:
    if not dsn:
        return None
    try:
        return (urlsplit(dsn).hostname or "").lower() or None
    except ValueError:
        return None


def require_disposable_database(
    integration_url: str,
    *,
    protected_urls: dict[str, str | None],
    allow_remote: bool = False,
) -> None:
    """Raise NotDisposableDatabaseError unless `integration_url` is safe.

    `protected_urls` maps a variable name (e.g. "DATABASE_URL") to its value;
    the integration URL may not equal any of them nor share their host, since
    the same server is the same database project. Unless `allow_remote`, the
    host must also be loopback.
    """
    host = _host(integration_url)
    if host is None:
        raise NotDisposableDatabaseError(
            "INTEGRATION_DATABASE_URL has no parseable host; refusing to run."
        )

    # Exact matches first, across every protected URL, so the message names the
    # variable that was actually reused rather than one that merely shares a host.
    for name, value in protected_urls.items():
        if value and integration_url == value:
            raise NotDisposableDatabaseError(
                f"INTEGRATION_DATABASE_URL is identical to {name}. Integration tests "
                "must never run against that database."
            )
    for name, value in protected_urls.items():
        if host == _host(value):
            raise NotDisposableDatabaseError(
                f"INTEGRATION_DATABASE_URL points at the same host as {name} ({host}). "
                "Integration tests must use a separate, disposable database."
            )

    if host not in LOOPBACK_HOSTS and not allow_remote:
        raise NotDisposableDatabaseError(
            f"INTEGRATION_DATABASE_URL host {host!r} is not loopback. Use a local "
            f"disposable database, or set {ALLOW_REMOTE_ENV_VAR}=1 for a dedicated "
            "hosted test database that is neither the dev nor a production project."
        )


def connection_kwargs(dsn: str) -> dict:
    """asyncpg keyword arguments for a disposable-database DSN.

    TLS follows the DSN's own `sslmode` (a local Postgres / Supabase stack
    usually has no TLS). With no `sslmode`, a loopback host is `prefer` and any
    other host is `require`. This is the integration suite's connection only;
    the running application's pool (app/db.py) always requires SSL and is
    unaffected.
    """
    kwargs = parse_dsn_kwargs(dsn)
    sslmode = (parse_qs(urlsplit(dsn).query).get("sslmode") or [None])[0]
    if sslmode is None:
        host = (kwargs["host"] or "").lower()
        sslmode = "prefer" if host in LOOPBACK_HOSTS else "require"
    kwargs["ssl"] = sslmode
    return kwargs


async def ensure_users(conn, *user_ids: str) -> None:
    """Create real `auth.users` rows for the given ids (idempotent).

    Every `user_id` column references `auth.users(id)`, so a made-up UUID
    violates the foreign key -- the reason these older tests failed against a
    real database. Call it as the connection's admin role BEFORE any `SET
    ROLE`; inside a rolled-back transaction the users disappear with it, and
    for tests that commit, the test's cleanup must delete them (cascading to
    everything user-owned).
    """
    await conn.execute(
        "insert into auth.users (id) select unnest($1::uuid[]) on conflict (id) do nothing",
        list(user_ids),
    )


async def remove_users(conn, *user_ids: str) -> None:
    """Delete the `auth.users` rows created by `ensure_users` for a test that
    COMMITTED. The user-owned tables all cascade from `auth.users`, so this also
    removes their logs, collection rows, achievements, contributions and profile.
    """
    await conn.execute("delete from auth.users where id = any($1::uuid[])", list(user_ids))


def run_rolled_back(dsn: str, body, *, users: tuple[str, ...] = ()) -> None:
    """Run `async body(conn)` as the connecting admin role inside a transaction
    that is ALWAYS rolled back, after creating real `auth.users` rows for
    `users`. Nothing a test does here is ever committed.
    """

    async def main() -> None:
        conn = await asyncpg.connect(**connection_kwargs(dsn))
        transaction = conn.transaction()
        await transaction.start()
        try:
            if users:
                await ensure_users(conn, *users)
            await body(conn)
        finally:
            await transaction.rollback()
            await conn.close()

    asyncio.run(main())
