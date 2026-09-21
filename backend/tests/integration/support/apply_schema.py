"""Apply the integration scaffold and every repository migration to a DISPOSABLE
database. Test support only; platform-neutral; installs nothing.

    INTEGRATION_DATABASE_URL=postgresql://postgres@127.0.0.1:5432/beerapp_test \\
        python backend/tests/integration/support/apply_schema.py

It refuses to run unless INTEGRATION_DATABASE_URL passes the same guard the
integration suite uses (a loopback host, and not DATABASE_URL / SEED_DATABASE_URL
or their host), and it never drops or resets anything: point it at an EMPTY
database on a throwaway cluster. It applies, in order:

  1. support/supabase_scaffold.sql
  2. supabase/migrations/*.sql, in filename order

Prefer a real local Supabase stack (`supabase start`, needs Docker) when you can;
this is the fallback for machines without Docker. See docs/DATABASE.md.
"""

import asyncio
import os
import sys
from pathlib import Path

import asyncpg

try:
    from ..disposable_db import (
        ALLOW_REMOTE_ENV_VAR,
        NotDisposableDatabaseError,
        connection_kwargs,
        require_disposable_database,
    )
except ImportError:  # executed as a script rather than imported by the test suite
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tests.integration.disposable_db import (
        ALLOW_REMOTE_ENV_VAR,
        NotDisposableDatabaseError,
        connection_kwargs,
        require_disposable_database,
    )

SUPPORT_DIR = Path(__file__).resolve().parent
SCAFFOLD_SQL = SUPPORT_DIR / "supabase_scaffold.sql"
# support -> integration -> tests -> backend -> repository root
MIGRATIONS_DIR = Path(__file__).resolve().parents[4] / "supabase" / "migrations"


def schema_files() -> list[Path]:
    """The scaffold first, then every migration in filename (= timestamp) order."""
    return [SCAFFOLD_SQL, *sorted(MIGRATIONS_DIR.glob("*.sql"))]


async def apply_schema(dsn: str, files: list[Path] | None = None) -> list[str]:
    """Apply `files` (default: `schema_files()`) to `dsn`; return the applied names.

    Refuses an already-scaffolded database rather than guessing what to change.
    """
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    try:
        if await conn.fetchval("select exists (select 1 from pg_namespace where nspname = 'auth')"):
            raise SystemExit(
                "The database already has an `auth` schema: the scaffold has been applied "
                "(or this is a real Supabase database). Use a new, empty database."
            )
        applied = []
        for path in files or schema_files():
            await conn.execute(path.read_text(encoding="utf-8"))
            applied.append(path.name)
        return applied
    finally:
        await conn.close()


def main() -> None:
    dsn = os.environ.get("INTEGRATION_DATABASE_URL")
    if not dsn:
        raise SystemExit("INTEGRATION_DATABASE_URL is not set.")
    try:
        require_disposable_database(
            dsn,
            protected_urls={
                "DATABASE_URL": os.environ.get("DATABASE_URL"),
                "SEED_DATABASE_URL": os.environ.get("SEED_DATABASE_URL"),
            },
            allow_remote=os.environ.get(ALLOW_REMOTE_ENV_VAR) == "1",
        )
    except NotDisposableDatabaseError as exc:
        raise SystemExit(f"Refusing to apply the schema: {exc}") from exc

    applied = asyncio.run(apply_schema(dsn))
    print(f"Applied {len(applied)} files: {applied[0]} + {len(applied) - 1} migrations.")


if __name__ == "__main__":
    main()
