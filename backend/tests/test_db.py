from app.db import parse_dsn_kwargs

# These DSNs are fabricated test fixtures. They point at the reserved
# `.invalid` TLD and carry deliberately fake credentials -- no real project,
# host or password appears here, and no test in this repo needs one.


def test_parse_dsn_kwargs_decodes_percent_encoded_special_characters():
    # Regression test: asyncpg's own DSN-string parser (`dsn=...`) did not
    # reliably authenticate with a percent-encoded password containing
    # URL-reserved characters, even though the same credentials connect
    # fine as explicit kwargs. parse_dsn_kwargs must decode them correctly.
    dsn = "postgresql://beerapp_backend.testref:fake%2Fpass%40word%3A1@db.example.invalid:5432/postgres"

    kwargs = parse_dsn_kwargs(dsn)

    assert kwargs["user"] == "beerapp_backend.testref"
    assert kwargs["password"] == "fake/pass@word:1"
    assert kwargs["host"] == "db.example.invalid"
    assert kwargs["port"] == 5432
    assert kwargs["database"] == "postgres"


def test_parse_dsn_kwargs_decodes_backslash_in_password():
    dsn = "postgresql://beerapp_seed.testref:fake%5Cpass%3Dword@db.example.invalid:5432/postgres"

    kwargs = parse_dsn_kwargs(dsn)

    assert kwargs["password"] == "fake\\pass=word"
