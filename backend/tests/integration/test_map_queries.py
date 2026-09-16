"""Integration tests for MapRepository against a real database.

Covers what unit tests with fakes cannot: that /map/beers' personal-state
read actually runs under the RLS-scoped `app.user_id` transaction (proving
user isolation through the repository itself, not just its own `WHERE
user_id = $N`), the paired coordinate fallback never mixes one table's
latitude with the other's longitude, the single-select `state` filter, and
the truncation cap. Mirrors tests/integration/test_collection_queries.py's
_SingleConnectionPool + `_as_backend_role` pattern, and
tests/integration/test_user_beer_collection_rls.py's two-user isolation
style.

Requires INTEGRATION_DATABASE_URL to point at a disposable database with all
migrations applied, whose connecting role can `SET ROLE beerapp_backend`.
Never run against DATABASE_URL/SEED_DATABASE_URL or the shared dev project.
"""

import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

import app.repositories.map as map_repository_module
from app.db import parse_dsn_kwargs
from app.repositories.map import MapRepository

pytestmark = pytest.mark.integration

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "22222222-2222-2222-2222-222222222222"


class _SingleConnectionPool:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    @asynccontextmanager
    async def acquire(self):
        yield self._conn


async def _as_backend_role(conn: asyncpg.Connection) -> None:
    await conn.execute("set local role beerapp_backend")


async def _seed_country_and_brewery(
    conn: asyncpg.Connection, *, brewery_lat=None, brewery_lng=None
) -> dict[str, str]:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id, latitude, longitude) "
        "values ('Test Brewery', $1, $2, $3) returning id",
        country_id,
        brewery_lat,
        brewery_lng,
    )
    return {"country_id": str(country_id), "brewery_id": str(brewery_id)}


async def _insert_beer(
    conn: asyncpg.Connection, *, brewery_id: str, latitude=None, longitude=None, name="Test Beer"
) -> str:
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, latitude, longitude) "
        "values ($1, $2, $3, $4) returning id",
        name,
        brewery_id,
        latitude,
        longitude,
    )


def _run(dsn: str, body) -> None:
    async def wrapper() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
        transaction = conn.transaction()
        await transaction.start()
        try:
            await _as_backend_role(conn)
            repository = MapRepository(_SingleConnectionPool(conn))
            await body(conn, repository)
        finally:
            await transaction.rollback()
            await conn.close()

    asyncio.run(wrapper())


# -- paired coordinate fallback -----------------------------------------


def test_beer_with_own_pair_uses_own_coordinates(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        beer_id = await _insert_beer(
            conn, brewery_id=ids["brewery_id"], latitude="1.5", longitude="2.5"
        )

        rows, _ = await repository.list_beers(user_id=_USER_A, state="all", country_id=None, q=None)

        assert len(rows) == 1
        assert str(rows[0]["beer_id"]) == str(beer_id)
        assert rows[0]["latitude"] == pytest.approx(1.5)
        assert rows[0]["longitude"] == pytest.approx(2.5)

    _run(integration_dsn, body)


def test_beer_without_own_pair_falls_back_to_brewery_pair(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        beer_id = await _insert_beer(conn, brewery_id=ids["brewery_id"])

        rows, _ = await repository.list_beers(user_id=_USER_A, state="all", country_id=None, q=None)

        assert len(rows) == 1
        assert str(rows[0]["beer_id"]) == str(beer_id)
        assert rows[0]["latitude"] == pytest.approx(10.0)
        assert rows[0]["longitude"] == pytest.approx(20.0)

    _run(integration_dsn, body)


def test_beer_with_neither_pair_is_excluded(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn)
        await _insert_beer(conn, brewery_id=ids["brewery_id"])

        rows, _ = await repository.list_beers(user_id=_USER_A, state="all", country_id=None, q=None)

        assert rows == []

    _run(integration_dsn, body)


def test_fallback_never_mixes_beer_latitude_with_brewery_longitude(integration_dsn):
    """Proves the CASE-based selection, not just the CHECK constraint: a
    beer's marker is never (beer.latitude, brewery.longitude) or vice versa.
    Both DB CHECK constraints already forbid a *partially null* pair at
    each table's own row, so this test seeds two fully-valid-but-different
    pairs (own vs brewery) and asserts the result is one pair or the other,
    never a combination of the two.
    """

    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        beer_id = await _insert_beer(
            conn, brewery_id=ids["brewery_id"], latitude="1.5", longitude="2.5"
        )

        rows, _ = await repository.list_beers(user_id=_USER_A, state="all", country_id=None, q=None)

        assert len(rows) == 1
        row = rows[0]
        assert str(row["beer_id"]) == str(beer_id)
        own_pair = row["latitude"] == pytest.approx(1.5) and row["longitude"] == pytest.approx(2.5)
        brewery_pair = row["latitude"] == pytest.approx(10.0) and row["longitude"] == pytest.approx(
            20.0
        )
        assert own_pair or brewery_pair
        assert not (own_pair and brewery_pair)
        # Explicitly rule out a hybrid: beer's own latitude with the
        # brewery's longitude (or the reverse).
        hybrid_a = row["latitude"] == pytest.approx(1.5) and row["longitude"] == pytest.approx(20.0)
        hybrid_b = row["latitude"] == pytest.approx(10.0) and row["longitude"] == pytest.approx(2.5)
        assert not hybrid_a
        assert not hybrid_b

    _run(integration_dsn, body)


# -- RLS isolation of personal state --------------------------------------


def test_user_a_sees_own_tried_favorite_wishlist_state(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        beer_id = await _insert_beer(conn, brewery_id=ids["brewery_id"])

        async with repository._scoped(_USER_A) as scoped_conn:
            await scoped_conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                beer_id,
            )
            await scoped_conn.execute(
                "insert into public.user_beer_collection (user_id, beer_id, is_favorite) "
                "values ($1, $2, true)",
                _USER_A,
                beer_id,
            )

        rows, _ = await repository.list_beers(user_id=_USER_A, state="all", country_id=None, q=None)

        assert len(rows) == 1
        assert rows[0]["is_tried"] is True
        assert rows[0]["is_favorite"] is True
        assert rows[0]["is_wishlist"] is False

    _run(integration_dsn, body)


def test_user_b_never_sees_user_a_personal_state(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        beer_id = await _insert_beer(conn, brewery_id=ids["brewery_id"])

        async with repository._scoped(_USER_A) as scoped_conn:
            await scoped_conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                beer_id,
            )
            await scoped_conn.execute(
                "insert into public.user_beer_collection (user_id, beer_id, is_favorite, "
                "is_wishlist) values ($1, $2, true, true)",
                _USER_A,
                beer_id,
            )

        rows, _ = await repository.list_beers(user_id=_USER_B, state="all", country_id=None, q=None)

        # The beer is still visible (it's catalog data), but none of user
        # A's personal state leaks onto user B's view of it.
        assert len(rows) == 1
        assert rows[0]["is_tried"] is False
        assert rows[0]["is_favorite"] is False
        assert rows[0]["is_wishlist"] is False

    _run(integration_dsn, body)


def test_state_filter_tried_only_returns_logged_beers(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        tried_beer_id = await _insert_beer(conn, brewery_id=ids["brewery_id"], name="Tried Beer")
        not_tried_beer_id = await _insert_beer(
            conn, brewery_id=ids["brewery_id"], name="Not Tried Beer"
        )

        async with repository._scoped(_USER_A) as scoped_conn:
            await scoped_conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) values ($1, $2)",
                _USER_A,
                tried_beer_id,
            )

        tried_rows, _ = await repository.list_beers(
            user_id=_USER_A, state="tried", country_id=None, q=None
        )
        not_tried_rows, _ = await repository.list_beers(
            user_id=_USER_A, state="not_tried", country_id=None, q=None
        )

        assert {str(r["beer_id"]) for r in tried_rows} == {str(tried_beer_id)}
        assert {str(r["beer_id"]) for r in not_tried_rows} == {str(not_tried_beer_id)}

    _run(integration_dsn, body)


def test_state_filter_favorites_and_wishlist_are_independent(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        favorite_beer_id = await _insert_beer(
            conn, brewery_id=ids["brewery_id"], name="Favorite Beer"
        )
        wishlist_beer_id = await _insert_beer(
            conn, brewery_id=ids["brewery_id"], name="Wishlist Beer"
        )

        async with repository._scoped(_USER_A) as scoped_conn:
            await scoped_conn.execute(
                "insert into public.user_beer_collection (user_id, beer_id, is_favorite) "
                "values ($1, $2, true)",
                _USER_A,
                favorite_beer_id,
            )
            await scoped_conn.execute(
                "insert into public.user_beer_collection (user_id, beer_id, is_wishlist) "
                "values ($1, $2, true)",
                _USER_A,
                wishlist_beer_id,
            )

        favorite_rows, _ = await repository.list_beers(
            user_id=_USER_A, state="favorites", country_id=None, q=None
        )
        wishlist_rows, _ = await repository.list_beers(
            user_id=_USER_A, state="wishlist", country_id=None, q=None
        )

        assert {str(r["beer_id"]) for r in favorite_rows} == {str(favorite_beer_id)}
        assert {str(r["beer_id"]) for r in wishlist_rows} == {str(wishlist_beer_id)}

    _run(integration_dsn, body)


# -- truncation cap --------------------------------------------------------


def test_beers_truncated_flag_true_when_cap_exceeded(integration_dsn, monkeypatch):
    monkeypatch.setattr(map_repository_module, "MAP_BEERS_CAP", 2)

    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        for i in range(3):
            await _insert_beer(conn, brewery_id=ids["brewery_id"], name=f"Beer {i}")

        rows, truncated = await repository.list_beers(
            user_id=_USER_A, state="all", country_id=None, q=None
        )

        assert truncated is True
        assert len(rows) == 2

    _run(integration_dsn, body)


def test_beers_truncated_flag_false_when_cap_not_exceeded(integration_dsn, monkeypatch):
    monkeypatch.setattr(map_repository_module, "MAP_BEERS_CAP", 5)

    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        await _insert_beer(conn, brewery_id=ids["brewery_id"])

        rows, truncated = await repository.list_beers(
            user_id=_USER_A, state="all", country_id=None, q=None
        )

        assert truncated is False
        assert len(rows) == 1

    _run(integration_dsn, body)


def test_breweries_truncated_flag_true_when_cap_exceeded(integration_dsn, monkeypatch):
    monkeypatch.setattr(map_repository_module, "MAP_BREWERIES_CAP", 1)

    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        for i in range(2):
            await conn.execute(
                "insert into public.breweries (name, country_id, latitude, longitude) "
                "values ($1, $2, 10.0, 20.0)",
                f"Brewery {i}",
                country_id,
            )

        rows, truncated = await repository.list_breweries(country_id=None, q=None)

        assert truncated is True
        assert len(rows) == 1

    _run(integration_dsn, body)


# -- breweries endpoint: own coordinates only, no personal state ----------


def test_breweries_without_coordinates_are_excluded(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        await conn.execute(
            "insert into public.breweries (name, country_id) values ('No Location', $1)",
            country_id,
        )
        located_id = await conn.fetchval(
            "insert into public.breweries (name, country_id, latitude, longitude) "
            "values ('Located', $1, 10.0, 20.0) returning id",
            country_id,
        )

        rows, _ = await repository.list_breweries(country_id=None, q=None)

        assert len(rows) == 1
        assert str(rows[0]["brewery_id"]) == str(located_id)

    _run(integration_dsn, body)


def test_country_filter_narrows_beer_results(integration_dsn):
    async def body(conn: asyncpg.Connection, repository: MapRepository) -> None:
        ids = await _seed_country_and_brewery(conn, brewery_lat="10.0", brewery_lng="20.0")
        other_country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('YY', 'Other Land', 'Europe') returning id"
        )
        other_brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id, latitude, longitude) "
            "values ('Other Brewery', $1, 30.0, 40.0) returning id",
            other_country_id,
        )
        matching_beer_id = await _insert_beer(conn, brewery_id=ids["brewery_id"])
        await _insert_beer(conn, brewery_id=str(other_brewery_id), name="Other Beer")

        rows, _ = await repository.list_beers(
            user_id=_USER_A, state="all", country_id=ids["country_id"], q=None
        )

        assert {str(r["beer_id"]) for r in rows} == {str(matching_beer_id)}

    _run(integration_dsn, body)
