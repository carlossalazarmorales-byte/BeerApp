import asyncpg

_COLUMNS = (
    "id, name, category, description, origin_country_id, "
    "typical_abv_min, typical_abv_max, created_at, updated_at"
)


class BeerStyleRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def list_all(self) -> list[asyncpg.Record]:
        query = f"select {_COLUMNS} from public.beer_styles order by name"
        async with self._pool.acquire() as conn:
            return await conn.fetch(query)
