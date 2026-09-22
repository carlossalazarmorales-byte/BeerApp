"""Offline checks of the DRAFT production reference-data files (no database).

`supabase/reference_data/` is deliberately NOT part of `supabase/migrations/` and is never
applied by code. See supabase/reference_data/README.md. The database behaviour of
the files is covered by tests/integration/test_reference_data.py.
"""

from reference_data_files import (
    CATALOG_TEMPLATE,
    COUNTRIES,
    REFERENCE_DIR,
    STYLES,
    country_rows,
    has_draft_guard,
    read,
    rollback_safe_body,
    style_rows,
    without_draft_guard,
)

_CONTINENTS = {
    "Africa",
    "Antarctica",
    "Asia",
    "Europe",
    "North America",
    "Oceania",
    "South America",
}
# Reserved / exceptional / user-assigned codes: NOT ISO 3166-1 assignments.
_NOT_ASSIGNED = {"AC", "CP", "DG", "EA", "EU", "EZ", "IC", "QO", "TA", "UN", "XA", "XB", "XK", "ZZ"}


def test_reference_data_is_not_a_migration_and_is_documented():
    assert REFERENCE_DIR.parent.name == "supabase"
    assert REFERENCE_DIR.name == "reference_data"
    assert (REFERENCE_DIR / "README.md").is_file()
    assert (REFERENCE_DIR / "countries_review.md").is_file()
    migrations = REFERENCE_DIR.parent / "migrations"
    assert not any(p.name.startswith(("countries", "beer_styles")) for p in migrations.iterdir())


def test_both_files_are_draft_guarded_and_say_so():
    for path in (COUNTRIES, STYLES):
        sql = read(path)
        assert has_draft_guard(sql), f"{path.name} lost its DRAFT-GUARD (owner review comes first)"
        assert sql.index("DRAFT-GUARD-BEGIN") < sql.index("\nbegin;")
        assert "raise exception" in sql.split("DRAFT-GUARD-END")[0]
        assert "NOT" in sql.split("DRAFT-GUARD-BEGIN")[0]  # header disclaims review/application
    assert "NOT reviewed by the owner" in read(COUNTRIES)
    assert "CLAUDE-CREATED DRAFT" in read(STYLES)
    assert "NOT been reviewed or approved" in read(STYLES)


def test_countries_are_the_249_assigned_iso_codes_with_valid_columns():
    rows = country_rows(read(COUNTRIES))

    codes = [c for c, _, _ in rows]
    assert len(rows) == 249
    assert len(set(codes)) == 249
    assert codes == sorted(codes)
    assert not _NOT_ASSIGNED & set(codes)
    assert len({n.lower() for _, n, _ in rows}) == 249  # lower(name) is unique
    assert all(n.strip() for _, n, _ in rows)
    assert {k for _, _, k in rows} <= _CONTINENTS
    assert [c for c, _, k in rows if k == "Antarctica"] == ["AQ"]
    assert {"IE", "DE", "US", "GB", "MX", "JP", "BE", "CZ", "AU", "BR"} <= set(codes)


def test_countries_file_is_valid_after_the_guard_and_wrapper_are_removed():
    body = rollback_safe_body(read(COUNTRIES))

    assert "DRAFT-GUARD-BEGIN" not in body and "DRAFT-GUARD-END" not in body
    assert "\nbegin;" not in body and "\ncommit;" not in body
    assert "on conflict (iso_code) do update" in body
    # It touches only countries' own columns.
    assert "insert into public.countries (iso_code, name, continent)" in body


def test_beer_styles_are_generic_valid_and_reference_known_countries():
    styles = style_rows(read(STYLES))
    known = {c for c, _, _ in country_rows(read(COUNTRIES))}

    assert len(styles) >= 40
    assert len({s[0].lower() for s in styles}) == len(styles)
    for name, category, origin, lo, hi in styles:
        assert name.strip() and category.strip()
        assert 0 <= lo <= hi < 100, name
        assert origin is None or origin in known, name


def test_beer_styles_never_write_or_copy_descriptions():
    sql = without_draft_guard(read(STYLES))
    insert = sql.split("insert into public.beer_styles", 1)[1].split("on conflict", 1)[0]
    assert "description" not in insert
    assert "description" not in sql.split("on conflict", 1)[1].split("-- Sanity", 1)[0]


def test_the_beta_catalog_template_is_an_unfilled_guarded_template_with_fake_rows_only():
    sql = read(CATALOG_TEMPLATE)

    assert has_draft_guard(sql)  # TEMPLATE-GUARD is recognized
    assert "unfilled template" in sql.split("TEMPLATE-GUARD-END")[0]
    assert "EXAMPLE BREWERY (placeholder, replace)" in sql
    assert "EXAMPLE BEER (placeholder, replace)" in sql
    assert "'AA'" in sql  # not a real country code: cannot load unedited
    assert sql.count("insert into _beta_breweries") == 1
    assert sql.count("insert into _beta_beers") == 1
    assert "'owner-curated'" in sql
    assert "dev-seed" not in sql
    assert (CATALOG_TEMPLATE.parent / "README.md").is_file()
