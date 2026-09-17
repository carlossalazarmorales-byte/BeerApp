import asyncpg

from app.repositories.scoped_connection import scoped_connection

# A beer's *effective* country: its own country_id if set, else its
# brewery's country_id. Mirrors MapRepository's exact
# `coalesce(b.country_id, br.country_id)` pattern (see docs/DECISIONS.md) --
# countries_discovered/favorite_country must not silently drop a beer whose
# own country field is null while its brewery has a known one.
#
# breweries.country_id is NOT NULL (schema constraint), so this coalesce can
# never itself be null -- unlike style_id, which can be genuinely absent for
# a beer, there is no "neither present" case for country.
#
# Deliberately NOT applied to style/brewery -- those are always exactly
# beer.style_id / beer.brewery_id, never inferred from anything else.
_EFFECTIVE_COUNTRY = "coalesce(b.country_id, br.country_id)"

_OVERVIEW_QUERY = (
    "with logged_beers as ("
    "select distinct l.beer_id, "
    f"{_EFFECTIVE_COUNTRY} as country_id, b.style_id, b.brewery_id "
    "from public.user_beer_logs l "
    "join public.beers b on b.id = l.beer_id "
    "join public.breweries br on br.id = b.brewery_id "
    "where l.user_id = $1"
    ") "
    "select "
    "(select count(*) from public.user_beer_logs where user_id = $1) as total_logs, "
    "(select count(*) from logged_beers) as total_unique_beers, "
    "(select avg(rating) from public.user_beer_logs "
    "where user_id = $1 and rating is not null) as average_rating, "
    # count(distinct col) naturally skips NULLs -- style_id is nullable,
    # country_id (post-coalesce) never is (see _EFFECTIVE_COUNTRY above).
    "(select count(distinct country_id) from logged_beers) as countries_discovered, "
    "(select count(distinct style_id) from logged_beers) as styles_discovered, "
    "(select count(distinct brewery_id) from logged_beers) as breweries_discovered"
)

_AMOUNT_SPENT_QUERY = (
    "select currency, sum(price) as total "
    "from public.user_beer_logs "
    # Both checked explicitly, even though price/currency are always paired
    # by BeerLogCreate/BeerLogUpdate -- a row this query can't attribute to
    # a currency must never be silently folded into any bucket.
    "where user_id = $1 and price is not null and currency is not null "
    "group by currency "
    "order by currency"
)

# Trailing 12 UTC calendar months, zero-filled so the chart always has
# exactly 12 points even for a brand-new user. `AT TIME ZONE 'UTC'` makes the
# bucketing independent of the pooled connection's session `timezone` GUC
# (which callers never control and which the pool may vary across reused
# physical connections).
_MONTHLY_ACTIVITY_QUERY = (
    "with months as ("
    "select generate_series("
    "date_trunc('month', now() at time zone 'utc') - interval '11 months', "
    "date_trunc('month', now() at time zone 'utc'), "
    "interval '1 month'"
    ")::date as month"
    "), monthly_counts as ("
    "select date_trunc('month', consumed_at at time zone 'utc')::date as month, "
    "count(*) as log_count "
    "from public.user_beer_logs where user_id = $1 group by 1"
    ") "
    "select m.month, coalesce(mc.log_count, 0) as log_count "
    "from months m left join monthly_counts mc on mc.month = m.month "
    "order by m.month"
)

# All-time, one row per UTC calendar year with >=1 log -- deliberately NOT
# zero-filled, a different aggregation shape from monthly_activity.
_YEARLY_ACTIVITY_QUERY = (
    "select extract(year from consumed_at at time zone 'utc')::int as year, "
    "count(*) as log_count "
    "from public.user_beer_logs where user_id = $1 "
    "group by 1 order by 1"
)

# Favorite style/country/brewery: the mode among the user's
# is_favorite=true beers, tie-broken by name (case-insensitive) then by a
# stable id so two entities with identical names never produce a
# nondeterministic result. Each favorited beer joins to exactly one brewery,
# at most one style, and at most one effective country, so it contributes
# exactly one row to favorited_beers -- count(*) below is already "distinct
# favorited beers voting for this entity," not merely coincidentally equal
# to it (user_beer_collection also has unique(user_id, beer_id)).
_FAVORITES_QUERY = (
    "with favorited_beers as ("
    "select "
    "b.style_id, st.name as style_name, "
    f"{_EFFECTIVE_COUNTRY} as country_id, co.name as country_name, "
    "b.brewery_id, br.name as brewery_name "
    "from public.user_beer_collection c "
    "join public.beers b on b.id = c.beer_id "
    "join public.breweries br on br.id = b.brewery_id "
    "left join public.beer_styles st on st.id = b.style_id "
    f"left join public.countries co on co.id = {_EFFECTIVE_COUNTRY} "
    "where c.user_id = $1 and c.is_favorite = true"
    ") "
    "select "
    "(select style_name from favorited_beers where style_id is not null "
    "group by style_id, style_name "
    "order by count(*) desc, lower(style_name) asc, style_id asc limit 1) as favorite_style, "
    "(select country_name from favorited_beers where country_id is not null "
    "group by country_id, country_name "
    "order by count(*) desc, lower(country_name) asc, country_id asc limit 1) as favorite_country, "
    "(select brewery_name from favorited_beers where brewery_id is not null "
    "group by brewery_id, brewery_name "
    "order by count(*) desc, lower(brewery_name) asc, brewery_id asc limit 1) as favorite_brewery"
)


class StatisticsRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    def _scoped(self, user_id: str):
        # Opts into repeatable_read (unlike every other repository's plain
        # scoped_connection(user_id)) -- this is a read-only, multi-statement
        # aggregate, and a plain READ COMMITTED transaction would let a
        # commit between statements (e.g. a new log) produce an internally
        # inconsistent response. REPEATABLE READ fixes the snapshot at the
        # first statement for the whole transaction, with no write-conflict
        # risk since nothing here writes. See docs/DECISIONS.md.
        return scoped_connection(self._pool, user_id, isolation="repeatable_read")

    async def get_statistics(self, *, user_id: str) -> dict:
        async with self._scoped(user_id) as conn:
            overview = await conn.fetchrow(_OVERVIEW_QUERY, user_id)
            amount_spent_rows = await conn.fetch(_AMOUNT_SPENT_QUERY, user_id)
            monthly_rows = await conn.fetch(_MONTHLY_ACTIVITY_QUERY, user_id)
            yearly_rows = await conn.fetch(_YEARLY_ACTIVITY_QUERY, user_id)
            favorites = await conn.fetchrow(_FAVORITES_QUERY, user_id)
        return {
            "overview": overview,
            "amount_spent": amount_spent_rows,
            "monthly_activity": monthly_rows,
            "yearly_activity": yearly_rows,
            "favorites": favorites,
        }
