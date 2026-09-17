import asyncio
from contextlib import asynccontextmanager
from datetime import UTC, datetime

from app.services.achievements import AchievementsService

_USER_ID = "11111111-1111-1111-1111-111111111111"


class _FakeConnection:
    async def execute(self, *args, **kwargs):
        return None

    @asynccontextmanager
    async def transaction(self, isolation=None):
        yield None


class _FakePool:
    def __init__(self) -> None:
        self.conn = _FakeConnection()

    @asynccontextmanager
    async def acquire(self):
        yield self.conn


class _FakeAchievementsRepository:
    def __init__(self) -> None:
        self.unlocked: dict[str, datetime] = {}
        self.metrics: dict[str, int] = {"favorites_count": 0, "wishlist_count": 0}

    async def list_unlocked(self, conn, *, user_id: str):
        return dict(self.unlocked)

    async def get_metrics(self, conn, *, user_id: str):
        return dict(self.metrics)


class _FakeAchievementEvaluator:
    def __init__(self) -> None:
        self.calls: list[str] = []

    async def evaluate_and_unlock(self, conn, *, user_id: str) -> None:
        self.calls.append(user_id)


def _run(coro):
    return asyncio.run(coro)


def test_get_achievements_always_evaluates_first():
    repository = _FakeAchievementsRepository()
    evaluator = _FakeAchievementEvaluator()
    service = AchievementsService(_FakePool(), repository, evaluator)

    _run(service.get_achievements(user_id=_USER_ID))

    assert evaluator.calls == [_USER_ID]


def test_permanence_rule_unlocked_item_never_shows_regressed_progress():
    repository = _FakeAchievementsRepository()
    repository.unlocked = {"collection_first_favorite": datetime.now(UTC)}
    # Live metric has since dropped below the threshold (e.g. unfavorited).
    repository.metrics = {"favorites_count": 0, "wishlist_count": 0}
    evaluator = _FakeAchievementEvaluator()
    service = AchievementsService(_FakePool(), repository, evaluator)

    result = _run(service.get_achievements(user_id=_USER_ID))

    item = next(i for i in result.items if i.key == "collection_first_favorite")
    assert item.unlocked is True
    assert item.progress_current == item.progress_target


def test_unknown_retired_key_in_persisted_rows_is_silently_absent():
    repository = _FakeAchievementsRepository()
    repository.unlocked = {"some_retired_key": datetime.now(UTC)}
    evaluator = _FakeAchievementEvaluator()
    service = AchievementsService(_FakePool(), repository, evaluator)

    result = _run(service.get_achievements(user_id=_USER_ID))

    keys = [item.key for item in result.items]
    assert "some_retired_key" not in keys
    # No crash, and the three current catalog entries are still present.
    assert set(keys) == {
        "collection_first_favorite",
        "collection_first_wishlist",
        "collection_curator",
    }


def test_curator_progress_counts_prerequisites_met_not_a_raw_number():
    repository = _FakeAchievementsRepository()
    repository.unlocked = {"collection_first_favorite": datetime.now(UTC)}
    repository.metrics = {"favorites_count": 0, "wishlist_count": 0}
    evaluator = _FakeAchievementEvaluator()
    service = AchievementsService(_FakePool(), repository, evaluator)

    result = _run(service.get_achievements(user_id=_USER_ID))

    curator = next(i for i in result.items if i.key == "collection_curator")
    assert curator.unlocked is False
    assert curator.progress_current == 1  # one of two prerequisites unlocked
    assert curator.progress_target == 2
