"""Integration tests for CollectionRepository's list/get queries against a
real database -- unique-beers-tried correctness, the exact per-tab/per-sort
ORDER BY clauses, and that every row is self-sufficient (brewery/style/
country names present with no follow-up query). Mirrors
tests/integration/test_beer_search.py's `_SingleConnectionPool` pattern:
seeds data as the connecting (elevated) role, then switches to
`beerapp_backend` -- required both for the table grants and so the RLS
policy (`backend_owns_rows`, scoped `TO beerapp_backend`) actually applies --
before exercising the repository, all inside one rolled-back transaction.
"""

import asyncio
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta

import asyncpg
import pytest

from app.db import parse_dsn_kwargs
from app.repositories.collection import CollectionRepository

pytestmark = pytest.mark.integration

_USER_ID = "11111111-1111-1111-1111-111111111111"


class _SingleConnectionPool:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set local role beerapp_backend")


async def _seed_catalog(conn: asyncpg.Connection) -> dict[str, str]:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    other_country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('YY', 'Other Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Alpha Brewery', $1) returning id",
        country_id,
    )
    other_brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Zulu Brewery', $1) returning id",
        other_country_id,
    )
    style_id = await conn.fetchval(
        "insert into public.beer_styles (name) values ('Test Stout') returning id"
    )

    beer_alpha = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, style_id, country_id) "
        "values ('Zeta Beer', $1, $2, $3) returning id",
        brewery_id,
        style_id,
        country_id,
    )
    # lowercase official_name, so it only sorts first under a case-insensitive comparison.
    beer_beta = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, style_id, country_id) "
        "values ('alpha beer', $1, $2, $3) returning id",
        other_brewery_id,
        style_id,
        other_country_id,
    )
    return {
        "country_id": str(country_id),
        "other_country_id": str(other_country_id),
        "brewery_id": str(brewery_id),
        "other_brewery_id": str(other_brewery_id),
        "style_id": str(style_id),
        "beer_alpha": str(beer_alpha),
        "beer_beta": str(beer_beta),
    }


def _run(dsn: str, body) -> None:
    async def wrapper() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
        transaction = conn.transaction()
        await transaction.start()
        try:
            ids = await _seed_catalog(conn)
            await _as_backend_role(conn)
            repository = CollectionRepository(_SingleConnectionPool(conn))
            await body(repository, ids)
        finally:
            await transaction.rollback()
            await conn.close()

    asyncio.run(wrapper())


# -- unique beers tried, despite multiple logs -------------------------------


def test_unique_beers_tried_counts_distinct_beer_id_not_total_logs(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            now = datetime.now(UTC)
            # Three logs of the SAME beer, at different times/ratings.
            for i, rating in enumerate([3, 5, 4]):
                await conn.execute(
                    "insert into public.user_beer_logs (user_id, beer_id, rating, consumed_at) "
                    "values ($1, $2, $3, $4)",
                    _USER_ID,
                    ids["beer_alpha"],
                    rating,
                    now - timedelta(days=i),
                )

        rows, total = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        # One row for the beer, not three -- and its rating/date reflect the
        # LATEST log (i=0, rating 3, most recent consumed_at), not an
        # average and not the first-inserted row.
        assert total == 1
        assert len(rows) == 1
        assert str(rows[0]["beer_id"]) == ids["beer_alpha"]
        assert rows[0]["latest_rating"] == 3

    _run(integration_dsn, body)


# -- self-sufficient rows: brewery/style/country names present --------------


def test_logged_row_carries_brewery_style_country_names_inline(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_ID,
                ids["beer_alpha"],
            )

        rows, _ = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        assert rows[0]["brewery_name"] == "Alpha Brewery"
        assert rows[0]["style_name"] == "Test Stout"
        assert rows[0]["country_name"] == "Test Land"

    _run(integration_dsn, body)


# -- favorite/wishlist independence, and rows appear on the right tab -------


def test_favoriting_a_beer_does_not_appear_on_wishlist_tab(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        await repository.set_state(
            user_id=_USER_ID, beer_id=ids["beer_alpha"], is_favorite=True, is_wishlist=None
        )

        favorites_rows, favorites_total = await repository.list_favorites(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
        wishlist_rows, wishlist_total = await repository.list_wishlist(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        assert favorites_total == 1
        assert str(favorites_rows[0]["beer_id"]) == ids["beer_alpha"]
        assert wishlist_total == 0

    _run(integration_dsn, body)


# -- filters ------------------------------------------------------------------


def test_logged_country_filter_narrows_results(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            for beer_id in (ids["beer_alpha"], ids["beer_beta"]):
                await conn.execute(
                    "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                    _USER_ID,
                    beer_id,
                )

        rows, total = await repository.list_logged(
            user_id=_USER_ID,
            country_id=ids["country_id"],
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        assert total == 1
        assert str(rows[0]["beer_id"]) == ids["beer_alpha"]

    _run(integration_dsn, body)


# -- exact ORDER BY per tab and sort value ------------------------------------


def test_logged_sort_by_name_is_case_insensitive(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            for beer_id in (ids["beer_alpha"], ids["beer_beta"]):
                await conn.execute(
                    "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                    _USER_ID,
                    beer_id,
                )

        rows, _ = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="name",
            page=1,
            page_size=20,
        )

        # "alpha beer" (lowercase) sorts before "Zeta Beer" only if the
        # comparison is case-insensitive (lower(official_name)) -- a plain
        # byte-order sort would put every uppercase "Z..." before "a...".
        assert [str(r["beer_id"]) for r in rows] == [ids["beer_beta"], ids["beer_alpha"]]

    _run(integration_dsn, body)


def test_logged_sort_by_rating_puts_unrated_last(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id, rating) values ($1, $2, $3)",
                _USER_ID,
                ids["beer_alpha"],
                4,
            )
            # No rating at all for beer_beta.
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_ID,
                ids["beer_beta"],
            )

        rows, _ = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="rating",
            page=1,
            page_size=20,
        )

        assert [str(r["beer_id"]) for r in rows] == [ids["beer_alpha"], ids["beer_beta"]]

    _run(integration_dsn, body)


def test_favorites_sort_by_recent_uses_favorited_at_not_log_date(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        # beer_beta favorited first, beer_alpha favorited second -- alpha
        # must sort first under sort=recent regardless of any log dates.
        await repository.set_state(
            user_id=_USER_ID, beer_id=ids["beer_beta"], is_favorite=True, is_wishlist=None
        )
        await repository.set_state(
            user_id=_USER_ID, beer_id=ids["beer_alpha"], is_favorite=True, is_wishlist=None
        )

        rows, _ = await repository.list_favorites(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        assert [str(r["beer_id"]) for r in rows] == [ids["beer_alpha"], ids["beer_beta"]]

    _run(integration_dsn, body)


def test_wishlist_shows_rating_from_logs_even_though_driven_by_collection_table(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        await repository.set_state(
            user_id=_USER_ID, beer_id=ids["beer_alpha"], is_favorite=None, is_wishlist=True
        )
        async with repository._scoped(_USER_ID) as conn:
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id, rating) values ($1, $2, $3)",
                _USER_ID,
                ids["beer_alpha"],
                5,
            )

        rows, _ = await repository.list_wishlist(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )

        assert rows[0]["latest_rating"] == 5

    _run(integration_dsn, body)


# -- pagination determinism ---------------------------------------------------


def test_logged_pagination_no_duplicate_or_skipped_rows_across_pages(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        async with repository._scoped(_USER_ID) as conn:
            for beer_id in (ids["beer_alpha"], ids["beer_beta"]):
                await conn.execute(
                    "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                    _USER_ID,
                    beer_id,
                )

        page1, total = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="name",
            page=1,
            page_size=1,
        )
        page2, _ = await repository.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="name",
            page=2,
            page_size=1,
        )

        assert total == 2
        seen = {str(page1[0]["beer_id"]), str(page2[0]["beer_id"])}
        assert seen == {ids["beer_alpha"], ids["beer_beta"]}

    _run(integration_dsn, body)


# -- GET /collection/{beer_id} 404-vs-200 query -------------------------------


def test_get_state_returns_no_row_for_nonexistent_beer(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        row = await repository.get_state(
            user_id=_USER_ID, beer_id="00000000-0000-0000-0000-000000000000"
        )
        assert row is None

    _run(integration_dsn, body)


def test_get_state_returns_false_false_for_real_beer_with_no_collection_row(integration_dsn):
    async def body(repository: CollectionRepository, ids: dict) -> None:
        row = await repository.get_state(user_id=_USER_ID, beer_id=ids["beer_alpha"])
        assert row is not None
        assert row["is_favorite"] is False
        assert row["is_wishlist"] is False

    _run(integration_dsn, body)
