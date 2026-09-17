import asyncpg

from app.repositories.achievements import AchievementsRepository
from app.repositories.scoped_connection import scoped_connection
from app.schemas.achievements import AchievementOut, AchievementsOut
from app.services.achievement_catalog import ACHIEVEMENT_CATALOG
from app.services.achievement_evaluator import AchievementEvaluator


class AchievementsService:
    def __init__(
        self,
        pool: asyncpg.Pool,
        repository: AchievementsRepository,
        evaluator: AchievementEvaluator,
    ) -> None:
        self._pool = pool
        self._repository = repository
        self._evaluator = evaluator

    async def get_achievements(self, *, user_id: str) -> AchievementsOut:
        # One transaction covers the idempotent repair/backfill evaluation
        # AND the subsequent reads, so the response always reflects
        # whatever this same call just persisted -- see
        # docs/DECISIONS.md.
        async with scoped_connection(self._pool, user_id) as conn:
            await self._evaluator.evaluate_and_unlock(conn, user_id=user_id)
            unlocked = await self._repository.list_unlocked(conn, user_id=user_id)
            metrics = await self._repository.get_metrics(conn, user_id=user_id)

        items = [
            _build_item(key, unlocked=unlocked, metrics=metrics) for key in ACHIEVEMENT_CATALOG
        ]
        return AchievementsOut(items=items)


def _build_item(key: str, *, unlocked: dict, metrics: dict[str, int]) -> AchievementOut:
    definition = ACHIEVEMENT_CATALOG[key]
    unlocked_at = unlocked.get(key)
    is_unlocked = unlocked_at is not None

    if definition.requirements:
        # Single-requirement (progressive) entry: a numeric progress bar.
        # Permanence display rule -- once unlocked, always show complete,
        # even if the live metric has since dropped below threshold (e.g. a
        # qualifying favorite was later removed). The bar must never
        # regress on an already-unlocked achievement.
        metric, threshold = definition.requirements[0]
        progress_target = threshold
        progress_current = threshold if is_unlocked else min(metrics[metric], threshold)
    else:
        # Compound (prerequisite-based) entry: a neutral "conditions met"
        # count, never a raw domain number. Not-yet-unlocked progress
        # counts how many of its prerequisite achievements are themselves
        # already unlocked.
        progress_target = len(definition.prerequisite_keys)
        progress_current = (
            progress_target
            if is_unlocked
            else sum(1 for prerequisite in definition.prerequisite_keys if prerequisite in unlocked)
        )

    return AchievementOut(
        key=key,
        category=definition.category.value,
        unlocked=is_unlocked,
        unlocked_at=unlocked_at,
        progress_current=progress_current,
        progress_target=progress_target,
    )
