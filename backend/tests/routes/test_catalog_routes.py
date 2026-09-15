from datetime import UTC, datetime
from uuid import UUID

from app.dependencies import (
    get_beer_service,
    get_beer_style_service,
    get_brewery_service,
    get_country_service,
)
from app.errors import NotFoundError
from app.main import app
from app.schemas.beer_styles import BeerStyleOut
from app.schemas.beers import BeerOut
from app.schemas.breweries import BreweryOut
from app.schemas.common import Page
from app.schemas.countries import CountryOut

_NOW = datetime.now(UTC)
_IE_ID = UUID("11111111-1111-1111-1111-111111111111")
_STYLE_ID = UUID("22222222-2222-2222-2222-222222222222")
_BREWERY_ID = UUID("33333333-3333-3333-3333-333333333333")
_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")


class _FakeCountryService:
    async def list_countries(self) -> list[CountryOut]:
        return [
            CountryOut(
                id=_IE_ID,
                iso_code="IE",
                name="Ireland",
                continent="Europe",
                created_at=_NOW,
                updated_at=_NOW,
            )
        ]


class _FakeBeerStyleService:
    async def list_beer_styles(self) -> list[BeerStyleOut]:
        return [
            BeerStyleOut(
                id=_STYLE_ID,
                name="Dry Stout",
                category="Stout",
                description=None,
                origin_country_id=_IE_ID,
                typical_abv_min=None,
                typical_abv_max=None,
                created_at=_NOW,
                updated_at=_NOW,
            )
        ]


def _brewery_out() -> BreweryOut:
    return BreweryOut(
        id=_BREWERY_ID,
        name="St. James's Gate Brewery",
        country_id=_IE_ID,
        region=None,
        city="Dublin",
        latitude=None,
        longitude=None,
        description=None,
        website=None,
        logo_url=None,
        verified=True,
        source="dev-seed",
        created_at=_NOW,
        updated_at=_NOW,
    )


class _FakeBreweryService:
    def __init__(self, *, found: bool = True) -> None:
        self._found = found
        self.received_country_id: str | None = None
        self.received_page: int | None = None
        self.received_page_size: int | None = None

    async def list_breweries(
        self, *, country_id: str | None, page: int, page_size: int
    ) -> Page[BreweryOut]:
        self.received_country_id = country_id
        self.received_page = page
        self.received_page_size = page_size
        items = [_brewery_out()] if self._found else []
        return Page[BreweryOut](items=items, page=page, page_size=page_size, total=len(items))

    async def get_brewery(self, brewery_id: str) -> BreweryOut:
        if not self._found:
            raise NotFoundError(f"Brewery {brewery_id} not found")
        return _brewery_out()


def _beer_out() -> BeerOut:
    return BeerOut(
        id=_BEER_ID,
        official_name="Guinness Draught",
        brewery_id=_BREWERY_ID,
        style_id=_STYLE_ID,
        country_id=_IE_ID,
        region=None,
        city=None,
        latitude=None,
        longitude=None,
        abv=None,
        ibu=None,
        description=None,
        image_url=None,
        barcode="5000213007072",
        verified=True,
        source="dev-seed",
        created_at=_NOW,
        updated_at=_NOW,
    )


class _FakeBeerService:
    def __init__(self, *, found: bool = True) -> None:
        self._found = found

    async def list_beers(
        self,
        *,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        page: int,
        page_size: int,
    ) -> Page[BeerOut]:
        items = [_beer_out()] if self._found else []
        return Page[BeerOut](items=items, page=page, page_size=page_size, total=len(items))

    async def get_beer(self, beer_id: str) -> BeerOut:
        if not self._found:
            raise NotFoundError(f"Beer {beer_id} not found")
        return _beer_out()


def _override(dependency, fake) -> None:
    app.dependency_overrides[dependency] = lambda: fake


def _clear_overrides(*dependencies) -> None:
    for dependency in dependencies:
        app.dependency_overrides.pop(dependency, None)


# -- countries ---------------------------------------------------------


def test_list_countries_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/countries")
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json() == {
        "error": {"code": "unauthorized", "message": "Missing or invalid credentials."}
    }


def test_list_countries_returns_data_when_authenticated(client, authenticated):
    _override(get_country_service, _FakeCountryService())
    try:
        response = client.get("/countries")
    finally:
        _clear_overrides(get_country_service)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["iso_code"] == "IE"
    assert body[0]["continent"] == "Europe"


# -- beer styles ---------------------------------------------------------


def test_list_beer_styles_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/beer-styles")
    assert response.status_code == 401


def test_list_beer_styles_returns_data_when_authenticated(client, authenticated):
    _override(get_beer_style_service, _FakeBeerStyleService())
    try:
        response = client.get("/beer-styles")
    finally:
        _clear_overrides(get_beer_style_service)

    assert response.status_code == 200
    body = response.json()
    assert body[0]["name"] == "Dry Stout"


# -- breweries ---------------------------------------------------------


def test_list_breweries_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/breweries")
    assert response.status_code == 401


def test_list_breweries_passes_filters_and_pagination_through(client, authenticated):
    fake = _FakeBreweryService()
    _override(get_brewery_service, fake)
    try:
        response = client.get(
            "/breweries",
            params={
                "country_id": str(_IE_ID),
                "page": 2,
                "page_size": 5,
            },
        )
    finally:
        _clear_overrides(get_brewery_service)

    assert response.status_code == 200
    assert fake.received_country_id == str(_IE_ID)
    assert fake.received_page == 2
    assert fake.received_page_size == 5
    body = response.json()
    assert body["page"] == 2
    assert body["page_size"] == 5
    assert body["items"][0]["name"] == "St. James's Gate Brewery"


def test_list_breweries_malformed_country_id_is_422(client, authenticated):
    # This FastAPI version resolves sibling dependencies (the service, which
    # needs app.state.pool) before short-circuiting on an invalid query
    # param, so the service must still be overridden here even though the
    # assertion below never reaches it.
    _override(get_brewery_service, _FakeBreweryService())
    try:
        response = client.get("/breweries", params={"country_id": "not-a-uuid"})
    finally:
        _clear_overrides(get_brewery_service)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_get_brewery_not_found_is_404(client, authenticated):
    _override(get_brewery_service, _FakeBreweryService(found=False))
    try:
        response = client.get(f"/breweries/{_BREWERY_ID}")
    finally:
        _clear_overrides(get_brewery_service)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_brewery_found_returns_data(client, authenticated):
    _override(get_brewery_service, _FakeBreweryService(found=True))
    try:
        response = client.get(f"/breweries/{_BREWERY_ID}")
    finally:
        _clear_overrides(get_brewery_service)

    assert response.status_code == 200
    assert response.json()["name"] == "St. James's Gate Brewery"


# -- beers ---------------------------------------------------------


def test_list_beers_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/beers")
    assert response.status_code == 401


def test_list_beers_malformed_style_id_is_422(client, authenticated):
    # See the equivalent brewery test above for why the service is still
    # overridden here.
    _override(get_beer_service, _FakeBeerService())
    try:
        response = client.get("/beers", params={"style_id": "not-a-uuid"})
    finally:
        _clear_overrides(get_beer_service)

    assert response.status_code == 422


def test_get_beer_not_found_is_404(client, authenticated):
    _override(get_beer_service, _FakeBeerService(found=False))
    try:
        response = client.get(f"/beers/{_BEER_ID}")
    finally:
        _clear_overrides(get_beer_service)

    assert response.status_code == 404


def test_get_beer_found_returns_data(client, authenticated):
    _override(get_beer_service, _FakeBeerService(found=True))
    try:
        response = client.get(f"/beers/{_BEER_ID}")
    finally:
        _clear_overrides(get_beer_service)

    assert response.status_code == 200
    body = response.json()
    assert body["official_name"] == "Guinness Draught"
    assert body["barcode"] == "5000213007072"
