import asyncpg

_COLUMNS = (
    "id, name, country_id, region, city, latitude, longitude, "
    "description, website, logo_url, verified, source, created_at, updated_at"
)


class BreweryRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def list_paginated(
        self, *, country_id: str | None, page: int, page_size: int
    ) -> tuple[list[asyncpg.Record], int]:
        offset = (page - 1) * page_size
        params: list = []
        where_clause = ""
        if country_id is not None:
            params.append(country_id)
            where_clause = f"where country_id = ${len(params)}"

        count_query = f"select count(*) from public.breweries {where_clause}"
        list_query = (
            f"select {_COLUMNS} from public.breweries {where_clause} "
            f"order by name limit ${len(params) + 1} offset ${len(params) + 2}"
        )

        async with self._pool.acquire() as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *params, page_size, offset)

        return rows, total

    async def get_by_id(self, brewery_id: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.breweries where id = $1"
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(query, brewery_id)
