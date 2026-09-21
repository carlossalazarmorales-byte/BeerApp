"""Unit tests for the integration suite's disposable-database guard.

Deliberately NOT marked `integration`: these are pure (no database) and must
run in the default suite so the guard itself can never silently rot.
"""

import pytest

from .disposable_db import (
    NotDisposableDatabaseError,
    connection_kwargs,
    require_disposable_database,
)

# Fabricated DSNs on the reserved `.invalid` TLD -- never a real credential.
_DEV = "postgresql://beerapp_backend.testref:pw-a@pooler.example.invalid:5432/postgres"
_SEED = "postgresql://beerapp_seed.testref:pw-b@pooler.example.invalid:5432/postgres"
_LOCAL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
_PROTECTED = {"DATABASE_URL": _DEV, "SEED_DATABASE_URL": _SEED}


@pytest.mark.parametrize(
    "url",
    [
        _LOCAL,
        "postgresql://postgres:postgres@localhost:5432/beerapp_test",
        "postgresql://postgres:postgres@[::1]:5432/beerapp_test",
        "postgresql://postgres:postgres@LOCALHOST:5432/beerapp_test",
    ],
)
def test_a_loopback_database_distinct_from_the_protected_ones_is_allowed(url):
    require_disposable_database(url, protected_urls=_PROTECTED)


def test_refuses_the_runtime_database_url_itself():
    with pytest.raises(NotDisposableDatabaseError, match="identical to DATABASE_URL"):
        require_disposable_database(_DEV, protected_urls=_PROTECTED, allow_remote=True)


def test_refuses_the_seed_database_url_itself():
    with pytest.raises(NotDisposableDatabaseError, match="identical to SEED_DATABASE_URL"):
        require_disposable_database(_SEED, protected_urls=_PROTECTED, allow_remote=True)


def test_refuses_another_role_on_the_same_host_as_a_protected_url():
    same_host_other_db = "postgresql://postgres:x@pooler.example.invalid:5432/other"

    with pytest.raises(NotDisposableDatabaseError, match="same host as"):
        require_disposable_database(
            same_host_other_db, protected_urls=_PROTECTED, allow_remote=True
        )


def test_refuses_a_remote_host_by_default():
    with pytest.raises(NotDisposableDatabaseError, match="not loopback"):
        require_disposable_database(
            "postgresql://postgres:x@test-db.example.invalid:5432/postgres",
            protected_urls=_PROTECTED,
        )


def test_a_dedicated_remote_host_is_allowed_only_with_explicit_opt_in():
    require_disposable_database(
        "postgresql://postgres:x@test-db.example.invalid:5432/postgres",
        protected_urls=_PROTECTED,
        allow_remote=True,
    )


@pytest.mark.parametrize("url", ["", "not a url", "postgresql:///nohost"])
def test_refuses_an_unparseable_or_hostless_url(url):
    with pytest.raises(NotDisposableDatabaseError, match="no parseable host"):
        require_disposable_database(url, protected_urls=_PROTECTED)


def test_unset_protected_variables_do_not_block_a_local_database():
    require_disposable_database(
        _LOCAL, protected_urls={"DATABASE_URL": None, "SEED_DATABASE_URL": None}
    )


def test_error_messages_never_contain_passwords():
    with pytest.raises(NotDisposableDatabaseError) as excinfo:
        require_disposable_database(_DEV, protected_urls=_PROTECTED)

    assert "pw-a" not in str(excinfo.value)
    assert "pw-b" not in str(excinfo.value)


# -- connection_kwargs: TLS follows the DSN, never a blanket "require" -------------------


@pytest.mark.parametrize("mode", ["disable", "allow", "prefer", "require", "verify-full"])
def test_connection_kwargs_honors_an_explicit_sslmode(mode):
    kwargs = connection_kwargs(f"postgresql://postgres@127.0.0.1:54322/postgres?sslmode={mode}")

    assert kwargs["ssl"] == mode


def test_a_loopback_dsn_without_sslmode_does_not_demand_tls():
    # A local Postgres / Supabase stack normally has no TLS configured.
    assert connection_kwargs("postgresql://postgres@127.0.0.1:54322/postgres")["ssl"] == "prefer"
    assert connection_kwargs("postgresql://postgres@localhost:5432/postgres")["ssl"] == "prefer"


def test_a_remote_dsn_without_sslmode_still_requires_tls():
    remote = "postgresql://postgres:x@test-db.example.invalid:5432/postgres"

    assert connection_kwargs(remote)["ssl"] == "require"


def test_connection_kwargs_decodes_the_dsn_like_the_application_does():
    kwargs = connection_kwargs(
        "postgresql://beerapp.testref:fake%2Fpass%40word@127.0.0.1:54322/postgres?sslmode=disable"
    )

    assert kwargs["user"] == "beerapp.testref"
    assert kwargs["password"] == "fake/pass@word"
    assert kwargs["host"] == "127.0.0.1"
    assert kwargs["port"] == 54322
    assert kwargs["database"] == "postgres"


def test_the_applications_own_pool_still_requires_ssl():
    # The integration helper's relaxed TLS must never leak into runtime code.
    import inspect

    import app.db

    assert 'ssl="require"' in inspect.getsource(app.db.create_pool)
