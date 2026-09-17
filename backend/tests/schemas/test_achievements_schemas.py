from datetime import UTC, datetime

from app.schemas.achievements import AchievementOut, AchievementsOut


def test_achievement_out_validates_a_locked_progressive_entry():
    item = AchievementOut.model_validate(
        {
            "key": "collection_first_favorite",
            "category": "collection",
            "unlocked": False,
            "unlocked_at": None,
            "progress_current": 0,
            "progress_target": 1,
        }
    )

    assert item.unlocked is False
    assert item.unlocked_at is None
    assert item.progress_current == 0


def test_achievement_out_unlocked_progress_equals_target():
    now = datetime.now(UTC)
    item = AchievementOut.model_validate(
        {
            "key": "collection_first_favorite",
            "category": "collection",
            "unlocked": True,
            "unlocked_at": now,
            "progress_current": 1,
            "progress_target": 1,
        }
    )

    assert item.unlocked is True
    assert item.unlocked_at == now
    assert item.progress_current == item.progress_target


def test_achievements_out_wraps_a_list_of_items():
    payload = {
        "items": [
            {
                "key": "collection_curator",
                "category": "special",
                "unlocked": False,
                "unlocked_at": None,
                "progress_current": 0,
                "progress_target": 2,
            }
        ]
    }

    achievements = AchievementsOut.model_validate(payload)

    assert len(achievements.items) == 1
    assert achievements.items[0].key == "collection_curator"
