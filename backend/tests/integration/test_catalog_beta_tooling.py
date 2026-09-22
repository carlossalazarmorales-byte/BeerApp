"""The beta-catalog TEMPLATE and the contribution-review SQL, on a DISPOSABLE database only.

`supabase/catalog_beta/` holds tooling and a runbook, not content. The rows used here
are obviously fake test fixtures (they live in this test, not in the repository's
SQL). The template's guard and its own `begin;`/`commit;` are removed so everything
runs inside a transaction that is always rolled back.
"""

import random
import re

import asyncpg
import pytest
from reference_data_files import CATALOG_TEMPLATE, has_draft_guard, read, rollback_safe_body

from app.services.barcode import canonicalize_barcode

from .disposable_db import run_rolled_back

pytestmark = pytest.mark.integration

_USER = "00000000-0000-0000-0000-0000000000aa"
_PLACEHOLDER_BLOCK = re.compile(
    r"-- ---- PLACEHOLDER ROWS.*?-- ---- end of placeholder rows -+\n", re.DOTALL
)


def _api_accepts(code: str) -> bool:
    try:
        canonicalize_barcode(code)
    except ValueError:
        return False
    return True


def _ean13(payload12: str) -> str:
    total = sum(int(ch) * (3 if i % 2 == 0 else 1) for i, ch in enumerate(reversed(payload12)))
    return payload12 + str((10 - total % 10) % 10)


_GOOD_A = _ean13("400638133393")
_GOOD_B = _ean13("590123412345")
_BREWERY_ROW = (
    "('b1', 'Fixture Brewery One', 'IE', 'Leinster', 'Dublin', 53.349805, -6.260310, "
    "'https://example.com')"
)
_BEER_ROW = "('b1', 'Fixture Beer One', 'Pilsner', 4.80, 30, '{barcode}')"


def _filled(breweries: str = _BREWERY_ROW, beers: str | None = None) -> str:
    beers = beers or _BEER_ROW.format(barcode=_GOOD_A)
    rows = (
        "insert into _beta_breweries (key, name, country_iso, region, city, latitude, "
        f"longitude, website) values {breweries};\n"
        "insert into _beta_beers (brewery_key, official_name, style_name, abv, ibu, barcode) "
        f"values {beers};\n"
    )
    body = rollback_safe_body(read(CATALOG_TEMPLATE))
    assert _PLACEHOLDER_BLOCK.search(body), "template lost its placeholder block markers"
    return _PLACEHOLDER_BLOCK.sub(lambda _: rows, body)


async def _reference(conn: asyncpg.Connection) -> None:
    await conn.execute(
        "insert into public.countries (iso_code, name, continent) values "
        "('IE', 'Ireland', 'Europe'), ('DE', 'Germany', 'Europe');"
        "insert into public.beer_styles (name, category) values ('Pilsner', 'Lager');"
    )


async def _rerun(conn: asyncpg.Connection, sql: str) -> None:
    await conn.execute("drop table if exists _beta_breweries, _beta_beers")
    await conn.execute(sql)


def test_the_template_as_shipped_cannot_load(integration_dsn):
    template = read(CATALOG_TEMPLATE)
    assert has_draft_guard(template)  # the TEMPLATE-GUARD block is recognized

    async def body(conn: asyncpg.Connection) -> None:
        await conn.execute("savepoint s1")
        with pytest.raises(asyncpg.RaiseError, match="unfilled template"):
            await conn.execute(template)
        await conn.execute("rollback to savepoint s1")

        # Even with the guard removed, the fake country code makes validation fail.
        await conn.execute("savepoint s2")
        with pytest.raises(asyncpg.RaiseError, match="unknown country_iso"):
            await conn.execute(rollback_safe_body(template))
        await conn.execute("rollback to savepoint s2")
        assert await conn.fetchval("select count(*) from public.breweries") == 0
        assert await conn.fetchval("select count(*) from public.beers") == 0

    run_rolled_back(integration_dsn, body)


def test_a_filled_copy_loads_idempotently_with_owner_curated_source(integration_dsn):
    sql = _filled()

    async def body(conn: asyncpg.Connection) -> None:
        await _reference(conn)
        await conn.execute(sql)

        brewery = await conn.fetchrow("select * from public.breweries")
        beer = await conn.fetchrow("select * from public.beers")
        assert brewery["name"] == "Fixture Brewery One"
        assert (brewery["source"], brewery["verified"]) == ("owner-curated", False)
        assert (beer["source"], beer["verified"]) == ("owner-curated", False)
        assert beer["brewery_id"] == brewery["id"]
        assert beer["barcode"] == _GOOD_A
        assert float(beer["abv"]) == 4.8
        # Coordinates/country stay null on the beer: the app falls back to the brewery's.
        assert beer["latitude"] is None and beer["country_id"] is None
        assert beer["style_id"] is not None

        await _rerun(conn, sql)  # re-running the same copy adds nothing
        assert await conn.fetchval("select count(*) from public.breweries") == 1
        assert await conn.fetchval("select count(*) from public.beers") == 1

    run_rolled_back(integration_dsn, body)


_BAD_CHECK_DIGIT = _GOOD_A[:-1] + str((int(_GOOD_A[-1]) + 1) % 10)


@pytest.mark.parametrize(
    ("breweries", "beers", "fragment"),
    [
        (_BREWERY_ROW.replace("'IE'", "'ZZ'"), None, "unknown country_iso"),
        (_BREWERY_ROW, "('nope', 'X', null, null, null, null)", "unknown brewery_key"),
        (_BREWERY_ROW, "('b1', 'X', 'No Such Style', null, null, null)", "unknown style_name"),
        (_BREWERY_ROW, "('b1', 'X', null, null, null, '12345')", "not a valid EAN-8/GTIN-13"),
        (_BREWERY_ROW, "('b1', 'X', null, null, null, '40063813339A1')", "not a valid EAN"),
        (
            _BREWERY_ROW,
            f"('b1', 'X', null, null, null, '{_BAD_CHECK_DIGIT}')",
            "not a valid EAN-8/GTIN-13",
        ),
        (
            _BREWERY_ROW,
            f"('b1', 'A', null, null, null, '{_GOOD_A}'), "
            f"('b1', 'B', null, null, null, '{_GOOD_A}')",
            "barcode repeated in this file",
        ),
        (_BREWERY_ROW, "('b1', 'X', null, -1.0, null, null)", "abv must be between"),
        (_BREWERY_ROW, "('b1', '   ', null, null, null, null)", "blank name"),
        (
            _BREWERY_ROW.replace("53.349805, -6.260310", "53.349805, null"),
            None,
            "latitude/longitude must be set together",
        ),
        (
            _BREWERY_ROW.replace("https://example.com", "http://example.com"),
            None,
            "website must start with https://",
        ),
    ],
)
def test_validation_aborts_before_anything_is_written(integration_dsn, breweries, beers, fragment):
    sql = _filled(breweries, beers)

    async def body(conn: asyncpg.Connection) -> None:
        await _reference(conn)
        with pytest.raises(asyncpg.RaiseError, match=re.escape(fragment)):
            await conn.execute(sql)

    run_rolled_back(integration_dsn, body)


def test_a_barcode_owned_by_another_beer_is_a_conflict(integration_dsn):
    sql = _filled()

    async def body(conn: asyncpg.Connection) -> None:
        await _reference(conn)
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) "
            "select 'Someone Else', id from public.countries where iso_code = 'DE' returning id"
        )
        await conn.execute(
            "insert into public.beers (official_name, brewery_id, barcode) values ($1, $2, $3)",
            "Other Beer",
            brewery_id,
            _GOOD_A,
        )
        with pytest.raises(asyncpg.RaiseError, match="already belongs to another beer"):
            await conn.execute(sql)

    run_rolled_back(integration_dsn, body)


def test_the_sql_check_digit_agrees_with_the_api_rule(integration_dsn):
    """The template re-implements the GS1 mod-10 rule in SQL; it must agree with the
    Python rule the API applies to scanned codes, for valid and invalid codes alike."""
    rng = random.Random(15)
    codes = []
    for _ in range(40):
        codes.append(_ean13("".join(rng.choice("0123456789") for _ in range(12))))
    for _ in range(15):
        body7 = "".join(rng.choice("0123456789") for _ in range(7))
        total = sum(int(ch) * (3 if i % 2 == 0 else 1) for i, ch in enumerate(reversed(body7)))
        codes.append(body7 + str((10 - total % 10) % 10))
    for code in list(codes[:25]):  # the same codes with a wrong last digit
        codes.append(code[:-1] + str((int(code[-1]) + 1 + rng.randrange(9)) % 10))
    assert all(len(c) in (8, 13) for c in codes)

    async def body(conn: asyncpg.Connection) -> None:
        await _reference(conn)
        for code in codes:
            expected_valid = _api_accepts(code)
            sql = _filled(beers=f"('b1', 'X', null, null, null, '{code}')")
            await conn.execute("savepoint one")
            try:
                await _rerun(conn, sql)
                accepted = True
            except asyncpg.RaiseError:
                accepted = False
            await conn.execute("rollback to savepoint one")
            assert accepted == expected_valid, code

    run_rolled_back(integration_dsn, body)


def test_the_documented_contribution_review_sql_satisfies_the_constraints(integration_dsn):
    """The approve/reject snippets in supabase/catalog_beta/README.md, run as the admin role."""

    async def body(conn: asyncpg.Connection) -> None:
        await _reference(conn)
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) "
            "select 'Fixture Brewery', id from public.countries where iso_code = 'IE' returning id"
        )
        approve_id, reject_id, brewery_reject_id = await conn.fetchrow(
            "select gen_random_uuid(), gen_random_uuid(), gen_random_uuid()"
        )
        await conn.execute(
            "insert into public.beer_contributions (id, user_id, official_name, brewery_id) "
            "values ($1, $2, 'Proposed A', $3), ($4, $2, 'Proposed B', $3)",
            approve_id,
            _USER,
            brewery_id,
            reject_id,
        )
        await conn.execute(
            "insert into public.brewery_contributions (id, user_id, name, proposed_country_name) "
            "values ($1, $2, 'Proposed Brewery', 'Nowhere')",
            brewery_reject_id,
            _USER,
        )

        pending = await conn.fetch(
            "select id, official_name, proposed_brewery_name, brewery_id, barcode, created_at "
            "from public.beer_contributions where status = 'pending' order by created_at"
        )
        assert len(pending) == 2

        # README: approve a beer.
        await conn.execute(
            """
            with new_beer as (
              insert into public.beers
                (official_name, brewery_id, style_id, abv, barcode, verified, source)
              values ('Proposed A', $2, null, null, null, false, 'owner-curated')
              returning id
            )
            update public.beer_contributions c
               set status = 'approved', reviewed_at = now(), resolved_beer_id = new_beer.id,
                   review_note = 'Approved by the owner.'
              from new_beer
             where c.id = $1 and c.status = 'pending'
            """,
            approve_id,
            brewery_id,
        )
        # README: reject a beer and a brewery contribution.
        await conn.execute(
            "update public.beer_contributions set status = 'rejected', reviewed_at = now(), "
            "review_note = 'Not enough information.' where id = $1 and status = 'pending'",
            reject_id,
        )
        await conn.execute(
            "update public.brewery_contributions set status = 'rejected', reviewed_at = now(), "
            "review_note = 'Duplicate.' where id = $1 and status = 'pending'",
            brewery_reject_id,
        )

        rows = {
            r["id"]: r
            for r in await conn.fetch(
                "select id, status, resolved_beer_id, reviewed_at from public.beer_contributions"
            )
        }
        assert rows[approve_id]["status"] == "approved" and rows[approve_id]["resolved_beer_id"]
        assert (
            rows[reject_id]["status"] == "rejected" and rows[reject_id]["resolved_beer_id"] is None
        )
        assert rows[approve_id]["reviewed_at"] is not None
        assert await conn.fetchval("select count(*) from public.beers") == 1

    run_rolled_back(integration_dsn, body, users=(_USER,))
