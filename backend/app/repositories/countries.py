import asyncpg

_COLUMNS = "id, iso_code, name, continent, created_at, updated_at"


class CountryRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def list_all(self) -> list[asyncpg.Record]:
        query = f"select {_COLUMNS} from public.countries order by name"
        async with self._pool.acquire() as conn:
            return await conn.fetch(query)
