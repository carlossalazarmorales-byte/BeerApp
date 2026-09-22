"""The DRAFT reference-data SQL files applied to a DISPOSABLE database only.

Nothing here touches `beerapp-dev`, production or any shared database: the
`integration_dsn` fixture refuses anything that is not a disposable loopback (or
explicitly allowed) database. Most tests run inside a transaction that is always
rolled back, with the file's own `begin;`/`commit;` and DRAFT-GUARD removed (a real
`commit;` would persist). One test runs the unmodified-but-guard-stripped file,
transaction wrapper included, and cleans up after itself.
"""

import asyncio

import asyncpg
import pytest
from reference_data_files import (
    COUNTRIES,
    STYLES,
    country_rows,
    has_draft_guard,
    read,
    rollback_safe_body,
    style_rows,
    without_draft_guard,
)

from .disposable_db import connection_kwargs, run_rolled_back

pytestmark = pytest.mark.integration


async def _count(conn: asyncpg.Connection, table: str) -> int:
    return await conn.fetchval(f"select count(*) from public.{table}")


async def _apply_again(conn: asyncpg.Connection, sql: str, temp_table: str) -> None:
    # The scripts create a temp table `on commit drop`; inside one long test
    # transaction a second run needs the first run's table gone.
    await conn.execute(f"drop table if exists {temp_table}")
    await conn.execute(sql)


def test_countries_apply_idempotently_and_coexist_with_existing_rows(integration_dsn):
    sql = rollback_safe_body(read(COUNTRIES))
    expected = country_rows(read(COUNTRIES))

    async def body(conn: asyncpg.Connection) -> None:
        # Rows the dev seed already holds: same iso_code, a different name and continent.
        await conn.execute(
            "insert into public.countries (iso_code, name, continent) values "
            "('IE', 'Eire (old)', 'Asia'), ('US', 'USA', 'Europe')"
        )

        await conn.execute(sql)

        assert await _count(conn, "countries") == 249  # no duplicates, dev rows updated in place
        rows = await conn.fetch("select iso_code, name, continent from public.countries")
        assert {(r["iso_code"], r["name"], r["continent"]) for r in rows} == set(expected)

        await _apply_again(conn, sql, "_ref_countries")  # idempotent
        assert await _count(conn, "countries") == 249

    run_rolled_back(integration_dsn, body)


def test_countries_second_run_changes_nothing(integration_dsn):
    sql = rollback_safe_body(read(COUNTRIES))

    async def body(conn: asyncpg.Connection) -> None:
        await conn.execute(sql)
        # `ctid` is the physical row version: an UPDATE writes a new one, so it exposes a
        # rewrite that `now()`-based columns cannot (now() is fixed within a transaction).
        first = await conn.fetch("select iso_code, ctid::text as ctid from public.countries")
        await _apply_again(conn, sql, "_ref_countries")
        second = await conn.fetch("select iso_code, ctid::text as ctid from public.countries")
        # The `where ... is distinct from` clause skips unchanged rows entirely.
        assert {(r["iso_code"], r["ctid"]) for r in first} == {
            (r["iso_code"], r["ctid"]) for r in second
        }

    run_rolled_back(integration_dsn, body)


def test_the_draft_guard_stops_the_files_as_shipped(integration_dsn):
    async def body(conn: asyncpg.Connection) -> None:
        for path in (COUNTRIES, STYLES):
            sql = read(path)
            if not has_draft_guard(sql):
                continue  # the owner reviewed the file and removed the guard
            await conn.execute("savepoint before_guard")
            with pytest.raises(asyncpg.RaiseError, match="DRAFT|draft"):
                await conn.execute(sql)
            await conn.execute("rollback to savepoint before_guard")
            assert await _count(conn, "countries") == 0
            assert await _count(conn, "beer_styles") == 0

    run_rolled_back(integration_dsn, body)


def test_beer_styles_need_the_countries_first(integration_dsn):
    styles_sql = rollback_safe_body(read(STYLES))

    async def body(conn: asyncpg.Connection) -> None:
        with pytest.raises(asyncpg.RaiseError, match="apply countries.sql first"):
            await conn.execute(styles_sql)

    run_rolled_back(integration_dsn, body)


def test_beer_styles_apply_idempotently_and_never_overwrite_descriptions(integration_dsn):
    countries_sql = rollback_safe_body(read(COUNTRIES))
    styles_sql = rollback_safe_body(read(STYLES))
    expected = style_rows(read(STYLES))

    async def body(conn: asyncpg.Connection) -> None:
        await conn.execute(countries_sql)
        # A style already present under a different case, with an owner-written description.
        await conn.execute(
            "insert into public.beer_styles (name, category, description) "
            "values ('pilsner', 'Old category', 'Owner-written description')"
        )

        await conn.execute(styles_sql)

        assert await _count(conn, "beer_styles") == len(expected)
        rows = await conn.fetch(
            "select s.name, s.category, s.description, c.iso_code as origin, "
            "s.typical_abv_min::float as lo, s.typical_abv_max::float as hi "
            "from public.beer_styles s left join public.countries c on c.id = s.origin_country_id"
        )
        by_name = {r["name"].lower(): r for r in rows}
        assert {n.lower() for n, *_ in expected} == set(by_name)
        for name, category, origin, lo, hi in expected:
            row = by_name[name.lower()]
            assert (row["category"], row["origin"], row["lo"], row["hi"]) == (
                category,
                origin,
                lo,
                hi,
            )
        # The pre-existing row keeps its own spelling and its description.
        assert by_name["pilsner"]["name"] == "pilsner"
        assert by_name["pilsner"]["description"] == "Owner-written description"
        # Every other style has no description: none is written by the file.
        assert all(r["description"] is None for n, r in by_name.items() if n != "pilsner")

        await _apply_again(conn, styles_sql, "_ref_beer_styles")
        assert await _count(conn, "beer_styles") == len(expected)

    run_rolled_back(integration_dsn, body)


def test_the_transaction_wrapper_commits_and_drops_its_temp_tables(integration_dsn):
    """Runs the files with their real `begin; ... commit;` (guard removed) on a separate
    connection, then removes exactly the rows it created. Requires an empty starting state,
    which the rest of this suite preserves.
    """
    countries_sql = without_draft_guard(read(COUNTRIES))
    styles_sql = without_draft_guard(read(STYLES))

    async def main() -> None:
        conn = await asyncpg.connect(**connection_kwargs(integration_dsn))
        try:
            assert await _count(conn, "countries") == 0, "disposable database must start empty"
            assert await _count(conn, "beer_styles") == 0, "disposable database must start empty"
            try:
                await conn.execute(countries_sql)
                await conn.execute(styles_sql)

                assert await _count(conn, "countries") == 249
                assert await _count(conn, "beer_styles") == len(style_rows(read(STYLES)))
                # `on commit drop`: nothing is left behind on the connection.
                leftovers = await conn.fetchval(
                    "select count(*) from pg_class where relname in "
                    "('_ref_countries', '_ref_beer_styles') and relpersistence = 't'"
                )
                assert leftovers == 0
            finally:
                await conn.execute("delete from public.beer_styles")
                await conn.execute("delete from public.countries")
        finally:
            await conn.close()

    asyncio.run(main())
