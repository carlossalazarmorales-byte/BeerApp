import asyncio
from datetime import UTC, datetime

from app.services.achievement_evaluator import AchievementEvaluator

_USER_ID = "11111111-1111-1111-1111-111111111111"
_CONN = object()  # sentinel -- the evaluator never inspects it, only forwards it


class _FakeAchievementsRepository:
    def __init__(self) -> None:
        self.unlocked: dict[str, datetime] = {}
        self.metrics: dict[str, int] = {"favorites_count": 0, "wishlist_count": 0}
        self.unlock_many_calls: list[list[str]] = []

    async def list_unlocked(self, conn, *, user_id: str):
        assert conn is _CONN
        assert user_id == _USER_ID
        return dict(self.unlocked)

    async def get_metrics(self, conn, *, user_id: str):
        assert conn is _CONN
        assert user_id == _USER_ID
        return dict(self.metrics)

    async def unlock_many(self, conn, *, user_id: str, keys: list[str]) -> None:
        assert conn is _CONN
        assert user_id == _USER_ID
        self.unlock_many_calls.append(list(keys))
        for key in keys:
            self.unlocked[key] = datetime.now(UTC)


def _run(coro):
    return asyncio.run(coro)


def test_below_threshold_never_calls_unlock_many():
    repository = _FakeAchievementsRepository()
    evaluator = AchievementEvaluator(repository)

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))

    assert repository.unlock_many_calls == []


def test_crossing_favorites_unlocks_exactly_first_favorite_not_curator():
    repository = _FakeAchievementsRepository()
    repository.metrics = {"favorites_count": 1, "wishlist_count": 0}
    evaluator = AchievementEvaluator(repository)

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))

    assert repository.unlock_many_calls == [["collection_first_favorite"]]


def test_reevaluating_an_already_unlocked_key_does_not_call_unlock_many_again():
    repository = _FakeAchievementsRepository()
    repository.metrics = {"favorites_count": 1, "wishlist_count": 0}
    evaluator = AchievementEvaluator(repository)

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))
    assert len(repository.unlock_many_calls) == 1

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))

    assert len(repository.unlock_many_calls) == 1  # no second call


def test_crossing_both_metrics_in_one_call_unlocks_all_three_including_curator():
    repository = _FakeAchievementsRepository()
    repository.metrics = {"favorites_count": 1, "wishlist_count": 1}
    evaluator = AchievementEvaluator(repository)

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))

    assert repository.unlock_many_calls == [
        ["collection_first_favorite", "collection_first_wishlist", "collection_curator"]
    ]


def test_curator_unlocks_from_a_previously_unlocked_prerequisite_not_simultaneous_metrics():
    """Regression test for the permanence-vs-simultaneity fix: curator must
    unlock once each prerequisite has EVER been unlocked, not only when both
    live metrics are true at the same instant (see docs/DECISIONS.md).
    """
    repository = _FakeAchievementsRepository()
    repository.unlocked = {"collection_first_favorite": datetime.now(UTC)}
    # Live favorites_count is now back to 0 (e.g. the favorite was later
    # removed) -- collection_first_favorite stays permanently unlocked
    # regardless, and only wishlist_count newly crosses in this call.
    repository.metrics = {"favorites_count": 0, "wishlist_count": 1}
    evaluator = AchievementEvaluator(repository)

    _run(evaluator.evaluate_and_unlock(_CONN, user_id=_USER_ID))

    assert repository.unlock_many_calls == [["collection_first_wishlist", "collection_curator"]]
