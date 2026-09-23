import asyncpg

from app.repositories.scoped_connection import scoped_connection
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
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        q: str | None,
        untried_only: bool,
    ) -> tuple[str, list]:
        """Builds the shared FROM/JOIN/WHERE clause and its parameters once,
        so the count query and the page query can never drift apart --
        `total` must always describe the exact same filtered/searched row
        set as the page of results built from the same clause.

        Every bound parameter here is guaranteed to actually appear in the
        returned clause text: Postgres cannot infer a type for a $N that is
        bound but never referenced (`IndeterminateDatatypeError`), which is
        exactly what an unconditional "user_id is always $1" would produce
        for the *count* query whenever untried_only is false and no other
        filter happens to reference it. `user_id` is therefore only added to
        `params` when `untried_only` actually needs it here; the list
        query's separate `is_tried` column binds its own trailing copy in
        `list_paginated` instead of relying on this one.
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

        if untried_only:
            params.append(user_id)
            conditions.append(
                "not exists (select 1 from public.user_beer_logs ul "
                f"where ul.beer_id = b.id and ul.user_id = ${len(params)})"
            )

        where_clause = f"where {' and '.join(conditions)}" if conditions else ""
        clause_parts = ("from public.beers b", joins, where_clause)
        from_clause = " ".join(part for part in clause_parts if part)
        return from_clause, params

    async def list_paginated(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        q: str | None = None,
        untried_only: bool = False,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        """Discover (untried_only=True, no user-facing toggle) and Add Beer
        (untried_only=False, the full catalog -- a user may log a beer
        again) share this one query builder; only the flag differs. Reads
        public.user_beer_logs (for is_tried/untried_only) via
        `scoped_connection` for its RLS-required `app.user_id` -- see
        docs/DATABASE.md's user_beer_logs RLS section and
        MapRepository/CollectionRepository's identical use of it.
        """
        offset = (page - 1) * page_size
        from_clause, params = self._build_query(
            user_id=user_id,
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            q=q,
            untried_only=untried_only,
        )

        count_query = f"select count(*) {from_clause}"

        # is_tried is list-only (a count has no per-row column to attach it
        # to), so its user_id binding is its own trailing parameter here --
        # never folded into `params` above, which only the count/filter
        # WHERE clause (shared by both queries) uses.
        list_params = [*params, user_id]
        is_tried_param = f"${len(list_params)}"
        list_columns = (
            f"{_COLUMNS}, exists (select 1 from public.user_beer_logs ul "
            f"where ul.beer_id = b.id and ul.user_id = {is_tried_param}) as is_tried"
        )
        list_query = (
            f"select {list_columns} {from_clause} "
            f"order by b.official_name limit ${len(list_params) + 1} "
            f"offset ${len(list_params) + 2}"
        )

        async with scoped_connection(self._pool, user_id) as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *list_params, page_size, offset)

        return rows, total

    async def get_by_id(self, beer_id: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.beers b where b.id = $1"
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(query, beer_id)

    async def get_by_barcode(self, barcode: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.beers b where b.barcode = $1"
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(query, barcode)

    async def find_by_name_and_brewery(
        self,
        *,
        name: str,
        brewery_id: str | None,
        brewery_name: str | None,
        limit: int,
    ) -> list[asyncpg.Record]:
        """Duplicate-candidate lookup for Phase 13: catalog beers whose name
        equals `name` case-insensitively (an equality on `lower(official_name)`,
        served by beers_official_name_idx) AND whose brewery is either the
        given canonical brewery or any brewery named `brewery_name`.
        A name alone is never enough -- "Pilsner" alone would match half the
        catalog. Exactly one of `brewery_id`/`brewery_name` is expected; the
        caller (ContributionService) guarantees it.
        """
        if brewery_id is not None:
            brewery_condition = "b.brewery_id = $2"
            brewery_param: str = brewery_id
        else:
            brewery_condition = (
                "b.brewery_id in (select id from public.breweries where lower(name) = lower($2))"
            )
            brewery_param = brewery_name or ""
        query = (
            f"select {_COLUMNS} from public.beers b "
            f"where lower(b.official_name) = lower($1) and {brewery_condition} "
            "order by b.official_name, b.id limit $3"
        )
        async with self._pool.acquire() as conn:
            return await conn.fetch(query, name, brewery_param, limit)
