from app.db import parse_dsn_kwargs


def test_parse_dsn_kwargs_decodes_percent_encoded_special_characters():
    # Regression test: asyncpg's own DSN-string parser (`dsn=...`) did not
    # reliably authenticate with a percent-encoded password containing
    # URL-reserved characters, even though the same credentials connect
    # fine as explicit kwargs -- confirmed against this project's real
    # generated role passwords. parse_dsn_kwargs must decode correctly.
    dsn = "postgresql://beerapp_backend.abc123:7K%3D%40TnN3b2i5@aws-1-eu-west-1.pooler.supabase.com:5432/postgres"

    kwargs = parse_dsn_kwargs(dsn)

    assert kwargs["user"] == "beerapp_backend.abc123"
    assert kwargs["password"] == "7K=@TnN3b2i5"
    assert kwargs["host"] == "aws-1-eu-west-1.pooler.supabase.com"
    assert kwargs["port"] == 5432
    assert kwargs["database"] == "postgres"


def test_parse_dsn_kwargs_decodes_backslash_in_password():
    dsn = "postgresql://beerapp_seed.abc123:ZrBq543%5CC%3D9T@aws-1-eu-west-1.pooler.supabase.com:5432/postgres"

    kwargs = parse_dsn_kwargs(dsn)

    assert kwargs["password"] == "ZrBq543\\C=9T"
