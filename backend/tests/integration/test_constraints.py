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


async def _seed_beer(conn: asyncpg.Connection) -> str:
    country_id = await conn.fetchval(
        "insert into public.countries (iso_code, name, continent) "
        "values ('ZZ', 'Test Land', 'Europe') returning id"
    )
    brewery_id = await conn.fetchval(
        "insert into public.breweries (name, country_id) values ('Test Brewery', $1) returning id",
        country_id,
    )
    return await conn.fetchval(
        "insert into public.beers (official_name, brewery_id) values ('Test Beer', $1) "
        "returning id",
        brewery_id,
    )


def test_user_beer_log_rating_out_of_range_is_rejected(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id, rating) "
                "values ('00000000-0000-0000-0000-000000000001', $1, 6)",
                beer_id,
            )

    _run(integration_dsn, body)


def test_user_beer_log_price_currency_must_be_paired(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id, price) "
                "values ('00000000-0000-0000-0000-000000000001', $1, 5.00)",
                beer_id,
            )

    _run(integration_dsn, body)


def test_user_beer_log_serving_volume_ml_must_be_positive(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        with pytest.raises(asyncpg.CheckViolationError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id, serving_volume_ml) "
                "values ('00000000-0000-0000-0000-000000000001', $1, 0)",
                beer_id,
            )

    _run(integration_dsn, body)


def test_user_beer_log_serving_volume_ml_null_is_allowed(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        # Must not raise -- an absent serving_volume_ml is a fully valid log.
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) "
            "values ('00000000-0000-0000-0000-000000000001', $1)",
            beer_id,
        )

    _run(integration_dsn, body)


def test_user_beer_log_beer_id_foreign_key_is_enforced(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        with pytest.raises(asyncpg.ForeignKeyViolationError):
            await conn.execute(
                "insert into public.user_beer_logs (user_id, beer_id) "
                "values ('00000000-0000-0000-0000-000000000001', "
                "'00000000-0000-0000-0000-000000000000')"
            )

    _run(integration_dsn, body)


def test_user_beer_log_beer_id_is_restrict_not_cascade(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        beer_id = await _seed_beer(conn)
        await conn.execute(
            "insert into public.user_beer_logs (user_id, beer_id) "
            "values ('00000000-0000-0000-0000-000000000001', $1)",
            beer_id,
        )
        with pytest.raises(asyncpg.ForeignKeyViolationError):
            await conn.execute("delete from public.beers where id = $1", beer_id)

    _run(integration_dsn, body)


def test_user_beer_log_user_id_foreign_key_is_cascade(integration_dsn):
    """Verified via pg_constraint metadata (confdeltype = 'c') rather than
    by actually deleting a real auth.users row -- cheaper, and avoids
    touching Supabase Auth state even in a disposable database.
    """

    async def body(conn: asyncpg.Connection) -> None:
        delete_rule = await conn.fetchval(
            "select confdeltype from pg_constraint "
            "where conrelid = 'public.user_beer_logs'::regclass "
            "and confrelid = 'auth.users'::regclass"
        )
        assert delete_rule == "c"

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
