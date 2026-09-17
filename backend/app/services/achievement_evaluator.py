import asyncpg

from app.repositories.achievements import AchievementsRepository
from app.services.achievement_catalog import ACHIEVEMENT_CATALOG


class AchievementEvaluator:
    """Evaluates the achievement catalog against live state and persists any
    newly-satisfied unlocks, on a connection supplied by the caller.

    Operating on a caller-supplied connection (rather than opening its own
    scoped_connection) is what lets CollectionService.set_state run this in
    the SAME transaction as the Collection mutation that may have caused an
    unlock -- see docs/DECISIONS.md for why that atomicity matters
    (evaluating in a separate transaction can silently lose a permanently-
    earned achievement if evaluation fails after the mutation commits and
    the condition is reversed before anything retries).

    Fully idempotent: safe to call as often as needed, on any connection,
    including as a repair/backfill step from GET /achievements.
    """

    def __init__(self, repository: AchievementsRepository) -> None:
        self._repository = repository

    async def evaluate_and_unlock(self, conn: asyncpg.Connection, *, user_id: str) -> None:
        unlocked = await self._repository.list_unlocked(conn, user_id=user_id)
        metrics = await self._repository.get_metrics(conn, user_id=user_id)

        newly_unlocked: list[str] = []
        # Iterated in catalog (insertion) order so a prerequisite-based
        # entry can see a prerequisite unlocked earlier in this very pass --
        # `already_unlocked` below the loop is only what's newly decided on
        # this call, checked alongside the persisted `unlocked` map.
        already_unlocked = set(unlocked)
        for key, definition in ACHIEVEMENT_CATALOG.items():
            if key in already_unlocked:
                continue
            if definition.requirements:
                satisfied = all(
                    metrics[metric] >= threshold for metric, threshold in definition.requirements
                )
            else:
                satisfied = all(
                    prerequisite in already_unlocked
                    for prerequisite in definition.prerequisite_keys
                )
            if satisfied:
                newly_unlocked.append(key)
                already_unlocked.add(key)

        if newly_unlocked:
            await self._repository.unlock_many(conn, user_id=user_id, keys=newly_unlocked)
