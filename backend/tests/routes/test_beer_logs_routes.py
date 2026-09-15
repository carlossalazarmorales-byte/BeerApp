from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from app.dependencies import get_beer_log_service
from app.errors import InvalidRequestError, NotFoundError
from app.main import app
from app.schemas.beer_logs import BeerLogOut
from app.schemas.common import Page

_NOW = datetime.now(UTC)
_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "99999999-9999-9999-9999-999999999999"
_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")


def _log_out(**overrides) -> BeerLogOut:
    fields = {
        "id": uuid4(),
        "user_id": UUID(_USER_A),
        "beer_id": _BEER_ID,
        "rating": None,
        "review": None,
        "consumed_at": _NOW,
        "serving_note": None,
        "price": None,
        "currency": None,
        "venue_name": None,
        "serving_volume_ml": None,
        "created_at": _NOW,
        "updated_at": _NOW,
    }
    fields.update(overrides)
    return BeerLogOut(**fields)


class _FakeBeerLogService:
    """In-memory fake standing in for BeerLogService, enforcing the same
    ownership semantics a real service+repository+RLS stack would: a log
    belongs to whichever user_id created it, and any operation by a
    different user_id sees it as not-found.
    """

    def __init__(self) -> None:
        self._logs: dict[str, BeerLogOut] = {}
        self.create_error: Exception | None = None
        self.create_received_payload = None

    def _owned(self, log_id: str, user_id: str) -> BeerLogOut | None:
        log = self._logs.get(log_id)
        if log is None or str(log.user_id) != user_id:
            return None
        return log

    async def create_log(self, *, user_id: str, payload):
        self.create_received_payload = payload
        if self.create_error is not None:
            raise self.create_error
        if payload.consumed_at is not None and payload.consumed_at > datetime.now(UTC):
            raise InvalidRequestError("consumed_at cannot be in the future.")
        log = _log_out(
            id=uuid4(),
            user_id=UUID(user_id),
            beer_id=payload.beer_id,
            rating=payload.rating,
            review=payload.review,
            consumed_at=payload.consumed_at or datetime.now(UTC),
            serving_note=payload.serving_note,
            price=payload.price,
            currency=payload.currency,
            venue_name=payload.venue_name,
            serving_volume_ml=payload.serving_volume_ml,
        )
        self._logs[str(log.id)] = log
        return log

    async def list_logs(self, *, user_id: str, beer_id, page: int, page_size: int):
        items = [log for log in self._logs.values() if str(log.user_id) == user_id]
        return Page[BeerLogOut](items=items, page=page, page_size=page_size, total=len(items))

    async def get_log(self, *, user_id: str, log_id: str):
        log = self._owned(log_id, user_id)
        if log is None:
            raise NotFoundError(f"Beer log {log_id} not found")
        return log

    async def update_log(self, *, user_id: str, log_id: str, payload):
        log = self._owned(log_id, user_id)
        if log is None:
            raise NotFoundError(f"Beer log {log_id} not found")
        patch = payload.model_dump(exclude_unset=True)
        if "consumed_at" in patch and patch["consumed_at"] > datetime.now(UTC):
            raise InvalidRequestError("consumed_at cannot be in the future.")
        resulting_price = patch.get("price", log.price)
        resulting_currency = patch.get("currency", log.currency)
        if (resulting_price is None) != (resulting_currency is None):
            raise InvalidRequestError("price and currency must both be set or both be cleared.")
        updated = log.model_copy(update=patch)
        self._logs[log_id] = updated
        return updated

    async def delete_log(self, *, user_id: str, log_id: str) -> None:
        log = self._owned(log_id, user_id)
        if log is None:
            raise NotFoundError(f"Beer log {log_id} not found")
        del self._logs[log_id]


def _override(fake) -> None:
    app.dependency_overrides[get_beer_log_service] = lambda: fake


def _clear_override() -> None:
    app.dependency_overrides.pop(get_beer_log_service, None)


# -- auth gating -------------------------------------------------------


def test_create_without_token_is_unauthorized(client, unauthenticated):
    response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
    assert response.status_code == 401


def test_list_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/beer-logs")
    assert response.status_code == 401


# -- create --------------------------------------------------------------


def test_create_happy_path(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "rating": 4, "serving_volume_ml": 330},
        )
    finally:
        _clear_override()

    assert response.status_code == 201
    body = response.json()
    assert body["rating"] == 4
    assert body["serving_volume_ml"] == 330
    assert body["user_id"] == _USER_A


def test_create_omitted_serving_volume_ml_is_null_in_response(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
    finally:
        _clear_override()

    assert response.status_code == 201
    assert response.json()["serving_volume_ml"] is None


def test_create_serving_volume_ml_zero_is_422(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post(
            "/beer-logs", json={"beer_id": str(_BEER_ID), "serving_volume_ml": 0}
        )
    finally:
        _clear_override()

    assert response.status_code == 422


def test_create_cannot_spoof_user_id(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "user_id": _USER_B},
        )
    finally:
        _clear_override()

    # extra="forbid" rejects the unknown field outright.
    assert response.status_code == 422


def test_create_future_consumed_at_is_400(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    future = (datetime.now(UTC) + timedelta(days=1)).isoformat()
    try:
        response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID), "consumed_at": future})
    finally:
        _clear_override()

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"


def test_create_naive_consumed_at_is_422_never_500(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "consumed_at": "2026-01-01T10:00:00"},
        )
    finally:
        _clear_override()

    assert response.status_code == 422


def test_create_malformed_beer_id_is_422(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.post("/beer-logs", json={"beer_id": "not-a-uuid"})
    finally:
        _clear_override()

    assert response.status_code == 422


# -- ownership isolation ---------------------------------------------------


def test_get_update_delete_another_users_log_is_404_not_403(client, authenticated_as):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        authenticated_as(_USER_A)
        create_response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        log_id = create_response.json()["id"]

        authenticated_as(_USER_B)
        get_response = client.get(f"/beer-logs/{log_id}")
        patch_response = client.patch(f"/beer-logs/{log_id}", json={"review": "hijacked"})
        delete_response = client.delete(f"/beer-logs/{log_id}")
    finally:
        _clear_override()

    assert get_response.status_code == 404
    assert patch_response.status_code == 404
    assert delete_response.status_code == 404
    # Never a 403 -- existence and ownership are indistinguishable to the
    # client (see BeerLogService.update_log's docstring/comment).
    assert get_response.json()["error"]["code"] == "not_found"


def test_list_only_returns_the_caller_s_own_logs(client, authenticated_as):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        authenticated_as(_USER_A)
        client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})

        authenticated_as(_USER_B)
        client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        list_response = client.get("/beer-logs")
    finally:
        _clear_override()

    body = list_response.json()
    assert body["total"] == 1
    assert body["items"][0]["user_id"] == _USER_B


# -- PATCH semantics ---------------------------------------------------


def test_patch_empty_body_is_422(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        log_id = create_response.json()["id"]
        response = client.patch(f"/beer-logs/{log_id}", json={})
    finally:
        _clear_override()

    assert response.status_code == 422


def test_patch_consumed_at_null_is_422(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        log_id = create_response.json()["id"]
        response = client.patch(f"/beer-logs/{log_id}", json={"consumed_at": None})
    finally:
        _clear_override()

    assert response.status_code == 422


def test_patch_review_only_leaves_price_currency_untouched(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "price": "10.00", "currency": "USD"},
        )
        log_id = create_response.json()["id"]
        response = client.patch(f"/beer-logs/{log_id}", json={"review": "Solid"})
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert body["review"] == "Solid"
    assert body["price"] == "10.00"
    assert body["currency"] == "USD"


def test_patch_clearing_only_currency_is_400(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "price": "10.00", "currency": "USD"},
        )
        log_id = create_response.json()["id"]
        response = client.patch(f"/beer-logs/{log_id}", json={"currency": None})
    finally:
        _clear_override()

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"


def test_patch_clearing_both_price_and_currency_together_succeeds(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post(
            "/beer-logs",
            json={"beer_id": str(_BEER_ID), "price": "10.00", "currency": "USD"},
        )
        log_id = create_response.json()["id"]
        response = client.patch(f"/beer-logs/{log_id}", json={"price": None, "currency": None})
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert body["price"] is None
    assert body["currency"] is None


def test_patch_serving_volume_ml_set_then_clear(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        log_id = create_response.json()["id"]

        set_response = client.patch(f"/beer-logs/{log_id}", json={"serving_volume_ml": 500})
        clear_response = client.patch(f"/beer-logs/{log_id}", json={"serving_volume_ml": None})
    finally:
        _clear_override()

    assert set_response.status_code == 200
    assert set_response.json()["serving_volume_ml"] == 500
    assert clear_response.status_code == 200
    assert clear_response.json()["serving_volume_ml"] is None


# -- DELETE -----------------------------------------------------------


def test_delete_happy_path_is_204(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        create_response = client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        log_id = create_response.json()["id"]
        response = client.delete(f"/beer-logs/{log_id}")
    finally:
        _clear_override()

    assert response.status_code == 204
    assert response.content == b""


def test_delete_nonexistent_is_404(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.delete(f"/beer-logs/{uuid4()}")
    finally:
        _clear_override()

    assert response.status_code == 404


# -- pagination ordering (contract-level: the fake mirrors the real
#    repository's stable-sort behavior, so this asserts the route/schema
#    plumbs page/page_size/total through correctly; the actual ORDER BY is
#    exercised by the integration test against a real database) -----------


def test_list_pagination_envelope_shape(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        for _ in range(3):
            client.post("/beer-logs", json={"beer_id": str(_BEER_ID)})
        response = client.get("/beer-logs", params={"page": 1, "page_size": 20})
    finally:
        _clear_override()

    body = response.json()
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert body["total"] == 3
    assert len(body["items"]) == 3


def test_list_malformed_beer_id_is_422(client, authenticated):
    fake = _FakeBeerLogService()
    _override(fake)
    try:
        response = client.get("/beer-logs", params={"beer_id": "not-a-uuid"})
    finally:
        _clear_override()

    assert response.status_code == 422
