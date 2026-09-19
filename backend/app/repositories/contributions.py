from decimal import Decimal

import asyncpg

from app.repositories.scoped_connection import scoped_connection

_BEER_COLUMNS = (
    "id, official_name, brewery_id, proposed_brewery_name, style_id, "
    "proposed_style_name, abv, barcode, status, created_at"
)
_BREWERY_COLUMNS = "id, name, country_id, proposed_country_name, region, city, status, created_at"


class ContributionRepository:
    """User-owned proposals for catalog growth (Phase 13). Every method runs
    inside `scoped_connection`, so the owner-only RLS policies apply, and
    still filters `where user_id = $N` explicitly -- RLS is a backstop, not a
    replacement for careful queries.

    Deliberately has NO method that writes public.beers, public.breweries,
    public.beer_styles or public.countries: a contribution is a proposal, not
    a catalog row, and `beerapp_backend` holds no privilege to write them
    anyway. There are also no update/delete methods -- submissions are
    immutable this phase and the role has no such grant.
    """

    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def create_beer(
        self,
        *,
        user_id: str,
        official_name: str,
        brewery_id: str | None,
        proposed_brewery_name: str | None,
        style_id: str | None,
        proposed_style_name: str | None,
        abv: Decimal | None,
        barcode: str | None,
    ) -> asyncpg.Record:
        query = (
            "insert into public.beer_contributions "
            "(user_id, official_name, brewery_id, proposed_brewery_name, style_id, "
            "proposed_style_name, abv, barcode) "
            "values ($1, $2, $3, $4, $5, $6, $7, $8) "
            f"returning {_BEER_COLUMNS}"
        )
        async with scoped_connection(self._pool, user_id) as conn:
            return await conn.fetchrow(
                query,
                user_id,
                official_name,
                brewery_id,
                proposed_brewery_name,
                style_id,
                proposed_style_name,
                abv,
                barcode,
            )

    async def create_brewery(
        self,
        *,
        user_id: str,
        name: str,
        country_id: str | None,
        proposed_country_name: str | None,
        region: str | None,
        city: str | None,
    ) -> asyncpg.Record:
        query = (
            "insert into public.brewery_contributions "
            "(user_id, name, country_id, proposed_country_name, region, city) "
            "values ($1, $2, $3, $4, $5, $6) "
            f"returning {_BREWERY_COLUMNS}"
        )
        async with scoped_connection(self._pool, user_id) as conn:
            return await conn.fetchrow(
                query, user_id, name, country_id, proposed_country_name, region, city
            )

    async def list_history(
        self, *, user_id: str, page: int, page_size: int
    ) -> tuple[list[asyncpg.Record], int]:
        # Both kinds in one newest-first list. `id desc` is the stable
        # tie-breaker so pagination stays deterministic when two suggestions
        # share a created_at.
        union = (
            "select 'beer'::text as kind, id, official_name as title, status, created_at "
            "from public.beer_contributions where user_id = $1 "
            "union all "
            "select 'brewery'::text, id, name, status, created_at "
            "from public.brewery_contributions where user_id = $1"
        )
        count_query = (
            "select (select count(*) from public.beer_contributions where user_id = $1) "
            "+ (select count(*) from public.brewery_contributions where user_id = $1)"
        )
        list_query = (
            f"select kind, id, title, status, created_at from ({union}) c "
            "order by created_at desc, id desc limit $2 offset $3"
        )
        offset = (page - 1) * page_size
        async with scoped_connection(self._pool, user_id) as conn:
            total = await conn.fetchval(count_query, user_id)
            rows = await conn.fetch(list_query, user_id, page_size, offset)
        return rows, total

    async def has_own_pending_beer(
        self,
        *,
        user_id: str,
        official_name: str,
        brewery_id: str | None,
        proposed_brewery_name: str | None,
    ) -> bool:
        """The caller's own equivalent pending suggestion -- the same key the
        `beer_contributions_own_pending_*_uidx` unique indexes enforce.
        """
        if brewery_id is not None:
            brewery_condition = "brewery_id = $3"
            brewery_param: str = brewery_id
        else:
            brewery_condition = "lower(btrim(proposed_brewery_name)) = lower($3)"
            brewery_param = proposed_brewery_name or ""
        query = (
            "select exists (select 1 from public.beer_contributions "
            "where user_id = $1 and status = 'pending' "
            f"and lower(btrim(official_name)) = lower($2) and {brewery_condition})"
        )
        async with scoped_connection(self._pool, user_id) as conn:
            return await conn.fetchval(query, user_id, official_name, brewery_param)

    async def has_own_pending_brewery(
        self,
        *,
        user_id: str,
        name: str,
        country_id: str | None,
        proposed_country_name: str | None,
    ) -> bool:
        if country_id is not None:
            country_condition = "country_id = $3"
            country_param: str = country_id
        else:
            country_condition = "lower(btrim(proposed_country_name)) = lower($3)"
            country_param = proposed_country_name or ""
        query = (
            "select exists (select 1 from public.brewery_contributions "
            "where user_id = $1 and status = 'pending' "
            f"and lower(btrim(name)) = lower($2) and {country_condition})"
        )
        async with scoped_connection(self._pool, user_id) as conn:
            return await conn.fetchval(query, user_id, name, country_param)

    async def other_user_pending_barcode_exists(self, *, user_id: str, barcode: str) -> bool:
        """Does ANOTHER user have a pending suggestion carrying this canonical
        barcode? Answered by a boolean-only SECURITY DEFINER function -- the
        RLS policy on beer_contributions stays owner-only, so this method
        cannot (and must not) be extended to return any other user's row.
        The caller's identity comes from the scoped connection's app.user_id.
        """
        async with scoped_connection(self._pool, user_id) as conn:
            return await conn.fetchval(
                "select private.other_user_pending_beer_barcode_exists($1)", barcode
            )
