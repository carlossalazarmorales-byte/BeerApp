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
