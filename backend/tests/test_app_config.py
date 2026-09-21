"""Environment-driven behaviour: startup validation, and which routes exist.

- Interactive API docs (/docs, /redoc, /openapi.json) are for `local`/`dev`
  only. Any other value -- including a typo or an empty string -- is treated
  as production-like and gets no docs (fail closed).
- /health is deliberately identical in every environment: an unauthenticated
  liveness probe that touches neither the database, Supabase nor auth.
"""

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.config import RuntimeSettings, Settings
from app.main import create_app

_DB = "postgresql://beerapp_backend.testref:fake-pass@db.example.invalid:5432/postgres"


def _settings(**overrides) -> Settings:
    values = {"supabase_url": "https://example.supabase.co", "database_url": _DB}
    values.update(overrides)
    return Settings(_env_file=None, **values)


# -- docs gating ---------------------------------------------------------------


@pytest.mark.parametrize("environment", ["local", "dev", "LOCAL", " Dev "])
def test_docs_are_enabled_for_local_and_dev(environment):
    assert _settings(environment=environment).docs_enabled is True


@pytest.mark.parametrize(
    "environment", ["production", "prod", "staging", "development", "", "loca1", "test"]
)
def test_docs_are_disabled_for_every_other_environment(environment):
    assert _settings(environment=environment).docs_enabled is False


def test_the_default_environment_is_local():
    assert _settings().environment == "local"
    assert _settings().docs_enabled is True


def test_runtime_settings_need_no_secrets_so_the_app_can_be_built_at_import_time():
    # `app.main` builds the FastAPI app at import, before any Supabase/database
    # variable is required, so tests and tooling can import it with no .env.
    assert RuntimeSettings(_env_file=None).docs_enabled is True


@pytest.mark.parametrize("path", ["/docs", "/redoc", "/openapi.json"])
def test_docs_routes_exist_when_enabled(path):
    client = TestClient(create_app(docs_enabled=True), raise_server_exceptions=False)

    assert client.get(path).status_code == 200


@pytest.mark.parametrize("path", ["/docs", "/redoc", "/openapi.json", "/docs/oauth2-redirect"])
def test_docs_routes_do_not_exist_when_disabled(path):
    client = TestClient(create_app(docs_enabled=False), raise_server_exceptions=False)

    response = client.get(path)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


# -- /health -------------------------------------------------------------------


@pytest.mark.parametrize("docs_enabled", [True, False])
def test_health_is_identical_in_every_environment_and_needs_no_dependencies(docs_enabled):
    # No lifespan, no app.state.pool, no auth override: if /health touched the
    # database, JWKS or authentication this would error.
    client = TestClient(create_app(docs_enabled=docs_enabled), raise_server_exceptions=False)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_is_documented_as_liveness_only():
    client = TestClient(create_app(docs_enabled=True))
    schema = client.get("/openapi.json").json()

    description = schema["paths"]["/health"]["get"]["description"]
    assert "liveness" in description.lower()
    assert "database" in description.lower()


# -- startup validation ---------------------------------------------------------


def test_a_trailing_slash_on_supabase_url_is_normalized_away():
    settings = _settings(supabase_url="https://example.supabase.co/")

    assert settings.supabase_url == "https://example.supabase.co"
    assert settings.jwks_url == "https://example.supabase.co/auth/v1/.well-known/jwks.json"
    assert settings.jwt_issuer == "https://example.supabase.co/auth/v1"


@pytest.mark.parametrize("environment", ["production", "prod", "staging", ""])
def test_a_non_https_supabase_url_is_rejected_outside_local_and_dev(environment):
    with pytest.raises(ValidationError, match="https"):
        _settings(environment=environment, supabase_url="http://example.supabase.co")


@pytest.mark.parametrize("environment", ["local", "dev"])
def test_http_supabase_url_is_allowed_for_local_development(environment):
    settings = _settings(environment=environment, supabase_url="http://127.0.0.1:54321")

    assert settings.supabase_url == "http://127.0.0.1:54321"


def test_https_supabase_url_is_accepted_in_production():
    assert _settings(environment="production").supabase_url == "https://example.supabase.co"


def test_pool_min_size_may_not_exceed_max_size():
    with pytest.raises(ValidationError, match="db_pool_min_size"):
        _settings(db_pool_min_size=11, db_pool_max_size=10)


@pytest.mark.parametrize(
    "field",
    [
        "db_command_timeout_seconds",
        "db_acquire_timeout_seconds",
        "db_connect_timeout_seconds",
        "jwks_cache_ttl_seconds",
        "max_request_body_bytes",
    ],
)
@pytest.mark.parametrize("value", [0, -1])
def test_timeouts_and_limits_must_be_positive(field, value):
    with pytest.raises(ValidationError):
        _settings(**{field: value})


def test_the_jwks_cooldown_may_be_zero_but_not_negative():
    assert _settings(jwks_refresh_cooldown_seconds=0).jwks_refresh_cooldown_seconds == 0
    with pytest.raises(ValidationError):
        _settings(jwks_refresh_cooldown_seconds=-1)


@pytest.mark.parametrize("level", ["DEBUG", "info", "Warning", "ERROR", "CRITICAL"])
def test_log_level_accepts_standard_names_case_insensitively(level):
    assert _settings(log_level=level).log_level == level.upper()


def test_an_unknown_log_level_is_rejected():
    with pytest.raises(ValidationError):
        _settings(log_level="LOUD")


def test_secrets_never_appear_in_the_settings_repr():
    text = repr(_settings(supabase_secret_key="sb_secret_test_only"))

    assert "sb_secret_test_only" not in text
    assert "fake-pass" not in text
