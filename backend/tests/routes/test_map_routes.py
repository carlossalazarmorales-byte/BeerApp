from decimal import Decimal
from uuid import UUID

from app.dependencies import get_map_service
from app.main import app
from app.schemas.map import CappedList, MapBeerOut, MapBreweryOut

_COUNTRY_ID = UUID("11111111-1111-1111-1111-111111111111")
_BREWERY_ID = UUID("33333333-3333-3333-3333-333333333333")
_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")


def _beer_out() -> MapBeerOut:
    return MapBeerOut(
        beer_id=_BEER_ID,
        official_name="La Chouffe",
        brewery_name="Achouffe",
        latitude=Decimal("50.229"),
        longitude=Decimal("5.686"),
        country_name="Belgium",
        region=None,
        is_tried=False,
        is_favorite=False,
        is_wishlist=False,
    )


def _brewery_out() -> MapBreweryOut:
    return MapBreweryOut(
        brewery_id=_BREWERY_ID,
        name="Achouffe",
        latitude=Decimal("50.229"),
        longitude=Decimal("5.686"),
        country_name="Belgium",
        city="Achouffe",
        region=None,
        description=None,
        website=None,
        verified=True,
    )


class _FakeMapService:
    def __init__(self, *, beers: list[MapBeerOut] | None = None, truncated: bool = False) -> None:
        self._beers = beers if beers is not None else [_beer_out()]
        self._truncated = truncated
        self.received_state: str | None = None
        self.received_country_id: str | None = None
        self.received_q: str | None = None

    async def list_beers(self, *, user_id, state, country_id, q):
        self.received_state = state
        self.received_country_id = country_id
        self.received_q = q
        return CappedList[MapBeerOut](items=self._beers, truncated=self._truncated)

    async def list_breweries(self, *, country_id, q):
        self.received_country_id = country_id
        self.received_q = q
        return CappedList[MapBreweryOut](items=[_brewery_out()], truncated=self._truncated)


def _override(fake) -> None:
    app.dependency_overrides[get_map_service] = lambda: fake


def _clear_overrides() -> None:
    app.dependency_overrides.pop(get_map_service, None)


# -- /map/beers ---------------------------------------------------------


def test_list_map_beers_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/map/beers")
    assert response.status_code == 401


def test_list_map_beers_defaults_to_all_state(client, authenticated):
    fake = _FakeMapService()
    _override(fake)
    try:
        response = client.get("/map/beers")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert fake.received_state == "all"
    body = response.json()
    assert body["truncated"] is False
    assert body["items"][0]["official_name"] == "La Chouffe"


def test_list_map_beers_passes_state_country_and_q_through(client, authenticated):
    fake = _FakeMapService()
    _override(fake)
    try:
        response = client.get(
            "/map/beers",
            params={"state": "favorites", "country_id": str(_COUNTRY_ID), "q": "stout"},
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert fake.received_state == "favorites"
    assert fake.received_country_id == str(_COUNTRY_ID)
    assert fake.received_q == "stout"


def test_list_map_beers_invalid_state_is_422(client, authenticated):
    _override(_FakeMapService())
    try:
        response = client.get("/map/beers", params={"state": "not-a-real-state"})
    finally:
        _clear_overrides()

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_list_map_beers_malformed_country_id_is_422(client, authenticated):
    _override(_FakeMapService())
    try:
        response = client.get("/map/beers", params={"country_id": "not-a-uuid"})
    finally:
        _clear_overrides()

    assert response.status_code == 422


def test_list_map_beers_truncated_flag_reaches_response_body(client, authenticated):
    _override(_FakeMapService(truncated=True))
    try:
        response = client.get("/map/beers")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert response.json()["truncated"] is True


# -- /map/breweries -------------------------------------------------------


def test_list_map_breweries_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/map/breweries")
    assert response.status_code == 401


def test_list_map_breweries_passes_country_and_q_through(client, authenticated):
    fake = _FakeMapService()
    _override(fake)
    try:
        response = client.get(
            "/map/breweries", params={"country_id": str(_COUNTRY_ID), "q": "achouffe"}
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert fake.received_country_id == str(_COUNTRY_ID)
    assert fake.received_q == "achouffe"
    body = response.json()
    assert body["items"][0]["name"] == "Achouffe"


def test_list_map_breweries_malformed_country_id_is_422(client, authenticated):
    _override(_FakeMapService())
    try:
        response = client.get("/map/breweries", params={"country_id": "not-a-uuid"})
    finally:
        _clear_overrides()

    assert response.status_code == 422
