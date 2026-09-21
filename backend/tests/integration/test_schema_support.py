"""Hygiene tests for the integration scaffold, its apply helper and the Phase 14
hardening migration. Pure file/logic checks -- NOT marked `integration`, so they
run in the default suite and need no database.
"""

import re

import pytest

from .support import apply_schema

_MIGRATION = "20260921100000_revoke_public_execute_on_set_updated_at.sql"


def _sql(path) -> str:
    return path.read_text(encoding="utf-8")


def _statements(text: str) -> list[str]:
    """SQL with `--` comments stripped, split into non-empty statements."""
    without_comments = "\n".join(line.split("--", 1)[0] for line in text.splitlines())
    return [s.strip() for s in without_comments.split(";") if s.strip()]


# -- the scaffold is generic, deterministic and secret-free ---------------------------


def test_the_scaffold_contains_no_secrets_identifiers_urls_or_machine_paths():
    text = _sql(apply_schema.SCAFFOLD_SQL)
    body = "\n".join(line.split("--", 1)[0] for line in text.splitlines()).lower()

    forbidden = [
        "password",
        "secret",
        "://",
        "supabase.co",
        "sb_",
        "eyj",
        "c:\\",
        "/users/",
        "/home/",
        "\\users\\",
        "@",
    ]
    for token in forbidden:
        assert token not in body, f"scaffold SQL contains {token!r}"


def test_the_scaffold_creates_only_nologin_roles():
    body = "\n".join(
        line.split("--", 1)[0] for line in _sql(apply_schema.SCAFFOLD_SQL).splitlines()
    ).lower()

    created = re.findall(r"create role (\w+)([^;]*);", body)
    assert {name for name, _ in created} == {"anon", "authenticated", "service_role"}
    for name, options in created:
        assert "nologin" in options, f"{name} must not be able to log in"
        assert "superuser" not in options and "createrole" not in options
        assert "password" not in options


def test_the_scaffold_defines_only_what_the_migrations_and_tests_need():
    body = _sql(apply_schema.SCAFFOLD_SQL).lower()

    assert "create table auth.users" in body
    assert "create function auth.uid()" in body
    assert "alter default privileges" in body
    # It must never pretend to be more than a scaffold.
    for unexpected in (
        "create extension",
        "create database",
        "drop ",
        "truncate",
        "create trigger",
    ):
        assert unexpected not in body


def test_the_scaffold_default_privileges_target_the_applying_role_not_a_named_one():
    body = _sql(apply_schema.SCAFFOLD_SQL)

    assert "current_user" in body
    assert "for role postgres" not in body.lower()


# -- the apply helper -------------------------------------------------------------------


def test_the_scaffold_is_applied_first_then_every_migration_in_order():
    files = apply_schema.schema_files()
    migrations = sorted(apply_schema.MIGRATIONS_DIR.glob("*.sql"))

    assert files[0] == apply_schema.SCAFFOLD_SQL
    assert files[1:] == migrations
    assert len(migrations) >= 19
    assert [p.name for p in migrations] == sorted(p.name for p in migrations)
    assert migrations[-1].name == _MIGRATION


def test_migration_timestamps_are_unique():
    names = [p.name.split("_", 1)[0] for p in apply_schema.MIGRATIONS_DIR.glob("*.sql")]

    assert len(names) == len(set(names))


def _fail_if_applied(monkeypatch):
    async def boom(*_args, **_kwargs):
        raise AssertionError("must not connect or apply anything")

    monkeypatch.setattr(apply_schema, "apply_schema", boom)


def test_the_helper_refuses_a_missing_url(monkeypatch):
    monkeypatch.delenv("INTEGRATION_DATABASE_URL", raising=False)
    _fail_if_applied(monkeypatch)

    with pytest.raises(SystemExit, match="not set"):
        apply_schema.main()


@pytest.mark.parametrize(
    "url",
    [
        "postgresql://postgres:x@db.example.invalid:5432/postgres",  # not loopback
        "postgresql://postgres:x@pooler.example.invalid:5432/postgres",
    ],
)
def test_the_helper_refuses_a_remote_database_before_connecting(monkeypatch, url):
    monkeypatch.setenv("INTEGRATION_DATABASE_URL", url)
    monkeypatch.delenv("INTEGRATION_DATABASE_ALLOW_REMOTE", raising=False)
    _fail_if_applied(monkeypatch)

    with pytest.raises(SystemExit, match="Refusing"):
        apply_schema.main()


def test_the_helper_refuses_the_protected_database_urls_even_on_loopback(monkeypatch):
    protected = "postgresql://beerapp_backend.testref:pw@127.0.0.1:5432/postgres"
    monkeypatch.setenv("INTEGRATION_DATABASE_URL", protected)
    monkeypatch.setenv("DATABASE_URL", protected)
    _fail_if_applied(monkeypatch)

    with pytest.raises(SystemExit, match="identical to DATABASE_URL"):
        apply_schema.main()


def test_the_helper_never_drops_or_resets_anything():
    source = (apply_schema.SUPPORT_DIR / "apply_schema.py").read_text(encoding="utf-8").lower()

    for verb in ("drop ", "truncate", "delete from", "reset"):
        assert verb not in source.split('"""', 2)[2], f"helper must not {verb.strip()}"


# -- the hardening migration does exactly one thing -------------------------------------


def test_the_hardening_migration_is_a_single_revoke_and_nothing_else():
    statements = _statements(_sql(apply_schema.MIGRATIONS_DIR / _MIGRATION))

    assert len(statements) == 1
    normalized = re.sub(r"\s+", " ", statements[0].lower())
    assert normalized == (
        "revoke execute on function private.set_updated_at() from public, anon, authenticated"
    )


def test_the_hardening_migration_changes_no_function_owner_trigger_or_other_grant():
    text = _sql(apply_schema.MIGRATIONS_DIR / _MIGRATION).lower()
    executable = "\n".join(line.split("--", 1)[0] for line in text.splitlines())

    for forbidden in (
        "create function",
        "create or replace",
        "alter function",
        "owner to",
        "create trigger",
        "drop trigger",
        "grant ",
        "security definer",
        "drop function",
    ):
        assert forbidden not in executable, forbidden


def test_no_earlier_migration_was_edited_to_make_the_revoke():
    # The REVOKE lives only in the new migration: the original that created
    # set_updated_at() must still contain no revoke for it (applied migrations
    # are immutable).
    original = _sql(apply_schema.MIGRATIONS_DIR / "20260914120000_create_profiles_table.sql")

    assert "revoke execute on function private.set_updated_at" not in original.lower()
