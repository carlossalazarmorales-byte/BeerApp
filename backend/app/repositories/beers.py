import asyncpg

from app.repositories.search import escape_like_term

_COLUMNS = (
    "b.id, b.official_name, b.brewery_id, b.style_id, b.country_id, b.region, "
    "b.city, b.latitude, b.longitude, b.abv, b.ibu, b.description, "
    "b.image_url, b.barcode, b.verified, b.source, b.created_at, b.updated_at"
)


class BeerRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    def _build_query(
        self,
        *,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        q: str | None,
    ) -> tuple[str, list]:
        """Builds the shared FROM/JOIN/WHERE clause and its parameters once,
        so the count query and the page query can never drift apart --
        `total` must always describe the exact same filtered/searched row
        set as the page of results built from the same clause.
        """
        params: list = []
        conditions: list[str] = []
        joins = ""

        if country_id is not None:
            params.append(country_id)
            conditions.append(f"b.country_id = ${len(params)}")
        if style_id is not None:
            params.append(style_id)
            conditions.append(f"b.style_id = ${len(params)}")
        if brewery_id is not None:
            params.append(brewery_id)
            conditions.append(f"b.brewery_id = ${len(params)}")

        if q is not None:
            joins = (
                "left join public.breweries br on br.id = b.brewery_id "
                "left join public.beer_styles st on st.id = b.style_id "
                "left join public.countries co on co.id = b.country_id"
            )
            params.append(f"%{escape_like_term(q)}%")
            pattern_param = f"${len(params)}"
            conditions.append(
                f"(b.official_name ilike {pattern_param} escape '\\' "
                f"or br.name ilike {pattern_param} escape '\\' "
                f"or st.name ilike {pattern_param} escape '\\' "
                f"or co.name ilike {pattern_param} escape '\\')"
            )

        where_clause = f"where {' and '.join(conditions)}" if conditions else ""
        clause_parts = ("from public.beers b", joins, where_clause)
        from_clause = " ".join(part for part in clause_parts if part)
        return from_clause, params

    async def list_paginated(
        self,
        *,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        q: str | None = None,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        offset = (page - 1) * page_size
        from_clause, params = self._build_query(
            country_id=country_id, style_id=style_id, brewery_id=brewery_id, q=q
        )

        count_query = f"select count(*) {from_clause}"
        list_query = (
            f"select {_COLUMNS} {from_clause} "
            f"order by b.official_name limit ${len(params) + 1} offset ${len(params) + 2}"
        )

        async with self._pool.acquire() as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *params, page_size, offset)

        return rows, total

    async def get_by_id(self, beer_id: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.beers b where b.id = $1"
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(query, beer_id)
