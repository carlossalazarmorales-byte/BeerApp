from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# app/config.py -> app/ -> backend/ -> repo root. Resolved from the file's
# own location (not the process cwd) so the app finds the repo's single
# .env regardless of whether it's launched from backend/ or repo root.
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_ENV_FILE = _REPO_ROOT / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = "local"
    api_base_url: str = "http://localhost:8000"

    supabase_url: str
    supabase_publishable_key: str = ""

    # Phase 12: Supabase's current secret-key model (sb_secret_..., replaces
    # the legacy service_role JWT), used only by SupabaseAdminClient for
    # DELETE /account's call to the Auth Admin API. Optional so the app keeps
    # booting normally when it's unset -- only DELETE /account itself
    # degrades (503) in that case. Never logged, never returned in any
    # response, never referenced from mobile/config/*. See docs/DECISIONS.md.
    supabase_secret_key: str | None = None

    # Least-privilege `beerapp_backend` role connection -- SELECT only on
    # the four catalog tables. Never the admin/seed credential; see
    # docs/DATABASE.md. Intentionally the only DB credential declared here --
    # SEED_DATABASE_URL is read directly by backend/scripts/seed_catalog.py
    # and is never part of the running app's settings surface.
    database_url: str
    db_pool_min_size: int = 2
    db_pool_max_size: int = 10
    # asyncpg default (100). Must be set to 0 if DATABASE_URL is ever
    # pointed at a Transaction Pooler (port 6543) connection instead of
    # Direct Connection / Session Pooler (port 5432) -- transaction mode
    # doesn't support server-side prepared statements.
    db_statement_cache_size: int = 100

    # Supabase's standard audience for signed-in user access tokens.
    # Documented default, not a value discovered from the JWKS endpoint
    # (JWKS only proves which signing keys exist, not what claims real
    # tokens carry) -- see docs/DECISIONS.md.
    jwt_audience: str = "authenticated"

    @property
    def jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    @property
    def jwt_issuer(self) -> str:
        return f"{self.supabase_url}/auth/v1"


@lru_cache
def get_settings() -> Settings:
    return Settings()
