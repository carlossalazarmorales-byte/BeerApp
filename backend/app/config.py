from functools import lru_cache
from pathlib import Path

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# app/config.py -> app/ -> backend/ -> repo root. Resolved from the file's
# own location (not the process cwd) so the app finds the repo's single
# .env regardless of whether it's launched from backend/ or repo root.
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_ENV_FILE = _REPO_ROOT / ".env"

# The only environments that get interactive API docs and may talk to a
# non-https Supabase URL (a local Supabase stack). Anything else -- including
# an unset-looking or misspelled value -- is treated as production-like:
# fail closed, not open.
_LOCAL_ENVIRONMENTS = frozenset({"local", "dev"})

_LOG_LEVELS = frozenset({"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"})


class RuntimeSettings(BaseSettings):
    """The settings the FastAPI app object itself needs at construction time.

    Deliberately has no required fields (no Supabase URL, no database URL), so
    `app.main` can build the app at import -- for tests and tooling -- without
    a populated .env. The full `Settings` extends it for the running server.
    """

    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = "local"
    log_level: str = "INFO"

    # Largest request body the API will accept. Every legitimate body is tiny
    # (a beer log with each text field full of 4-byte characters is ~11 KB), so
    # 64 KiB leaves generous headroom while bounding what an unauthenticated
    # caller can make the server buffer. Enforced from Content-Length and from
    # the bytes actually received -- see app/middleware.py.
    max_request_body_bytes: int = Field(default=65_536, gt=0)

    @field_validator("log_level")
    @classmethod
    def _normalize_log_level(cls, value: str) -> str:
        level = value.strip().upper()
        if level not in _LOG_LEVELS:
            raise ValueError(f"log_level must be one of {sorted(_LOG_LEVELS)}")
        return level

    @property
    def is_local_or_dev(self) -> bool:
        return self.environment.strip().lower() in _LOCAL_ENVIRONMENTS

    @property
    def docs_enabled(self) -> bool:
        """/docs, /redoc and /openapi.json exist only for local/dev."""
        return self.is_local_or_dev


class Settings(RuntimeSettings):
    supabase_url: str
    supabase_publishable_key: str = ""

    # Phase 12: Supabase's current secret-key model (sb_secret_..., replaces
    # the legacy service_role JWT), used only by SupabaseAdminClient for
    # DELETE /account's call to the Auth Admin API. Optional so the app keeps
    # booting normally when it's unset -- only DELETE /account itself
    # degrades (503) in that case. Never logged, never returned in any
    # response, never referenced from mobile/config/*. `repr=False` keeps it
    # out of any accidental `repr(settings)`. See docs/DECISIONS.md.
    supabase_secret_key: str | None = Field(default=None, repr=False)

    # Least-privilege `beerapp_backend` role connection -- SELECT only on
    # the four catalog tables. Never the admin/seed credential; see
    # docs/DATABASE.md. Intentionally the only DB credential declared here --
    # SEED_DATABASE_URL is read directly by backend/scripts/seed_catalog.py
    # and is never part of the running app's settings surface.
    database_url: str = Field(repr=False)
    db_pool_min_size: int = 2
    db_pool_max_size: int = 10
    # asyncpg default (100). Must be set to 0 if DATABASE_URL is ever
    # pointed at a Transaction Pooler (port 6543) connection instead of
    # Direct Connection / Session Pooler (port 5432) -- transaction mode
    # doesn't support server-side prepared statements.
    db_statement_cache_size: int = 100

    # Database timeouts, so a slow or saturated database fails fast (and is
    # reported as a sanitized 503) instead of hanging requests forever.
    # - connect: opening a new physical connection.
    # - acquire: waiting for a free pooled connection when the pool is busy.
    # - command: any single statement (asyncpg cancels it and raises).
    db_connect_timeout_seconds: float = Field(default=10.0, gt=0)
    db_acquire_timeout_seconds: float = Field(default=10.0, gt=0)
    db_command_timeout_seconds: float = Field(default=30.0, gt=0)

    # JWKS cache: a cached key set is trusted for at most the TTL (so a key
    # removed upstream stops being trusted), and refreshes -- whether
    # triggered by an unknown `kid` or by a failed load -- happen at most once
    # per cooldown, so forged tokens cannot make the backend hammer Supabase.
    jwks_cache_ttl_seconds: float = Field(default=600.0, gt=0)
    jwks_refresh_cooldown_seconds: float = Field(default=30.0, ge=0)

    # Supabase's standard audience for signed-in user access tokens.
    # Documented default, not a value discovered from the JWKS endpoint
    # (JWKS only proves which signing keys exist, not what claims real
    # tokens carry) -- see docs/DECISIONS.md.
    jwt_audience: str = "authenticated"

    @field_validator("supabase_url")
    @classmethod
    def _strip_trailing_slash(cls, value: str) -> str:
        # A trailing slash would build "//auth/v1" for the JWT issuer and the
        # JWKS URL and reject every token.
        return value.strip().rstrip("/")

    @model_validator(mode="after")
    def _validate_deployment_settings(self) -> "Settings":
        if not self.is_local_or_dev and not self.supabase_url.startswith("https://"):
            raise ValueError(
                "SUPABASE_URL must use https outside the local/dev environments "
                f"(ENVIRONMENT={self.environment!r})."
            )
        if self.db_pool_min_size > self.db_pool_max_size:
            raise ValueError(
                "db_pool_min_size must not exceed db_pool_max_size "
                f"({self.db_pool_min_size} > {self.db_pool_max_size})."
            )
        return self

    @property
    def jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    @property
    def jwt_issuer(self) -> str:
        return f"{self.supabase_url}/auth/v1"


@lru_cache
def get_runtime_settings() -> RuntimeSettings:
    return RuntimeSettings()


@lru_cache
def get_settings() -> Settings:
    return Settings()
