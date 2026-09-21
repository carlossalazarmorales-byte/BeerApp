import os

import pytest

from .disposable_db import (
    ALLOW_REMOTE_ENV_VAR,
    NotDisposableDatabaseError,
    require_disposable_database,
)


@pytest.fixture
def integration_dsn() -> str:
    """DSN for a disposable database -- never DATABASE_URL or SEED_DATABASE_URL.

    Refuses (fails, does not skip) if it equals or shares a host with either of
    those, or is not a loopback host unless INTEGRATION_DATABASE_ALLOW_REMOTE=1
    -- see disposable_db.py. Most tests run inside a rolled-back transaction,
    but a few (collection concurrency, statistics setup, the contributions
    end-to-end) commit real rows and clean up afterwards, so the target must be
    a database nobody else depends on. See docs/DATABASE.md.
    """
    dsn = os.environ.get("INTEGRATION_DATABASE_URL")
    if not dsn:
        pytest.skip("INTEGRATION_DATABASE_URL is not set; skipping integration test.")
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
        pytest.fail(str(exc), pytrace=False)
    return dsn
