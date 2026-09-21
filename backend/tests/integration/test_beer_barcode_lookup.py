import asyncio
from contextlib import asynccontextmanager

import asyncpg
import pytest

from app.repositories.beers import BeerRepository

from .disposable_db import connection_kwargs

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
        "values ('ZZ', 'Barcode Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) "
        "values ('Barcode Test Brewery', $1) returning id",
        country_id,
    )
    with_barcode_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id, barcode) "
        "values ('Scannable Test Beer', $1, '5000213007075') returning id",
        brewery_id,
    )
    without_barcode_id = await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) "
        "values ('Barcode-less Test Beer', $1) returning id",
        brewery_id,
    )
    return {
        "brewery_id": str(brewery_id),
        "with_barcode_id": str(with_barcode_id),
        "without_barcode_id": str(without_barcode_id),
    }


def _run(dsn: str, body) -> None:
    async def wrapper() -> None:
        conn = await asyncpg.connect(**connection_kwargs(dsn))
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


def test_get_by_barcode_returns_the_matching_beer(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        row = await repository.get_by_barcode("5000213007075")
        assert row is not None
        assert str(row["id"]) == ids["with_barcode_id"]

    _run(integration_dsn, body)


def test_get_by_barcode_returns_none_for_unknown_barcode(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        row = await repository.get_by_barcode("2222222222222")
        assert row is None

    _run(integration_dsn, body)


def test_get_by_barcode_never_matches_a_beer_with_a_null_barcode(integration_dsn):
    async def body(repository: BeerRepository, ids: dict) -> None:
        # A beer with no barcode is normal, not an error -- confirm the
        # lookup never accidentally matches it via a NULL comparison quirk.
        row = await repository.get_by_barcode("")
        assert row is None

    _run(integration_dsn, body)
