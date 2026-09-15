import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

from app.db import parse_dsn_kwargs
from app.repositories.beers import BeerRepository

pytestmark = pytest.mark.integration


class _SingleConnectionPool:
    """Minimal stand-in for `asyncpg.Pool`'s `acquire()` shape, so
    `BeerRepository` (written against a real pool) can be exercised directly
    against one already-open connection inside a rolled-back transaction.
    """

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


async def _seed(conn: asyncpg.Connection) -> dict[str, str]:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    other_country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('YY', '100% Wonderland', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) "
        "values ('Chouffe Test Brewery', $1) returning id",
        country_id,
    )
    style_id = await conn.fetchval(
        "insert into public.beer_styles (name) values ('Test Stout') returning id"
    )
    beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, style_id, country_id) "
        "values ('La Chouffe Search Target', $1, $2, $3) returning id",
        brewery_id,
        style_id,
        country_id,
    )
    percent_beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, country_id) "
        "values ('100% Test Beer', $1, $2) returning id",
        brewery_id,
        other_country_id,
    )
    underscore_beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) "
        "values ('under_score_test', $1) returning id",
        brewery_id,
    )
    noise_beer_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) "
        "values ('Completely Unrelated Beer', $1) returning id",
        brewery_id,
    )
    return {
        "country_id": str(country_id),
        "other_country_id": str(other_country_id),
        "brewery_id": str(brewery_id),
        "style_id": str(style_id),
        "beer_id": str(beer_id),
        "percent_beer_id": str(percent_beer_id),
        "underscore_beer_id": str(underscore_beer_id),
        "noise_beer_id": str(noise_beer_id),
    }


def _run(dsn: str, body) -> None:
    async def wrapper() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
        transaction = conn.transaction()
        await transaction.start()
        try:
            ids = await _seed(conn)
            repository = BeerRepository(_SingleConnectionPool(conn))
            await body(repository, ids)
        finally:
            await transaction.rollback()
            await conn.close()

    asyncio.run(wrapper())


def test_search_matches_beer_name(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None,
            style_id=None,
            brewery_id=None,
            q="chouffe search",
            page=1,
            page_size=20,
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["beer_id"]

    _run(integration_dsn, body)


def test_search_matches_brewery_name(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="Chouffe Test", page=1, page_size=20
        )
        # Every beer seeded by this test shares the same brewery, whose name
        # contains "Chouffe Test" -- all four must match via the joined
        # brewery name, not just the one whose own name also mentions it.
        matched_ids = {str(row["id"]) for row in rows}
        assert total == len(matched_ids) == 4
        assert matched_ids == {
            ids["beer_id"],
            ids["percent_beer_id"],
            ids["underscore_beer_id"],
            ids["noise_beer_id"],
        }

    _run(integration_dsn, body)


def test_search_matches_style_name(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="Test Stout", page=1, page_size=20
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["beer_id"]

    _run(integration_dsn, body)


def test_search_matches_country_name(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="Test Land", page=1, page_size=20
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["beer_id"]

    _run(integration_dsn, body)


def test_search_is_case_insensitive(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None,
            style_id=None,
            brewery_id=None,
            q="CHOUFFE SEARCH",
            page=1,
            page_size=20,
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["beer_id"]

    _run(integration_dsn, body)


def test_search_combined_with_exact_filter_narrows_results(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        # "chouffe" alone matches both the brewery name (shared by every
        # seeded beer) -- adding style_id narrows to just the one beer.
        rows, total = await repository.list_paginated(
            country_id=None,
            style_id=ids["style_id"],
            brewery_id=None,
            q="chouffe",
            page=1,
            page_size=20,
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["beer_id"]

    _run(integration_dsn, body)


def test_search_literal_percent_does_not_match_whole_catalog(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="100%", page=1, page_size=20
        )
        # "100% Test Beer"'s own name and its country's name ("100%
        # Wonderland") both contain a literal '100%' -- one matching row,
        # not the whole four-beer seeded catalog (which an unescaped '%'
        # wildcard would incorrectly match in full).
        matched_ids = {str(row["id"]) for row in rows}
        assert total == len(matched_ids) == 1
        assert matched_ids == {ids["percent_beer_id"]}

    _run(integration_dsn, body)


def test_search_literal_underscore_matches_only_literal_underscore(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="under_score", page=1, page_size=20
        )
        assert total == 1
        assert str(rows[0]["id"]) == ids["underscore_beer_id"]

    _run(integration_dsn, body)


def test_total_reflects_the_searched_filtered_result_set(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        rows, total = await repository.list_paginated(
            country_id=None, style_id=None, brewery_id=None, q="chouffe search", page=1, page_size=1
        )
        # page_size=1 means the page of results is smaller than the full
        # match count would be if this seed had more than one match -- here
        # it also confirms `total` isn't silently the unfiltered catalog
        # count (which would be 4 seeded beers, not 1).
        assert total == 1
        assert len(rows) == 1

    _run(integration_dsn, body)
