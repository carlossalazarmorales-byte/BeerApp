"""Bounded database behaviour: connect / command / acquire all have timeouts,
so a slow or saturated database fails fast (-> sanitized 503) instead of
hanging requests indefinitely.
"""

import asyncio

import pytest

import app.db as db
from app.config import Settings

_DSN = "postgresql://beerapp_backend.testref:fake-pass@db.example.invalid:5432/postgres"


def _settings(**overrides) -> Settings:
    return Settings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        database_url=_DSN,
        **overrides,
    )


class _FakePool:
    def __init__(self) -> None:
        self.acquire_calls: list[dict] = []
        self.closed = False
        self.marker = "passthrough-attribute"

    def acquire(self, *, timeout=None):
        self.acquire_calls.append({"timeout": timeout})
        return "acquire-context"

    async def close(self):
        self.closed = True


@pytest.fixture
def created(monkeypatch):
    captured: dict = {}
    fake = _FakePool()

    async def fake_create_pool(**kwargs):
        captured.update(kwargs)
        return fake

    monkeypatch.setattr(db.asyncpg, "create_pool", fake_create_pool)
    return captured, fake


def test_create_pool_bounds_connect_and_command_time(created):
    captured, _ = created

    asyncio.run(
        db.create_pool(
            _settings(
                db_command_timeout_seconds=12.5,
                db_connect_timeout_seconds=7.0,
            )
        )
    )

    assert captured["command_timeout"] == 12.5
    assert captured["timeout"] == 7.0


def test_create_pool_keeps_ssl_required_and_the_existing_sizing(created):
    captured, _ = created

    asyncio.run(db.create_pool(_settings(db_pool_min_size=3, db_pool_max_size=8)))

    assert captured["ssl"] == "require"
    assert captured["min_size"] == 3
    assert captured["max_size"] == 8
    assert captured["statement_cache_size"] == 100
    assert captured["user"] == "beerapp_backend.testref"


def test_acquire_gets_the_configured_timeout_by_default(created):
    _, fake = created
    pool = asyncio.run(db.create_pool(_settings(db_acquire_timeout_seconds=4.0)))

    context = pool.acquire()

    assert context == "acquire-context"
    assert fake.acquire_calls == [{"timeout": 4.0}]


def test_an_explicit_acquire_timeout_wins(created):
    _, fake = created
    pool = asyncio.run(db.create_pool(_settings(db_acquire_timeout_seconds=4.0)))

    pool.acquire(timeout=1.5)

    assert fake.acquire_calls == [{"timeout": 1.5}]


def test_the_wrapper_delegates_close_and_other_attributes(created):
    _, fake = created
    pool = asyncio.run(db.create_pool(_settings()))

    asyncio.run(pool.close())

    assert fake.closed is True
    assert pool.marker == "passthrough-attribute"


def test_default_timeouts_are_finite_and_ordered_sensibly():
    settings = _settings()

    assert 0 < settings.db_connect_timeout_seconds <= 30
    assert 0 < settings.db_acquire_timeout_seconds <= 30
    assert 0 < settings.db_command_timeout_seconds <= 120
