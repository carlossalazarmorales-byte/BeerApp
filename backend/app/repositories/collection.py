import asyncpg

from app.repositories.scoped_connection import scoped_connection

# "Latest log per beer" in one pass -- DISTINCT ON (beer_id), ordered by the
# same (consumed_at desc, id desc) tie-breaker discipline user_beer_logs
# already indexes on. Counted unfiltered, this *is* "unique beers tried"
# (see docs/DECISIONS.md) -- there is deliberately no separate has_logged
# boolean or stored count anywhere.
_LATEST_LOGS_CTE = (
    "with latest_logs as ("
    "select distinct on (beer_id) beer_id, rating, consumed_at "
    "from public.user_beer_logs where user_id = $1 "
    "order by beer_id, consumed_at desc, id desc"
    ") "
)

_CATALOG_JOIN = (
    "left join public.breweries br on br.id = b.brewery_id "
    "left join public.beer_styles st on st.id = b.style_id "
    "left join public.countries co on co.id = b.country_id"
)

# Every list response embeds the names a Collection tile actually displays
# -- brewery/style/country -- via this same join, so there is never a
# per-item follow-up request. Mirrors BeerRepository's own LIKE-search join,
# just always applied here rather than only when searching.
_BEER_COLUMNS = (
    "b.id as beer_id, b.official_name, b.image_url, b.abv, "
    "br.name as brewery_name, st.name as style_name, co.name as country_name"
)


def _filter_conditions(
    params: list, *, country_id: str | None, style_id: str | None, brewery_id: str | None
) -> list[str]:
    """Shared filter-condition builder, reused by every tab's count and page
    query so `total` can never drift from the page built from the same
    clause -- same drift-proofing pattern as BeerRepository._build_query.
    """
    conditions: list[str] = []
    if country_id is not None:
        params.append(country_id)
        conditions.append(f"b.country_id = ${len(params)}")
    if style_id is not None:
        params.append(style_id)
        conditions.append(f"b.style_id = ${len(params)}")
    if brewery_id is not None:
        params.append(brewery_id)
        conditions.append(f"b.brewery_id = ${len(params)}")
    return conditions


def _order_by(*, sort: str, recent_column: str) -> str:
    # `beer_id` (the select-list alias `b.id as beer_id`) is always the
    # final deterministic tie-breaker, visible in ORDER BY of the same
    # top-level SELECT it's aliased in.
    if sort == "rating":
        return f"ll.rating desc nulls last, {recent_column} desc, beer_id"
    if sort == "name":
        return "lower(b.official_name) asc, beer_id"
    return f"{recent_column} desc, beer_id"


class CollectionRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    def _scoped(self, user_id: str):
        return scoped_connection(self._pool, user_id)

    async def _fetch_page(
        self,
        *,
        user_id: str,
        from_join: str,
        where_clause: str,
        params: list,
        order_by: str,
        select_columns: str,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        offset = (page - 1) * page_size
        count_query = f"{_LATEST_LOGS_CTE}select count(*) {from_join} {where_clause}"
        list_query = (
            f"{_LATEST_LOGS_CTE}select {select_columns} {from_join} {where_clause} "
            f"order by {order_by} limit ${len(params) + 1} offset ${len(params) + 2}"
        )
        async with self._scoped(user_id) as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *params, page_size, offset)
        return rows, total

    async def list_logged(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        params: list = [user_id]
        conditions = _filter_conditions(
            params, country_id=country_id, style_id=style_id, brewery_id=brewery_id
        )
        where_clause = f"where {' and '.join(conditions)}" if conditions else ""
        from_join = (
            "from latest_logs ll "
            "join public.beers b on b.id = ll.beer_id "
            f"{_CATALOG_JOIN} "
            "left join public.user_beer_collection c on c.user_id = $1 and c.beer_id = ll.beer_id"
        )
        select_columns = (
            f"{_BEER_COLUMNS}, ll.rating as latest_rating, ll.consumed_at as latest_consumed_at, "
            "coalesce(c.is_favorite, false) as is_favorite, "
            "coalesce(c.is_wishlist, false) as is_wishlist"
        )
        order_by = _order_by(sort=sort, recent_column="ll.consumed_at")
        return await self._fetch_page(
            user_id=user_id,
            from_join=from_join,
            where_clause=where_clause,
            params=params,
            order_by=order_by,
            select_columns=select_columns,
            page=page,
            page_size=page_size,
        )

    async def _list_by_flag(
        self,
        *,
        user_id: str,
        flag_column: str,
        recent_column: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        params: list = [user_id]
        conditions = [flag_column]
        conditions += _filter_conditions(
            params, country_id=country_id, style_id=style_id, brewery_id=brewery_id
        )
        where_clause = f"where c.user_id = $1 and {' and '.join(conditions)}"
        from_join = (
            "from public.user_beer_collection c "
            "join public.beers b on b.id = c.beer_id "
            f"{_CATALOG_JOIN} "
            "left join latest_logs ll on ll.beer_id = c.beer_id"
        )
        select_columns = (
            f"{_BEER_COLUMNS}, ll.rating as latest_rating, ll.consumed_at as latest_consumed_at, "
            "c.is_favorite, c.is_wishlist"
        )
        order_by = _order_by(sort=sort, recent_column=recent_column)
        return await self._fetch_page(
            user_id=user_id,
            from_join=from_join,
            where_clause=where_clause,
            params=params,
            order_by=order_by,
            select_columns=select_columns,
            page=page,
            page_size=page_size,
        )

    async def list_favorites(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        return await self._list_by_flag(
            user_id=user_id,
            flag_column="c.is_favorite",
            recent_column="c.favorited_at",
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            sort=sort,
            page=page,
            page_size=page_size,
        )

    async def list_wishlist(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> tuple[list[asyncpg.Record], int]:
        return await self._list_by_flag(
            user_id=user_id,
            flag_column="c.is_wishlist",
            recent_column="c.wishlisted_at",
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            sort=sort,
            page=page,
            page_size=page_size,
        )

    async def get_state(self, *, user_id: str, beer_id: str) -> asyncpg.Record | None:
        # LEFT JOIN from beers (the driving table), not user_beer_collection
        # -- zero rows means beer_id isn't a real catalog beer (404 at the
        # service layer); one row with c.* NULL means it exists with no
        # collection row yet (200, both flags false). user_id is a join
        # parameter sourced only from the verified JWT, never client input.
        query = (
            "select b.id as beer_id, coalesce(c.is_favorite, false) as is_favorite, "
            "coalesce(c.is_wishlist, false) as is_wishlist "
            "from public.beers b "
            "left join public.user_beer_collection c on c.user_id = $1 and c.beer_id = b.id "
            "where b.id = $2"
        )
        async with self._scoped(user_id) as conn:
            return await conn.fetchrow(query, user_id, beer_id)

    async def set_state(
        self, *, user_id: str, beer_id: str, is_favorite: bool | None, is_wishlist: bool | None
    ) -> dict:
        # Atomic, race-safe merge -- see docs/DECISIONS.md for the full
        # derivation and the four concurrency scenarios this was verified
        # against. $3/$4 (is_favorite/is_wishlist) are NULL when the PATCH
        # omitted that field, meaning "preserve current" -- coalesce(...)
        # against the *unqualified table name* reads the live row's current
        # value at the moment of this locked write, which is what makes two
        # concurrent PATCHes on the same row merge correctly instead of one
        # clobbering the other's field. There is deliberately no
        # `CHECK (is_favorite OR is_wishlist)` to violate here (see the
        # migration) -- this statement always succeeds and returns the
        # actual resulting row via RETURNING, including a transient
        # both-false row if that's what the merge produced. The DELETE
        # below, when needed, runs immediately after inside the *same*
        # transaction: the row lock this upsert just took is never
        # released, so no concurrent transaction can observe or touch this
        # row between the upsert and the delete -- a both-false state is
        # therefore never visible outside this transaction, and never
        # committed.
        query = (
            "insert into public.user_beer_collection "
            "(user_id, beer_id, is_favorite, is_wishlist, favorited_at, wishlisted_at) "
            "values ("
            "$1, $2, "
            "coalesce($3, false), coalesce($4, false), "
            "case when coalesce($3, false) then now() else null end, "
            "case when coalesce($4, false) then now() else null end"
            ") "
            "on conflict (user_id, beer_id) do update set "
            "is_favorite = coalesce($3, user_beer_collection.is_favorite), "
            "is_wishlist = coalesce($4, user_beer_collection.is_wishlist), "
            "favorited_at = case "
            "when coalesce($3, user_beer_collection.is_favorite) "
            "and not user_beer_collection.is_favorite then now() "
            "when not coalesce($3, user_beer_collection.is_favorite) then null "
            "else user_beer_collection.favorited_at "
            "end, "
            "wishlisted_at = case "
            "when coalesce($4, user_beer_collection.is_wishlist) "
            "and not user_beer_collection.is_wishlist then now() "
            "when not coalesce($4, user_beer_collection.is_wishlist) then null "
            "else user_beer_collection.wishlisted_at "
            "end, "
            "updated_at = now() "
            "returning id, user_id, beer_id, is_favorite, is_wishlist, "
            "favorited_at, wishlisted_at, created_at, updated_at"
        )
        async with self._scoped(user_id) as conn:
            record = await conn.fetchrow(query, user_id, beer_id, is_favorite, is_wishlist)
            result = dict(record)
            if not result["is_favorite"] and not result["is_wishlist"]:
                await conn.execute(
                    "delete from public.user_beer_collection where user_id = $1 and beer_id = $2",
                    user_id,
                    beer_id,
                )
                return {"beer_id": beer_id, "is_favorite": False, "is_wishlist": False}
            return result
