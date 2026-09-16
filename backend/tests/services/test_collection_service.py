import asyncio
from uuid import UUID

import asyncpg
import pytest

from app.errors import NotFoundError
from app.schemas.collection import CollectionStateUpdate
from app.services.collection import CollectionService

_USER_ID = "11111111-1111-1111-1111-111111111111"
_BEER_ID = "44444444-4444-4444-4444-444444444444"


def _collection_beer_row(**overrides) -> dict:
    row = {
        "beer_id": UUID(_BEER_ID),
        "official_name": "Test Beer",
        "brewery_name": "Test Brewery",
        "style_name": "IPA",
        "country_name": "Ireland",
        "image_url": None,
        "abv": None,
        "is_favorite": False,
        "is_wishlist": False,
        "latest_rating": None,
        "latest_consumed_at": None,
    }
    row.update(overrides)
    return row


class _FakeCollectionRepository:
    def __init__(self) -> None:
        self.logged_result: tuple[list[dict], int] = ([], 0)
        self.favorites_result: tuple[list[dict], int] = ([], 0)
        self.wishlist_result: tuple[list[dict], int] = ([], 0)
        self.get_state_result: dict | None = None
        self.set_state_result: dict | None = None
        self.set_state_error: Exception | None = None
        self.set_state_calls: list[dict] = []

    async def list_logged(self, **kwargs):
        return self.logged_result

    async def list_favorites(self, **kwargs):
        return self.favorites_result

    async def list_wishlist(self, **kwargs):
        return self.wishlist_result

    async def get_state(self, *, user_id: str, beer_id: str):
        return self.get_state_result

    async def set_state(self, *, user_id: str, beer_id: str, is_favorite, is_wishlist):
        self.set_state_calls.append(
            {
                "user_id": user_id,
                "beer_id": beer_id,
                "is_favorite": is_favorite,
                "is_wishlist": is_wishlist,
            }
        )
        if self.set_state_error is not None:
            raise self.set_state_error
        return self.set_state_result


def _run(coro):
    return asyncio.run(coro)


# -- list_* pagination passthrough ------------------------------------------


def test_list_logged_wraps_repository_rows_into_page():
    repository = _FakeCollectionRepository()
    repository.logged_result = ([_collection_beer_row()], 1)
    service = CollectionService(repository)

    page = _run(
        service.list_logged(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.total == 1
    assert page.items[0].official_name == "Test Beer"


def test_list_favorites_wraps_repository_rows_into_page():
    repository = _FakeCollectionRepository()
    repository.favorites_result = ([_collection_beer_row(is_favorite=True)], 1)
    service = CollectionService(repository)

    page = _run(
        service.list_favorites(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.items[0].is_favorite is True


def test_list_wishlist_wraps_repository_rows_into_page():
    repository = _FakeCollectionRepository()
    repository.wishlist_result = ([_collection_beer_row(is_wishlist=True)], 1)
    service = CollectionService(repository)

    page = _run(
        service.list_wishlist(
            user_id=_USER_ID,
            country_id=None,
            style_id=None,
            brewery_id=None,
            sort="recent",
            page=1,
            page_size=20,
        )
    )

    assert page.items[0].is_wishlist is True


# -- get_state: 404 vs. 200 distinction --------------------------------------


def test_get_state_raises_not_found_when_repository_returns_none():
    repository = _FakeCollectionRepository()
    repository.get_state_result = None
    service = CollectionService(repository)

    with pytest.raises(NotFoundError):
        _run(service.get_state(user_id=_USER_ID, beer_id=_BEER_ID))


def test_get_state_returns_false_false_for_a_real_beer_with_no_row():
    repository = _FakeCollectionRepository()
    repository.get_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": False,
        "is_wishlist": False,
    }
    service = CollectionService(repository)

    result = _run(service.get_state(user_id=_USER_ID, beer_id=_BEER_ID))

    assert result.is_favorite is False
    assert result.is_wishlist is False


# -- set_state: FK violation -> NotFoundError --------------------------------


def test_set_state_foreign_key_violation_becomes_not_found():
    repository = _FakeCollectionRepository()
    repository.set_state_error = asyncpg.ForeignKeyViolationError("no such beer")
    service = CollectionService(repository)

    with pytest.raises(NotFoundError):
        _run(
            service.set_state(
                user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
            )
        )


def test_set_state_passes_absolute_requested_values_to_repository():
    repository = _FakeCollectionRepository()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": True,
        "is_wishlist": False,
    }
    service = CollectionService(repository)

    _run(
        service.set_state(
            user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=True)
        )
    )

    call = repository.set_state_calls[0]
    assert call["is_favorite"] is True
    assert call["is_wishlist"] is None  # omitted field passed through as None, not coerced


def test_set_state_returns_repository_result():
    repository = _FakeCollectionRepository()
    repository.set_state_result = {
        "beer_id": UUID(_BEER_ID),
        "is_favorite": False,
        "is_wishlist": False,
    }
    service = CollectionService(repository)

    result = _run(
        service.set_state(
            user_id=_USER_ID, beer_id=_BEER_ID, payload=CollectionStateUpdate(is_favorite=False)
        )
    )

    assert result.is_favorite is False
    assert result.is_wishlist is False
