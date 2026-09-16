import asyncio

import asyncpg
import pytest

from app.db import parse_dsn_kwargs

pytestmark = pytest.mark.integration


def test_beerapp_backend_can_select_countries(backend_role_dsn):
    async def body() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(backend_role_dsn), ssl="require")
        try:
            # Must not raise -- this is the whole point of the role.
            await conn.fetch("select id from public.countries limit 1")
        finally:
            await conn.close()

    asyncio.run(body())


def test_beerapp_backend_cannot_insert_countries(backend_role_dsn):
    async def body() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(backend_role_dsn), ssl="require")
        try:
            with pytest.raises(asyncpg.InsufficientPrivilegeError):
                await conn.execute(
                    "insert into public.countries (iso_code, name, continent) "
                    "values ('ZZ', 'Should Fail', 'Europe')"
                )
        finally:
            await conn.close()

    asyncio.run(body())


def test_beerapp_backend_has_full_grants_on_user_beer_logs(backend_role_dsn):
    """Table-privilege check only (information_schema), independent of RLS
    row visibility -- Phase 6 is the first write endpoint, so unlike the
    catalog tables above, beerapp_backend needs SELECT/INSERT/UPDATE/DELETE
    here, scoped to this one table (still SELECT-only on the four catalog
    tables). The row-level behavior those grants combine with (the
    transaction-scoped app.user_id RLS policy) is exercised end-to-end in
    tests/integration/test_user_beer_logs_rls.py -- this test only confirms
    the grants themselves exist.
    """

    async def body() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(backend_role_dsn), ssl="require")
        try:
            rows = await conn.fetch(
                "select privilege_type from information_schema.role_table_grants "
                "where table_schema = 'public' and table_name = 'user_beer_logs' "
                "and grantee = 'beerapp_backend'"
            )
            privileges = {row["privilege_type"] for row in rows}
            assert privileges == {"SELECT", "INSERT", "UPDATE", "DELETE"}
        finally:
            await conn.close()

    asyncio.run(body())


def test_beerapp_backend_has_full_grants_on_user_beer_collection(backend_role_dsn):
    """Phase 7's second user-owned write table, on the exact same grant
    shape as user_beer_logs above -- see
    tests/integration/test_user_beer_collection_rls.py for the row-level
    behavior those grants combine with.
    """

    async def body() -> None:
        conn = await asyncpg.connect(**parse_dsn_kwargs(backend_role_dsn), ssl="require")
        try:
            rows = await conn.fetch(
                "select privilege_type from information_schema.role_table_grants "
                "where table_schema = 'public' and table_name = 'user_beer_collection' "
                "and grantee = 'beerapp_backend'"
            )
            privileges = {row["privilege_type"] for row in rows}
            assert privileges == {"SELECT", "INSERT", "UPDATE", "DELETE"}
        finally:
            await conn.close()

    asyncio.run(body())
