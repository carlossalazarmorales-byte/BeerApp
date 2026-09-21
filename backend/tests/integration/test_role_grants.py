"""The `beerapp_backend` role's core privilege boundary, probed in the DISPOSABLE
database (migrations applied there) by connecting as its admin and `SET ROLE`.

These used to connect through DATABASE_URL -- the real dev project's
credential. They must not: no integration test may touch a shared database.
The complete per-table/per-role audit is in test_security_audit.py.
"""

import asyncio

import asyncpg
import pytest

from .disposable_db import connection_kwargs

pytestmark = pytest.mark.integration


async def _connect_as_backend(dsn: str) -> asyncpg.Connection:
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    await conn.execute("set role beerapp_backend")
    return conn


def test_beerapp_backend_can_select_countries(integration_dsn):
    async def body() -> None:
        conn = await _connect_as_backend(integration_dsn)
        try:
            # Must not raise -- this is the whole point of the role.
            await conn.fetch("select id from public.countries limit 1")
        finally:
            await conn.close()

    asyncio.run(body())


def test_beerapp_backend_cannot_insert_countries(integration_dsn):
    async def body() -> None:
        conn = await _connect_as_backend(integration_dsn)
        try:
            with pytest.raises(asyncpg.InsufficientPrivilegeError):
                await conn.execute(
                    "insert into public.countries (iso_code, name, continent) "
                    "values ('ZZ', 'Should Fail', 'Europe')"
                )
        finally:
            await conn.close()

    asyncio.run(body())


async def _table_privileges(dsn: str, table: str, role: str = "beerapp_backend") -> set[str]:
    conn = await asyncpg.connect(**connection_kwargs(dsn))
    try:
        rows = await conn.fetch(
            "select privilege_type from information_schema.role_table_grants "
            "where table_schema = 'public' and table_name = $1 and grantee = $2",
            table,
            role,
        )
        return {row["privilege_type"] for row in rows}
    finally:
        await conn.close()


def test_beerapp_backend_has_full_grants_on_user_beer_logs(integration_dsn):
    """Table-privilege check only, independent of RLS row visibility -- Phase 6
    is the first write endpoint, so unlike the catalog tables above,
    beerapp_backend needs SELECT/INSERT/UPDATE/DELETE here, scoped to this one
    table. The row-level behavior those grants combine with (the
    transaction-scoped app.user_id RLS policy) is exercised in
    test_user_beer_logs_rls.py -- this test only confirms the grants exist.
    """
    privileges = asyncio.run(_table_privileges(integration_dsn, "user_beer_logs"))

    assert privileges == {"SELECT", "INSERT", "UPDATE", "DELETE"}


def test_beerapp_backend_has_full_grants_on_user_beer_collection(integration_dsn):
    """Phase 7's second user-owned write table, on the exact same grant shape
    as user_beer_logs -- see test_user_beer_collection_rls.py for the row-level
    behavior.
    """
    privileges = asyncio.run(_table_privileges(integration_dsn, "user_beer_collection"))

    assert privileges == {"SELECT", "INSERT", "UPDATE", "DELETE"}
