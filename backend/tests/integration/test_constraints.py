import asyncio
from decimal import Decimal

import asyncpg
import pytest

from app.db import parse_dsn_kwargs

pytestmark = pytest.mark.integration


async def _in_rolled_back_transaction(dsn: str, body) -> None:
    conn = await asyncpg.connect(**parse_dsn_kwargs(dsn), ssl="require")
    transaction = conn.transaction()
    await transaction.start()
    try:
        await body(conn)
    finally:
        await transaction.rollback()
        await conn.close()


def _run(dsn: str, body) -> None:
    asyncio.run(_in_rolled_back_transaction(dsn, body))


def test_country_iso_code_must_be_two_uppercase_letters(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.countries (iso_code, name, continent) "
                "values ('ie', 'Ireland', 'Europe')"
            )

    _run(integration_dsn, body)


def test_country_iso_code_must_be_unique(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        await conn.execute(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe')"
        )
        with pytest.raises(asyncpg.UniqueViolationError):
            await conn.execute(
                "insert into public.countries (iso_code, name, continent) "
                "values ('ZZ', 'Other Land', 'Europe')"
            )

    _run(integration_dsn, body)


def test_beer_abv_out_of_range_is_rejected(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) values ('Test Brewery', $1) "
            "returning id",
            country_id,
        )
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.beers (official_name, brewery_id, abv) "
                "values ('Bad Beer', $1, $2)",
                brewery_id,
                Decimal("150.0"),
            )

    _run(integration_dsn, body)


def test_beer_ibu_negative_is_rejected(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) values ('Test Brewery', $1) "
            "returning id",
            country_id,
        )
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.beers (official_name, brewery_id, ibu) "
                "values ('Bad Beer', $1, -5)",
                brewery_id,
            )

    _run(integration_dsn, body)


def test_brewery_latitude_longitude_must_be_paired(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.breweries (name, country_id, latitude) "
                "values ('Test Brewery', $1, 10.0)",
                country_id,
            )

    _run(integration_dsn, body)


def test_beer_brewery_id_foreign_key_is_enforced(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        with pytest.raises(asyncpg.ForeignKeyViolationError):
            await conn.execute(
                "insert into public.beers (official_name, brewery_id) "
                "values ('Orphan Beer', '00000000-0000-0000-0000-000000000000')"
            )

    _run(integration_dsn, body)


def test_beer_barcode_must_be_unique_when_present(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        country_id = await conn.fetchval(
            "insert into public.countries (iso_code, name, continent) "
            "values ('ZZ', 'Test Land', 'Europe') returning id"
        )
        brewery_id = await conn.fetchval(
            "insert into public.breweries (name, country_id) values ('Test Brewery', $1) "
            "returning id",
            country_id,
        )
        await conn.execute(
            "insert into public.beers (official_name, brewery_id, barcode) "
            "values ('Beer One', $1, '1234567890123')",
            brewery_id,
        )
        with pytest.raises(asyncpg.UniqueViolationError):
            await conn.execute(
                "insert into public.beers (official_name, brewery_id, barcode) "
                "values ('Beer Two', $1, '1234567890123')",
                brewery_id,
            )

    _run(integration_dsn, body)
