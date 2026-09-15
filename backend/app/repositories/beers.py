import asyncpg

_COLUMNS = (
    "id, official_name, brewery_id, style_id, country_id, region, city, "
    "latitude, longitude, abv, ibu, description, image_url, barcode, "
    "verified, source, created_at, updated_at"
)


class BeerRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def list_paginated(
        self,
        *,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        offset = (page - 1) * page_size
        params: list = []
        conditions: list[str] = []

        if country_id is not None:
            params.append(country_id)
            conditions.append(f"country_id = ${len(params)}")
        if style_id is not None:
            params.append(style_id)
            conditions.append(f"style_id = ${len(params)}")
        if brewery_id is not None:
            params.append(brewery_id)
            conditions.append(f"brewery_id = ${len(params)}")

        where_clause = f"where {' and '.join(conditions)}" if conditions else ""

        count_query = f"select count(*) from public.beers {where_clause}"
        list_query = (
            f"select {_COLUMNS} from public.beers {where_clause} "
            f"order by official_name limit ${len(params) + 1} offset ${len(params) + 2}"
        )

        async with self._pool.acquire() as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *params, page_size, offset)

        return rows, total

    async def get_by_id(self, beer_id: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.beers where id = $1"
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(query, beer_id)
