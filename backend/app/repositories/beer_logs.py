from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import datetime
from decimal import Decimal

import asyncpg

_COLUMNS = (
    "id, user_id, beer_id, rating, review, consumed_at, serving_note, "
    "price, currency, venue_name, serving_volume_ml, created_at, updated_at"
)

# The only columns BeerLogUpdate can ever produce (extra="forbid", fixed
# field set) -- this allowlist exists as a second, independent guard against
# ever string-interpolating an untrusted column name into the dynamic SET
# clause below, not because BeerLogUpdate is expected to produce anything
# else today.
_UPDATABLE_COLUMNS = {
    "rating",
    "review",
    "consumed_at",
    "serving_note",
    "price",
    "currency",
    "venue_name",
    "serving_volume_ml",
}


class BeerLogRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    @asynccontextmanager
    async def _scoped(self, user_id: str) -> AsyncIterator[asyncpg.Connection]:
        """Every user_beer_logs operation runs inside a transaction with
        app.user_id set via SET LOCAL (transaction-scoped, never
        session-level: the pool reuses physical connections across
        unrelated requests/users, and SET LOCAL is automatically unset at
        COMMIT/ROLLBACK, exactly when the connection returns to the pool).
        This is what the backend_owns_rows RLS policy on user_beer_logs
        checks against -- see supabase/migrations/
        20260915120700_grant_beerapp_backend_user_beer_logs.sql and
        docs/DATABASE.md. Every method below still filters
        `where user_id = $N` explicitly in addition to this -- the RLS
        policy is a backstop that makes an isolation bug in the SQL below
        non-exploitable, not a replacement for careful queries.
        """
        async with self._pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute("select set_config('app.user_id', $1, true)", user_id)
                yield conn

    async def create(
        self,
        *,
        user_id: str,
        beer_id: str,
        rating: int | None,
        review: str | None,
        consumed_at: datetime,
        serving_note: str | None,
        price: Decimal | None,
        currency: str | None,
        venue_name: str | None,
        serving_volume_ml: int | None,
    ) -> asyncpg.Record:
        query = (
            "insert into public.user_beer_logs "
            "(user_id, beer_id, rating, review, consumed_at, serving_note, "
            "price, currency, venue_name, serving_volume_ml) "
            "values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) "
            f"returning {_COLUMNS}"
        )
        async with self._scoped(user_id) as conn:
            return await conn.fetchrow(
                query,
                user_id,
                beer_id,
                rating,
                review,
                consumed_at,
                serving_note,
                price,
                currency,
                venue_name,
                serving_volume_ml,
            )

    async def list_paginated(
        self, *, user_id: str, beer_id: str | None, page: int, page_size: int
    ) -> tuple[list[asyncpg.Record], int]:
        # WHERE clause built once and reused for both the count and the page
        # query, same drift-proofing pattern as BeerRepository -- `total`
        # must always describe the exact same filtered row set as the page
        # of results built from the same clause.
        params: list = [user_id]
        conditions = ["user_id = $1"]
        if beer_id is not None:
            params.append(beer_id)
            conditions.append(f"beer_id = ${len(params)}")
        where_clause = f"where {' and '.join(conditions)}"

        offset = (page - 1) * page_size
        count_query = f"select count(*) from public.user_beer_logs {where_clause}"
        # ORDER BY consumed_at DESC, id DESC -- id is the stable tie-breaker
        # so pagination stays deterministic when two logs share a
        # consumed_at (e.g. two quick-logs submitted in the same second).
        list_query = (
            f"select {_COLUMNS} from public.user_beer_logs {where_clause} "
            f"order by consumed_at desc, id desc "
            f"limit ${len(params) + 1} offset ${len(params) + 2}"
        )

        async with self._scoped(user_id) as conn:
            total = await conn.fetchval(count_query, *params)
            rows = await conn.fetch(list_query, *params, page_size, offset)
        return rows, total

    async def get_by_id(self, *, log_id: str, user_id: str) -> asyncpg.Record | None:
        query = f"select {_COLUMNS} from public.user_beer_logs where id = $1 and user_id = $2"
        async with self._scoped(user_id) as conn:
            return await conn.fetchrow(query, log_id, user_id)

    async def update(self, *, log_id: str, user_id: str, fields: dict) -> asyncpg.Record | None:
        unknown = set(fields) - _UPDATABLE_COLUMNS
        if unknown:
            raise ValueError(f"Unknown update field(s): {sorted(unknown)}")
        if not fields:
            # BeerLogUpdate's _reject_empty_patch validator already prevents
            # an empty patch from reaching the service; this guard only
            # protects the repository itself should that ever change.
            raise ValueError("fields must not be empty")

        params: list = []
        set_clauses = []
        for column, value in fields.items():
            params.append(value)
            set_clauses.append(f"{column} = ${len(params)}")
        params.append(log_id)
        log_id_param = f"${len(params)}"
        params.append(user_id)
        user_id_param = f"${len(params)}"

        query = (
            f"update public.user_beer_logs set {', '.join(set_clauses)} "
            f"where id = {log_id_param} and user_id = {user_id_param} "
            f"returning {_COLUMNS}"
        )
        async with self._scoped(user_id) as conn:
            return await conn.fetchrow(query, *params)

    async def delete(self, *, log_id: str, user_id: str) -> bool:
        query = "delete from public.user_beer_logs where id = $1 and user_id = $2"
        async with self._scoped(user_id) as conn:
            result = await conn.execute(query, log_id, user_id)
        # asyncpg's execute() returns a command tag like "DELETE 1"/"DELETE 0".
        return result.split()[-1] != "0"
