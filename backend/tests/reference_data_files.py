"""Helpers for tests of supabase/reference_data/*.sql (production reference data).

The files are DRAFTs / a template the owner has not reviewed or filled, are not
migrations, and are never applied by code or tests to anything but a disposable
database. Each one starts with a DRAFT-GUARD (or TEMPLATE-GUARD) block that makes it
raise until the owner deletes it, and wraps its work in its own `begin; ... commit;`.
"""

import re
from pathlib import Path

REFERENCE_DIR = Path(__file__).resolve().parents[2] / "supabase" / "reference_data"
COUNTRIES = REFERENCE_DIR / "countries.sql"
STYLES = REFERENCE_DIR / "beer_styles_DRAFT.sql"
CATALOG_TEMPLATE = (
    Path(__file__).resolve().parents[2] / "supabase" / "catalog_beta" / "beta_catalog_template.sql"
)

_GUARD = re.compile(
    r"-- >>> (?:DRAFT|TEMPLATE)-GUARD-BEGIN.*?-- <<< (?:DRAFT|TEMPLATE)-GUARD-END\n",
    re.DOTALL,
)

_COUNTRY_ROW = re.compile(r"^\s+\('([A-Z]{2})', '((?:[^']|'')*)', '([^']*)'\)[,;]?$")
_STYLE_ROW = re.compile(
    r"^\s+\('((?:[^']|'')*)', '((?:[^']|'')*)', (null|'[A-Z]{2}'), "
    r"(\d+\.\d\d), (\d+\.\d\d)\)[,;]?$"
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def has_draft_guard(sql: str) -> bool:
    return _GUARD.search(sql) is not None


def without_draft_guard(sql: str) -> str:
    return _GUARD.sub("", sql)


def without_transaction_wrapper(sql: str) -> str:
    """Drop the file's own `begin;` / `commit;` so it can run inside a test
    transaction that is always rolled back (a real `commit;` would persist)."""
    lines = sql.splitlines()
    assert lines.count("begin;") == 1 and lines.count("commit;") == 1
    return "\n".join(ln for ln in lines if ln not in ("begin;", "commit;")) + "\n"


def rollback_safe_body(sql: str) -> str:
    return without_transaction_wrapper(without_draft_guard(sql))


def country_rows(sql: str) -> list[tuple[str, str, str]]:
    rows = []
    for line in sql.splitlines():
        m = _COUNTRY_ROW.match(line)
        if m:
            rows.append((m.group(1), m.group(2).replace("''", "'"), m.group(3)))
    return rows


def style_rows(sql: str) -> list[tuple[str, str, str | None, float, float]]:
    rows = []
    for line in sql.splitlines():
        m = _STYLE_ROW.match(line)
        if m:
            origin = None if m.group(3) == "null" else m.group(3).strip("'")
            rows.append(
                (
                    m.group(1).replace("''", "'"),
                    m.group(2).replace("''", "'"),
                    origin,
                    float(m.group(4)),
                    float(m.group(5)),
                )
            )
    return rows
