"""Integration tests for StatisticsRepository against a real database:
unique-vs-total divergence, null-rating/null-style/null-currency exclusion,
the beer/brewery country fallback (mirroring MapRepository's), deterministic
favorite tie-breaking, the trailing-12-months zero-filled window vs.
all-time non-zero-filled yearly activity, UTC-bucket independence from the
connection's session timezone, and that get_statistics runs under
REPEATABLE READ.

Unlike most other integration test files in this package,
StatisticsRepository._scoped() opens its transaction at REPEATABLE READ
(see docs/DECISIONS.md), and Postgres does not allow changing the isolation
level on a nested transaction/SAVEPOINT. So these tests cannot use the usual
"seed and repository calls all inside one already-open outer transaction,
rolled back at the end" pattern (that would nest get_statistics's own
transaction inside it). Instead, _seed_and_get_statistics runs seeding,
the get_statistics call, and cleanup as three separate top-level
transactions/statements on the same connection -- seeding commits for real,
get_statistics runs its own genuinely top-level REPEATABLE READ transaction
against the committed data, and cleanup then deletes everything seeded.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with all
migrations applied, whose connecting role can `SET ROLE beerapp_backend`.
Never run against DATABASE_URL/SEED_DATABASE_URL or the shared dev project.
"""

import asyncio
from contextlib import asynccontextmanager
from datetime import UTC, datetime

import asyncpg
import pytest

from app.repositories.statistics import StatisticsRepository

from .disposable_db import connection_kwargs, ensure_users, remove_users

pytestmark = pytest.mark.integration

_USER_ID = "11111111-1111-1111-1111-111111111111"


class _SingleConnectionPool:
    """Stands in for the app's pool: the repository acquires the connection AS
    `beerapp_backend` (so RLS applies, as in production) and returns it as the
    connecting admin role on exit, which is what test setup/cleanup needs.
    """

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn
        self._depth = 0

    @asynccontextmanager
    async def acquire(self):
        if self._depth == 0:
            await self._conn.execute("set role beerapp_backend")
        self._depth += 1
        try:
            yield self._conn
        finally:
            self._depth -= 1
            if self._depth == 0:
                await self._conn.execute("reset role")


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set local role beerapp_backend")


async def _set_identity(conn: asyncpg.Connection, user_id: str) -> None:
    await conn.execute("select set_config('app.user_id', $1, true)", user_id)


async def _seed_country(conn: asyncpg.Connection, iso_code: str, name: str) -> str:
    return await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ($1, $2, 'Europe') returning id",
        iso_code,
        name,
    )


async def _seed_brewery(
    conn: asyncpg.Connection, *, country_id: str, name: str = "Test Brewery"
) -> str:
    return await conn.fetchval(
        "insert into public.breweries (name, country_id) values ($1, $2) returning id",
        name,
        country_id,
    )


async def _seed_style(conn: asyncpg.Connection, name: str = "Test Style") -> str:
    return await conn.fetchval(
        "insert into public.beer_styles (name) values ($1) returning id", name
    )


async def _seed_beer(
    conn: asyncpg.Connection,
    *,
    brewery_id: str,
    style_id: str | None = None,
    country_id: str | None = None,
    name: str = "Test Beer",
) -> str:
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, style_id, country_id) "
        "values ($1, $2, $3, $4) returning id",
        name,
        brewery_id,
        style_id,
        country_id,
    )


async def _insert_log(
    conn: asyncpg.Connection,
    *,
    user_id: str,
    beer_id: str,
    rating: int | None = None,
    consumed_at: datetime | None = None,
    price=None,
    currency: str | None = None,
) -> None:
    await _as_backend_role(conn)
    await _set_identity(conn, user_id)
    await conn.execute(
        "insert into public.user_beer_logs "
        "(user_id, beer_id, rating, consumed_at, price, currency) "
        "values ($1, $2, $3, coalesce($4, now()), $5, $6)",
        user_id,
        beer_id,
        rating,
        consumed_at,
        price,
        currency,
    )


async def _insert_favorite(conn: asyncpg.Connection, *, user_id: str, beer_id: str) -> None:
    await _as_backend_role(conn)
    await _set_identity(conn, user_id)
    await conn.execute(
        "insert into public.user_beer_collection "
        "(user_id, beer_id, is_favorite, favorited_at) "
        "values ($1, $2, true, now())",
        user_id,
        beer_id,
    )


def _empty_ids() -> dict[str, list[str]]:
    return {"country_ids": [], "brewery_ids": [], "style_ids": [], "beer_ids": []}


async def _seed_and_get_statistics(dsn: str, *, seed, user_ids: list[str]):
    """Runs `seed(conn) -> ids dict` as one committed setup transaction,
    then calls StatisticsRepository.get_statistics(user_id=...) for each of
    `user_ids` as its own top-level transaction, then deletes everything
    `seed` reported creating. Returns {user_id: get_statistics()-result}.
    """
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    ids = _empty_ids()
    try:
        await ensure_users(conn, *user_ids)
        async with conn.transaction():
            ids = await seed(conn)

        repository = StatisticsRepository(_SingleConnectionPool(conn))
        results = {}
        for user_id in user_ids:
            results[user_id] = await repository.get_statistics(user_id=user_id)
        return results
    finally:
        async with conn.transaction():
            await _as_backend_role(conn)
            for user_id in user_ids:
                await _set_identity(conn, user_id)
                for beer_id in ids["beer_ids"]:
                    await conn.execute(
                        "delete from public.user_beer_logs where user_id = $1 and beer_id = $2",
                        user_id,
                        beer_id,
                    )
                    await conn.execute(
                        "delete from public.user_beer_collection "
                        "where user_id = $1 and beer_id = $2",
                        user_id,
                        beer_id,
                    )
        await remove_users(conn, *user_ids)
        for beer_id in ids["beer_ids"]:
            await conn.execute("delete from public.beers where id = $1", beer_id)
        for style_id in ids["style_ids"]:
            await conn.execute("delete from public.beer_styles where id = $1", style_id)
        for brewery_id in ids["brewery_ids"]:
            await conn.execute("delete from public.breweries where id = $1", brewery_id)
        for country_id in ids["country_ids"]:
            await conn.execute("delete from public.countries where id = $1", country_id)
        await conn.close()


def _shift_months(dt: datetime, delta: int) -> datetime:
    """dt must be day-of-month 1 (a date_trunc('month', ...) result) --
    avoids needing a calendar/dateutil dependency just for this.
    """
    month_index = dt.month - 1 + delta
    year = dt.year + month_index // 12
    month = month_index % 12 + 1
    return dt.replace(year=year, month=month)


# -- total logs vs. unique beers ----------------------------------------------


def test_total_logs_and_total_unique_beers_diverge_for_a_repeated_beer(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        for _ in range(3):
            await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    overview = results[_USER_ID]["overview"]

    assert overview["total_logs"] == 3
    assert overview["total_unique_beers"] == 1


# -- null style excluded from styles_discovered, not from unique beers -------


def test_beer_with_null_style_counts_toward_unique_not_styles_discovered(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id, style_id=None)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    overview = results[_USER_ID]["overview"]

    assert overview["total_unique_beers"] == 1
    assert overview["styles_discovered"] == 0


# -- average rating excludes null ratings -------------------------------------


def test_average_rating_excludes_unrated_logs(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, rating=4)
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, rating=None)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    overview = results[_USER_ID]["overview"]

    # Not (4 + 0) / 2 = 2.0 -- the unrated log must be excluded entirely.
    assert float(overview["average_rating"]) == pytest.approx(4.0)


# -- amount spent grouped per currency, null price/currency excluded --------


def test_amount_spent_grouped_by_currency_excludes_unpriced_logs(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, price="5.00", currency="USD")
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, price="7.50", currency="USD")
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, price="4.00", currency="EUR")
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, price=None, currency=None)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    result = results[_USER_ID]

    assert result["overview"]["total_logs"] == 4
    by_currency = {row["currency"]: row["total"] for row in result["amount_spent"]}
    assert by_currency == {"USD": 12.50, "EUR": 4.00}


# -- country fallback: beer's own country wins over brewery's ----------------


def test_favorite_country_prefers_beers_own_country_over_brewery_country(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_a = await _seed_country(conn, "AA", "Country A")
        country_b = await _seed_country(conn, "BB", "Country B")
        brewery_id = await _seed_brewery(conn, country_id=country_b, name="Brewery B")
        beer_id = await _seed_beer(conn, brewery_id=brewery_id, country_id=country_a)
        ids["country_ids"] += [country_a, country_b]
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_favorite(conn, user_id=_USER_ID, beer_id=beer_id)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))

    assert results[_USER_ID]["favorites"]["favorite_country"] == "Country A"


def test_countries_discovered_and_favorite_country_fall_back_to_brewery_when_beer_country_null(
    integration_dsn,
):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "BB", "Country B")
        brewery_id = await _seed_brewery(conn, country_id=country_id, name="Brewery B")
        beer_id = await _seed_beer(conn, brewery_id=brewery_id, country_id=None)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id)
        await _insert_favorite(conn, user_id=_USER_ID, beer_id=beer_id)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    result = results[_USER_ID]

    # A beer with no own country is never excluded -- breweries.country_id
    # is NOT NULL, so the effective country always resolves via the brewery.
    assert result["overview"]["countries_discovered"] == 1
    assert result["favorites"]["favorite_country"] == "Country B"


# -- favorite tie-break: case-insensitive name -------------------------------


def test_favorite_brewery_tie_break_is_case_insensitive_by_name(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        ids["country_ids"].append(country_id)
        brewery_lower = await _seed_brewery(conn, country_id=country_id, name="apple Brewing")
        brewery_upper = await _seed_brewery(conn, country_id=country_id, name="Zulu Brewing")
        ids["brewery_ids"] += [brewery_lower, brewery_upper]
        beer_lower = await _seed_beer(conn, brewery_id=brewery_lower, name="Beer Lower")
        beer_upper = await _seed_beer(conn, brewery_id=brewery_upper, name="Beer Upper")
        ids["beer_ids"] += [beer_lower, beer_upper]
        await _insert_favorite(conn, user_id=_USER_ID, beer_id=beer_lower)
        await _insert_favorite(conn, user_id=_USER_ID, beer_id=beer_upper)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))

    # "apple Brewing" sorts before "Zulu Brewing" only under a
    # case-insensitive comparison -- a plain byte-order sort would put every
    # uppercase "Z..." before lowercase "a...".
    assert results[_USER_ID]["favorites"]["favorite_brewery"] == "apple Brewing"


# -- favorite tie-break: stable id as the final tie-breaker -------------------


def test_tie_break_order_prefers_lower_id_when_count_and_name_both_tie(integration_dsn):
    """A true name collision isn't practical to seed through valid catalog
    data (beer_styles/countries have case-insensitive unique name indexes;
    breweries don't, but constructing a real double-favorite tie on an
    identical brewery name adds no information the plan didn't already ask
    to verify directly). Asserts the SQL ordering clause itself --
    `order by count(*) desc, lower(name) asc, id asc` -- is deterministic
    when both count and name tie, using a throwaway values() CTE.
    """

    async def check():
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        try:
            row = await conn.fetchrow(
                "with candidates(id, name, cnt) as ("
                "values "
                "('22222222-2222-2222-2222-222222222222'::uuid, 'Same Name', 2), "
                "('11111111-1111-1111-1111-111111111111'::uuid, 'Same Name', 2)"
                ") "
                "select id from candidates order by cnt desc, lower(name) asc, id asc limit 1"
            )
            assert str(row["id"]) == "11111111-1111-1111-1111-111111111111"
        finally:
            await conn.close()

    asyncio.run(check())


# -- zero favorites ------------------------------------------------------------


def test_zero_favorites_yields_null_favorite_fields(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        # Logged but never favorited.
        await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id)
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    favorites = results[_USER_ID]["favorites"]

    assert favorites["favorite_style"] is None
    assert favorites["favorite_country"] is None
    assert favorites["favorite_brewery"] is None


# -- monthly activity: trailing 12 months, zero-filled ------------------------


def test_monthly_activity_trailing_12_months_boundary(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)

        current_month = await conn.fetchval("select date_trunc('month', now() at time zone 'utc')")
        inside_month = _shift_months(current_month, -11)
        outside_month = _shift_months(current_month, -13)

        await _insert_log(
            conn, user_id=_USER_ID, beer_id=beer_id, consumed_at=inside_month.replace(tzinfo=UTC)
        )
        await _insert_log(
            conn, user_id=_USER_ID, beer_id=beer_id, consumed_at=outside_month.replace(tzinfo=UTC)
        )
        ids["_inside_month"] = inside_month.date()
        ids["_outside_month"] = outside_month.date()
        return ids

    async def run():
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        ids = _empty_ids()
        try:
            await ensure_users(conn, _USER_ID)
            async with conn.transaction():
                ids = await seed(conn)
            repository = StatisticsRepository(_SingleConnectionPool(conn))
            return ids, await repository.get_statistics(user_id=_USER_ID)
        finally:
            async with conn.transaction():
                await _as_backend_role(conn)
                await _set_identity(conn, _USER_ID)
                for beer_id in ids["beer_ids"]:
                    await conn.execute(
                        "delete from public.user_beer_logs where user_id = $1 and beer_id = $2",
                        _USER_ID,
                        beer_id,
                    )
            await remove_users(conn, _USER_ID)
            for beer_id in ids["beer_ids"]:
                await conn.execute("delete from public.beers where id = $1", beer_id)
            for brewery_id in ids["brewery_ids"]:
                await conn.execute("delete from public.breweries where id = $1", brewery_id)
            for country_id in ids["country_ids"]:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await conn.close()

    ids, result = asyncio.run(run())

    assert result["overview"]["total_logs"] == 2
    assert len(result["monthly_activity"]) == 12
    months = {row["month"] for row in result["monthly_activity"]}
    assert ids["_inside_month"] in months
    assert ids["_outside_month"] not in months
    # Both logs still count toward yearly activity, regardless of the
    # monthly window.
    years = {row["year"] for row in result["yearly_activity"]}
    assert ids["_inside_month"].year in years
    assert ids["_outside_month"].year in years


# -- UTC bucketing independent of session timezone ----------------------------


def test_monthly_bucket_is_utc_independent_of_session_timezone(integration_dsn):
    async def run():
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        ids = _empty_ids()
        try:
            await ensure_users(conn, _USER_ID)
            async with conn.transaction():
                country_id = await _seed_country(conn, "ZZ", "Test Land")
                brewery_id = await _seed_brewery(conn, country_id=country_id)
                beer_id = await _seed_beer(conn, brewery_id=brewery_id)
                ids["country_ids"].append(country_id)
                ids["brewery_ids"].append(brewery_id)
                ids["beer_ids"].append(beer_id)
                # 2026-01-01T00:30:00Z is 2025-12-31T19:30 in US Eastern --
                # must bucket into January 2026, never December 2025.
                consumed_at = datetime(2026, 1, 1, 0, 30, tzinfo=UTC)
                await _insert_log(conn, user_id=_USER_ID, beer_id=beer_id, consumed_at=consumed_at)

            repository = StatisticsRepository(_SingleConnectionPool(conn))
            async with repository._scoped(_USER_ID) as scoped_conn:
                await scoped_conn.execute("set local timezone = 'America/New_York'")
                monthly_rows = await scoped_conn.fetch(
                    "select date_trunc('month', consumed_at at time zone 'utc')::date as month, "
                    "count(*) as log_count "
                    "from public.user_beer_logs where user_id = $1 group by 1",
                    _USER_ID,
                )
                yearly_rows = await scoped_conn.fetch(
                    "select extract(year from consumed_at at time zone 'utc')::int as year, "
                    "count(*) as log_count "
                    "from public.user_beer_logs where user_id = $1 group by 1",
                    _USER_ID,
                )
            return ids, monthly_rows, yearly_rows
        finally:
            async with conn.transaction():
                await _as_backend_role(conn)
                await _set_identity(conn, _USER_ID)
                for beer_id in ids["beer_ids"]:
                    await conn.execute(
                        "delete from public.user_beer_logs where user_id = $1 and beer_id = $2",
                        _USER_ID,
                        beer_id,
                    )
            await remove_users(conn, _USER_ID)
            for beer_id in ids["beer_ids"]:
                await conn.execute("delete from public.beers where id = $1", beer_id)
            for brewery_id in ids["brewery_ids"]:
                await conn.execute("delete from public.breweries where id = $1", brewery_id)
            for country_id in ids["country_ids"]:
                await conn.execute("delete from public.countries where id = $1", country_id)
            await conn.close()

    _ids, monthly_rows, yearly_rows = asyncio.run(run())

    from datetime import date

    assert {row["month"] for row in monthly_rows} == {date(2026, 1, 1)}
    assert {row["year"] for row in yearly_rows} == {2026}


# -- yearly activity: no zero-fill for a gap year -----------------------------


def test_yearly_activity_has_no_row_for_a_year_with_no_logs(integration_dsn):
    async def seed(conn):
        ids = _empty_ids()
        country_id = await _seed_country(conn, "ZZ", "Test Land")
        brewery_id = await _seed_brewery(conn, country_id=country_id)
        beer_id = await _seed_beer(conn, brewery_id=brewery_id)
        ids["country_ids"].append(country_id)
        ids["brewery_ids"].append(brewery_id)
        ids["beer_ids"].append(beer_id)
        await _insert_log(
            conn, user_id=_USER_ID, beer_id=beer_id, consumed_at=datetime(2024, 6, 1, tzinfo=UTC)
        )
        # 2025 deliberately skipped.
        await _insert_log(
            conn, user_id=_USER_ID, beer_id=beer_id, consumed_at=datetime(2026, 6, 1, tzinfo=UTC)
        )
        return ids

    results = asyncio.run(_seed_and_get_statistics(integration_dsn, seed=seed, user_ids=[_USER_ID]))
    years = {row["year"] for row in results[_USER_ID]["yearly_activity"]}

    assert years == {2024, 2026}


# -- REPEATABLE READ isolation -------------------------------------------------


def test_get_statistics_transaction_uses_repeatable_read(integration_dsn):
    async def check():
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        try:
            repository = StatisticsRepository(_SingleConnectionPool(conn))
            async with repository._scoped(_USER_ID) as scoped_conn:
                level = await scoped_conn.fetchval(
                    "select current_setting('transaction_isolation')"
                )
            assert level == "repeatable read"
        finally:
            await conn.close()

    asyncio.run(check())
