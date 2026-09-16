import asyncpg

from app.repositories.scoped_connection import scoped_connection
from app.repositories.search import escape_like_term

# Server-side safety backstop, not real pagination -- see CappedList's
# doc comment and docs/DECISIONS.md. Viewport/bounding-box querying is the
# actual future scale solution (Phase 14), not this cap.
MAP_BEERS_CAP = 2000
MAP_BREWERIES_CAP = 2000

# A beer's marker uses its own coordinate PAIR if both fields are set,
# otherwise its brewery's PAIR if both are set, otherwise no marker at all.
# Each CASE independently re-checks both columns of whichever source it
# reads from, so latitude and longitude always come from the same row --
# this can never combine one table's latitude with the other's longitude,
# regardless of what each table's own `..._lat_lng_paired` CHECK constraint
# already guarantees at that table's row level.
_BEER_LATITUDE = (
    "case when b.latitude is not null and b.longitude is not null then b.latitude "
    "when br.latitude is not null and br.longitude is not null then br.latitude "
    "else null end"
)
_BEER_LONGITUDE = (
    "case when b.latitude is not null and b.longitude is not null then b.longitude "
    "when br.latitude is not null and br.longitude is not null then br.longitude "
    "else null end"
)

_MAP_BEER_FROM_JOIN = (
    "from public.beers b "
    "join public.breweries br on br.id = b.brewery_id "
    "left join public.countries co on co.id = coalesce(b.country_id, br.country_id) "
    "left join public.user_beer_collection c on c.user_id = $1 and c.beer_id = b.id"
)

_MAP_BEER_COLUMNS = (
    "b.id as beer_id, b.official_name, br.name as brewery_name, "
    f"{_BEER_LATITUDE} as latitude, {_BEER_LONGITUDE} as longitude, "
    "co.name as country_name, coalesce(b.region, br.region) as region, "
    "exists (select 1 from public.user_beer_logs ul "
    "where ul.beer_id = b.id and ul.user_id = $1) as is_tried, "
    "coalesce(c.is_favorite, false) as is_favorite, "
    "coalesce(c.is_wishlist, false) as is_wishlist"
)

_STATE_CONDITIONS = {
    "all": None,
    "tried": (
        "exists (select 1 from public.user_beer_logs ul "
        "where ul.beer_id = b.id and ul.user_id = $1)"
    ),
    "not_tried": (
        "not exists (select 1 from public.user_beer_logs ul "
        "where ul.beer_id = b.id and ul.user_id = $1)"
    ),
    "favorites": "coalesce(c.is_favorite, false)",
    "wishlist": "coalesce(c.is_wishlist, false)",
}


class MapRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    def _scoped(self, user_id: str):
        return scoped_connection(self._pool, user_id)

    async def list_beers(
        self,
        *,
        user_id: str,
        state: str,
        country_id: str | None,
        q: str | None,
    ) -> tuple[list[asyncpg.Record], bool]:
        """Reads public.user_beer_logs/public.user_beer_collection, both RLS
        -protected on the transaction-local app.user_id pattern -- must run
        inside `scoped_connection` so `set_config('app.user_id', ...)` is
        active, exactly like CollectionRepository/BeerLogRepository. The
        explicit `... = $1` predicates below are kept too, as
        defense-in-depth on top of RLS, not a replacement for it.
        """
        params: list = [user_id]
        conditions: list[str] = [f"{_BEER_LATITUDE} is not null"]

        if country_id is not None:
            params.append(country_id)
            conditions.append(f"coalesce(b.country_id, br.country_id) = ${len(params)}")

        if q is not None:
            params.append(f"%{escape_like_term(q)}%")
            pattern_param = f"${len(params)}"
            conditions.append(
                f"(coalesce(b.region, br.region) ilike {pattern_param} escape '\\' "
                f"or br.name ilike {pattern_param} escape '\\' "
                f"or co.name ilike {pattern_param} escape '\\')"
            )

        state_condition = _STATE_CONDITIONS[state]
        if state_condition is not None:
            conditions.append(state_condition)

        where_clause = f"where {' and '.join(conditions)}"
        query = (
            f"select {_MAP_BEER_COLUMNS} {_MAP_BEER_FROM_JOIN} {where_clause} "
            f"order by b.official_name limit {MAP_BEERS_CAP + 1}"
        )
        async with self._scoped(user_id) as conn:
            rows = await conn.fetch(query, *params)
        truncated = len(rows) > MAP_BEERS_CAP
        return rows[:MAP_BEERS_CAP], truncated

    async def list_breweries(
        self, *, country_id: str | None, q: str | None
    ) -> tuple[list[asyncpg.Record], bool]:
        """Reads only catalog tables (breweries/countries) -- no
        scoped_connection needed, no RLS-protected table involved."""
        params: list = []
        conditions: list[str] = ["br.latitude is not null and br.longitude is not null"]

        if country_id is not None:
            params.append(country_id)
            conditions.append(f"br.country_id = ${len(params)}")

        if q is not None:
            params.append(f"%{escape_like_term(q)}%")
            pattern_param = f"${len(params)}"
            conditions.append(
                f"(br.region ilike {pattern_param} escape '\\' "
                f"or br.name ilike {pattern_param} escape '\\' "
                f"or co.name ilike {pattern_param} escape '\\')"
            )

        where_clause = f"where {' and '.join(conditions)}"
        query = (
            "select br.id as brewery_id, br.name, br.latitude, br.longitude, "
            "co.name as country_name, br.city, br.region, br.description, "
            "br.website, br.verified "
            "from public.breweries br "
            "left join public.countries co on co.id = br.country_id "
            f"{where_clause} "
            f"order by br.name limit {MAP_BREWERIES_CAP + 1}"
        )
        async with self._pool.acquire() as conn:
            rows = await conn.fetch(query, *params)
        truncated = len(rows) > MAP_BREWERIES_CAP
        return rows[:MAP_BREWERIES_CAP], truncated
