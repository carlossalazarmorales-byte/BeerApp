"""Startup/shutdown wiring, with no real database or network: settings feed the
JWKS cache and logging, and shutdown always closes both resources even if one
close fails.
"""

import logging

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.config import Settings

_DB = "postgresql://beerapp_backend.testref:fake-pass@db.example.invalid:5432/postgres"


class _FakePool:
    def __init__(self) -> None:
        self.closed = False

    async def close(self) -> None:
        self.closed = True


@pytest.fixture
def wired(monkeypatch):
    settings = Settings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        database_url=_DB,
        log_level="WARNING",
        jwks_cache_ttl_seconds=123.0,
        jwks_refresh_cooldown_seconds=4.5,
    )
    pool = _FakePool()
    configured: list[str] = []

    async def fake_create_pool(received):
        assert received is settings
        return pool

    monkeypatch.setattr(main, "get_settings", lambda: settings)
    monkeypatch.setattr(main, "create_pool", fake_create_pool)
    monkeypatch.setattr(main, "configure_logging", configured.append)
    return settings, pool, configured


def test_startup_configures_logging_and_builds_the_jwks_cache_from_settings(wired):
    settings, pool, configured = wired

    with TestClient(main.create_app(docs_enabled=False)) as client:
        state = client.app.state
        assert state.pool is pool
        assert state.jwks_cache._jwks_url == settings.jwks_url
        assert state.jwks_cache._ttl == 123.0
        assert state.jwks_cache._cooldown == 4.5

    assert configured == ["WARNING"]


def test_shutdown_closes_the_pool_and_the_http_client(wired):
    _, pool, _ = wired

    with TestClient(main.create_app(docs_enabled=False)) as client:
        http_client = client.app.state.http_client
        assert not http_client.is_closed

    assert pool.closed is True
    assert http_client.is_closed


def test_the_pool_is_still_closed_when_closing_the_http_client_fails(wired, monkeypatch):
    _, pool, _ = wired

    async def failing_aclose(self):
        raise RuntimeError("close failed")

    monkeypatch.setattr(main.httpx.AsyncClient, "aclose", failing_aclose)

    with pytest.raises(RuntimeError, match="close failed"):
        with TestClient(main.create_app(docs_enabled=False)):
            pass

    assert pool.closed is True


def test_importing_the_module_level_app_needs_no_secrets():
    # `app.main.app` exists at import time and is a real FastAPI application.
    assert main.app.title == "BeerApp API"
    assert logging.getLogger("app") is not None
