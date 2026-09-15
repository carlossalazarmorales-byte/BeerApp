import os

import pytest


@pytest.fixture
def integration_dsn() -> str:
    """DSN for a disposable/test schema, deliberately never DATABASE_URL or
    SEED_DATABASE_URL -- see docs/DATABASE.md. Tests using this fixture must
    run their work inside a transaction that is rolled back, so no test
    data is ever committed.
    """
    dsn = os.environ.get("INTEGRATION_DATABASE_URL")
    if not dsn:
        pytest.skip("INTEGRATION_DATABASE_URL is not set; skipping integration test.")
    return dsn


@pytest.fixture
def backend_role_dsn() -> str:
    """DATABASE_URL -- the real least-privilege `beerapp_backend` role.
    Safe to use directly here: this role has no write privilege at all, so
    nothing these tests do can mutate real data -- that lack of write
    privilege is exactly what they verify.
    """
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        pytest.skip("DATABASE_URL is not set; skipping integration test.")
    return dsn
