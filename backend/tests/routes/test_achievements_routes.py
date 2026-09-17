from app.dependencies import get_achievements_service
from app.main import app
from app.schemas.achievements import AchievementOut, AchievementsOut


def _canned_achievements() -> AchievementsOut:
    return AchievementsOut(
        items=[
            AchievementOut(
                key="collection_first_favorite",
                category="collection",
                unlocked=True,
                unlocked_at="2026-09-17T12:00:00Z",
                progress_current=1,
                progress_target=1,
            ),
            AchievementOut(
                key="collection_first_wishlist",
                category="collection",
                unlocked=False,
                unlocked_at=None,
                progress_current=0,
                progress_target=1,
            ),
        ]
    )


class _FakeAchievementsService:
    def __init__(self, result: AchievementsOut) -> None:
        self._result = result

    async def get_achievements(self, *, user_id: str) -> AchievementsOut:
        return self._result


def _override(fake) -> None:
    app.dependency_overrides[get_achievements_service] = lambda: fake


def _clear_override() -> None:
    app.dependency_overrides.pop(get_achievements_service, None)


def test_get_achievements_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/achievements")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_get_achievements_returns_full_body(client, authenticated):
    fake = _FakeAchievementsService(_canned_achievements())
    _override(fake)
    try:
        response = client.get("/achievements")
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert len(body["items"]) == 2
    assert body["items"][0]["key"] == "collection_first_favorite"
    assert body["items"][0]["unlocked"] is True
    assert body["items"][1]["unlocked"] is False
    assert body["items"][1]["unlocked_at"] is None


def test_post_achievements_is_405(client, authenticated):
    fake = _FakeAchievementsService(_canned_achievements())
    _override(fake)
    try:
        response = client.post("/achievements")
    finally:
        _clear_override()

    assert response.status_code == 405
