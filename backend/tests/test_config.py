from app.config import Settings


def test_settings_boots_without_supabase_secret_key(monkeypatch):
    # Phase 12: SUPABASE_SECRET_KEY is optional -- the app must keep
    # starting normally without it. Only DELETE /account degrades (503) in
    # that case; nothing here should raise a validation error.
    monkeypatch.delenv("SUPABASE_SECRET_KEY", raising=False)

    settings = Settings(
        _env_file=None,  # bypass the real repo-root .env for this test
        supabase_url="https://example.supabase.co",
        database_url="postgresql://user:pass@localhost:5432/postgres",
    )

    assert settings.supabase_secret_key is None


def test_settings_accepts_supabase_secret_key_when_set(monkeypatch):
    settings = Settings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        database_url="postgresql://user:pass@localhost:5432/postgres",
        supabase_secret_key="sb_secret_test_only",
    )

    assert settings.supabase_secret_key == "sb_secret_test_only"
