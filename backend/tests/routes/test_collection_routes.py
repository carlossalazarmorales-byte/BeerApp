from uuid import UUID, uuid4

from app.dependencies import get_collection_service
from app.errors import NotFoundError
from app.main import app
from app.schemas.collection import CollectionStateOut
from app.schemas.common import Page

_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "99999999-9999-9999-9999-999999999999"
_REAL_BEER_ID = "44444444-4444-4444-4444-444444444444"
_UNKNOWN_BEER_ID = str(uuid4())


class _FakeCollectionService:
    """In-memory fake standing in for CollectionService. `_state` is keyed
    by (user_id, beer_id) and only ever holds a row when at least one flag
    is true -- mirrors the real repository's "all-false means no row"
    invariant, so these tests exercise the same observable contract.
    """

    def __init__(self) -> None:
        self._real_beers = {_REAL_BEER_ID}
        self._state: dict[tuple[str, str], dict] = {}

    @staticmethod
    def _empty_page(**kwargs) -> Page[CollectionStateOut]:
        return Page(
            items=[], page=kwargs.get("page", 1), page_size=kwargs.get("page_size", 20), total=0
        )

    async def list_logged(self, *, user_id: str, **kwargs) -> Page[CollectionStateOut]:
        return self._empty_page(**kwargs)

    async def list_favorites(self, *, user_id: str, **kwargs) -> Page[CollectionStateOut]:
        return self._empty_page(**kwargs)

    async def list_wishlist(self, *, user_id: str, **kwargs) -> Page[CollectionStateOut]:
        return self._empty_page(**kwargs)

    async def get_state(self, *, user_id: str, beer_id: str) -> CollectionStateOut:
        if beer_id not in self._real_beers:
            raise NotFoundError(f"Beer {beer_id} not found")
        state = self._state.get((user_id, beer_id), {"is_favorite": False, "is_wishlist": False})
        return CollectionStateOut(beer_id=UUID(beer_id), **state)

    async def set_state(self, *, user_id: str, beer_id: str, payload) -> CollectionStateOut:
        if beer_id not in self._real_beers:
            raise NotFoundError(f"Beer {beer_id} not found")
        current = self._state.get((user_id, beer_id), {"is_favorite": False, "is_wishlist": False})
        resulting_favorite = (
            payload.is_favorite if payload.is_favorite is not None else current["is_favorite"]
        )
        resulting_wishlist = (
            payload.is_wishlist if payload.is_wishlist is not None else current["is_wishlist"]
        )
        if not resulting_favorite and not resulting_wishlist:
            self._state.pop((user_id, beer_id), None)
        else:
            self._state[(user_id, beer_id)] = {
                "is_favorite": resulting_favorite,
                "is_wishlist": resulting_wishlist,
            }
        return CollectionStateOut(
            beer_id=UUID(beer_id), is_favorite=resulting_favorite, is_wishlist=resulting_wishlist
        )


def _override(fake) -> None:
    app.dependency_overrides[get_collection_service] = lambda: fake


def _clear_override() -> None:
    app.dependency_overrides.pop(get_collection_service, None)


# -- auth gating -------------------------------------------------------------


def test_get_state_without_token_is_unauthorized(client, unauthenticated):
    response = client.get(f"/collection/{_REAL_BEER_ID}")
    assert response.status_code == 401


def test_patch_state_without_token_is_unauthorized(client, unauthenticated):
    response = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
    assert response.status_code == 401


def test_list_logged_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/collection/logged")
    assert response.status_code == 401


# -- GET /collection/{beer_id}: 404 vs. 200 distinction ----------------------


def test_get_state_for_nonexistent_beer_is_404(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.get(f"/collection/{_UNKNOWN_BEER_ID}")
    finally:
        _clear_override()

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_state_for_real_beer_with_no_row_is_200_false_false(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.get(f"/collection/{_REAL_BEER_ID}")
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert body["is_favorite"] is False
    assert body["is_wishlist"] is False


# -- PATCH /collection/{beer_id} ----------------------------------------------


def test_patch_empty_body_is_422(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.patch(f"/collection/{_REAL_BEER_ID}", json={})
    finally:
        _clear_override()

    assert response.status_code == 422


def test_patch_cannot_spoof_user_id(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.patch(
            f"/collection/{_REAL_BEER_ID}",
            json={"is_favorite": True, "user_id": _USER_B},
        )
    finally:
        _clear_override()

    # extra="forbid" rejects the unknown field outright.
    assert response.status_code == 422


def test_patch_cannot_spoof_beer_id(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.patch(
            f"/collection/{_REAL_BEER_ID}",
            json={"is_favorite": True, "beer_id": _UNKNOWN_BEER_ID},
        )
    finally:
        _clear_override()

    assert response.status_code == 422


def test_patch_nonexistent_beer_is_404(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.patch(f"/collection/{_UNKNOWN_BEER_ID}", json={"is_favorite": True})
    finally:
        _clear_override()

    assert response.status_code == 404


def test_patch_sets_favorite_true(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert body["is_favorite"] is True
    assert body["is_wishlist"] is False


def test_patch_omitted_field_preserves_it(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_wishlist": True})
        response = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
    finally:
        _clear_override()

    body = response.json()
    assert body["is_favorite"] is True
    assert body["is_wishlist"] is True  # preserved, not clobbered by the second PATCH


def test_patch_clearing_last_true_flag_returns_false_false(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
        response = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": False})
    finally:
        _clear_override()

    body = response.json()
    assert body["is_favorite"] is False
    assert body["is_wishlist"] is False


def test_patch_repeated_identical_request_is_idempotent(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        first = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
        second = client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})
    finally:
        _clear_override()

    assert first.json() == second.json()


# -- per-user isolation -------------------------------------------------------


def test_state_is_isolated_per_user(client, authenticated_as):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        authenticated_as(_USER_A)
        client.patch(f"/collection/{_REAL_BEER_ID}", json={"is_favorite": True})

        authenticated_as(_USER_B)
        response = client.get(f"/collection/{_REAL_BEER_ID}")
    finally:
        _clear_override()

    # User B never favorited this beer -- sees the default state, never
    # user A's, and never a 403/leak of user A's action.
    body = response.json()
    assert body["is_favorite"] is False
    assert body["is_wishlist"] is False


# -- list endpoints: pagination envelope shape --------------------------------


def test_list_logged_pagination_envelope_shape(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.get("/collection/logged", params={"page": 1, "page_size": 20})
    finally:
        _clear_override()

    body = response.json()
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert "items" in body
    assert "total" in body


def test_list_favorites_malformed_country_id_is_422(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.get("/collection/favorites", params={"country_id": "not-a-uuid"})
    finally:
        _clear_override()

    assert response.status_code == 422


def test_list_wishlist_invalid_sort_is_422(client, authenticated):
    fake = _FakeCollectionService()
    _override(fake)
    try:
        response = client.get("/collection/wishlist", params={"sort": "not-a-real-sort"})
    finally:
        _clear_override()

    assert response.status_code == 422
