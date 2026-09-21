from datetime import datetime

import asyncpg

# Every method here takes an already-open connection instead of a user_id
# and managing its own scoped_connection -- unlike every other repository in
# this codebase. This is deliberate: the caller (CollectionService.set_state,
# AchievementsService.get_achievements) owns the transaction boundary so a
# Collection mutation and its achievement evaluation/unlock can be composed
# into ONE atomic transaction. See docs/DECISIONS.md.

_METRICS_QUERY = (
    "select "
    "(select count(*) from public.user_beer_collection "
    "where user_id = $1 and is_favorite) as favorites_count, "
    "(select count(*) from public.user_beer_collection "
    "where user_id = $1 and is_wishlist) as wishlist_count"
)


class AchievementsRepository:
    async def list_unlocked(self, conn: asyncpg.Connection, *, user_id: str) -> dict[str, datetime]:
        rows = await conn.fetch(
            "select achievement_key, unlocked_at from public.user_achievements where user_id = $1",
            user_id,
        )
        return {row["achievement_key"]: row["unlocked_at"] for row in rows}

    async def get_metrics(self, conn: asyncpg.Connection, *, user_id: str) -> dict[str, int]:
        # Structured as its own small query (not composed with
        # StatisticsRepository) since the Phase 10 starter catalog needs
        # nothing StatisticsRepository already computes. A future
        # metric sourced from discovery counts can be added here without
        # changing this method's signature or any caller.
        row = await conn.fetchrow(_METRICS_QUERY, user_id)
        return {"favorites_count": row["favorites_count"], "wishlist_count": row["wishlist_count"]}

    async def unlock_many(self, conn: asyncpg.Connection, *, user_id: str, keys: list[str]) -> None:
        if not keys:
            return
        # ON CONFLICT DO NOTHING keeps this idempotent under repeated or
        # concurrent evaluation -- the loser of a race is a silent no-op,
        # and unlocked_at is whichever call actually won the insert.
        await conn.execute(
            "insert into public.user_achievements (user_id, achievement_key) "
            "select $1, unnest($2::text[]) "
            "on conflict (user_id, achievement_key) do nothing",
            user_id,
            keys,
        )
