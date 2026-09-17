from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AchievementOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    key: str
    category: str
    unlocked: bool
    # None only for an achievement definition with no meaningful bar at all
    # (not used by the Phase 10 starter catalog -- every current entry sets
    # both, per the permanence display rule in AchievementsService).
    unlocked_at: datetime | None
    progress_current: int | None
    progress_target: int | None


class AchievementsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    # Bounded, non-paginated list -- same precedent as StatisticsOut, not
    # the Page[T] envelope used for potentially-large catalog listings.
    items: list[AchievementOut]
