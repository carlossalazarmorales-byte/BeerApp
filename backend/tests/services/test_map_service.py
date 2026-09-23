import asyncio
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from app.services.map import MapService

_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")
_BREWERY_ID = UUID("33333333-3333-3333-3333-333333333333")
_NOW = datetime.now(UTC)


def _beer_row(**overrides) -> dict:
    row = {
        "beer_id": _BEER_ID,
        "official_name": "La Chouffe",
        "brewery_name": "Achouffe",
        "latitude": Decimal("50.229"),
        "longitude": Decimal("5.686"),
        "country_name": "Belgium",
        "region": None,
        "is_tried": False,
        "is_favorite": False,
        "is_wishlist": False,
    }
    row.update(overrides)
    return row


def _brewery_row(**overrides) -> dict:
    row = {
        "brewery_id": _BREWERY_ID,
        "name": "Achouffe",
        "latitude": Decimal("50.229"),
        "longitude": Decimal("5.686"),
        "country_name": "Belgium",
        "city": "Achouffe",
        "region": None,
        "description": None,
        "website": None,
        "verified": True,
    }
    row.update(overrides)
    return row


class _FakeMapRepository:
    def __init__(
        self,
        *,
        beer_rows: list[dict] | None = None,
        beers_truncated: bool = False,
        brewery_rows: list[dict] | None = None,
        breweries_truncated: bool = False,
        country_coverage_rows: list[dict] | None = None,
    ) -> None:
        self._beer_rows = beer_rows or []
        self._beers_truncated = beers_truncated
        self._brewery_rows = brewery_rows or []
        self._breweries_truncated = breweries_truncated
        self._country_coverage_rows = country_coverage_rows or []
        self.last_beers_call: dict | None = None
        self.last_breweries_call: dict | None = None
        self.last_country_coverage_call: dict | None = None

    async def list_beers(self, *, user_id, state, country_id, q):
        self.last_beers_call = {
            "user_id": user_id,
            "state": state,
            "country_id": country_id,
            "q": q,
        }
        return self._beer_rows, self._beers_truncated

    async def list_breweries(self, *, country_id, q):
        self.last_breweries_call = {"country_id": country_id, "q": q}
        return self._brewery_rows, self._breweries_truncated

    async def list_country_coverage(self, *, user_id):
        self.last_country_coverage_call = {"user_id": user_id}
        return self._country_coverage_rows


def test_list_beers_builds_dto_list_from_repository_rows():
    repository = _FakeMapRepository(beer_rows=[_beer_row()])
    service = MapService(repository)

    result = asyncio.run(service.list_beers(user_id="user-a", state="all", country_id=None, q=None))

    assert len(result.items) == 1
    assert result.items[0].official_name == "La Chouffe"
    assert result.truncated is False


def test_list_beers_propagates_truncated_flag():
    repository = _FakeMapRepository(beer_rows=[_beer_row()], beers_truncated=True)
    service = MapService(repository)

    result = asyncio.run(service.list_beers(user_id="user-a", state="all", country_id=None, q=None))

    assert result.truncated is True


def test_list_beers_strips_surrounding_whitespace_from_q():
    repository = _FakeMapRepository(beer_rows=[_beer_row()])
    service = MapService(repository)

    asyncio.run(service.list_beers(user_id="user-a", state="all", country_id=None, q="  stout  "))

    assert repository.last_beers_call["q"] == "stout"


def test_list_beers_treats_whitespace_only_q_as_no_search():
    repository = _FakeMapRepository(beer_rows=[_beer_row()])
    service = MapService(repository)

    asyncio.run(service.list_beers(user_id="user-a", state="all", country_id=None, q="   "))

    assert repository.last_beers_call["q"] is None


def test_list_beers_passes_state_and_country_id_through():
    repository = _FakeMapRepository(beer_rows=[])
    service = MapService(repository)

    asyncio.run(
        service.list_beers(user_id="user-a", state="favorites", country_id="country-1", q=None)
    )

    assert repository.last_beers_call == {
        "user_id": "user-a",
        "state": "favorites",
        "country_id": "country-1",
        "q": None,
    }


def test_list_breweries_builds_dto_list_from_repository_rows():
    repository = _FakeMapRepository(brewery_rows=[_brewery_row()])
    service = MapService(repository)

    result = asyncio.run(service.list_breweries(country_id=None, q=None))

    assert len(result.items) == 1
    assert result.items[0].name == "Achouffe"
    assert result.truncated is False


def test_list_breweries_propagates_truncated_flag():
    repository = _FakeMapRepository(brewery_rows=[_brewery_row()], breweries_truncated=True)
    service = MapService(repository)

    result = asyncio.run(service.list_breweries(country_id=None, q=None))

    assert result.truncated is True


def _country_coverage_row(**overrides) -> dict:
    row = {
        "country_id": UUID("55555555-5555-5555-5555-555555555555"),
        "iso_code": "BE",
        "catalog_beer_count": 5,
        "tried_beer_count": 2,
    }
    row.update(overrides)
    return row


def test_list_country_coverage_builds_dto_list_from_repository_rows():
    repository = _FakeMapRepository(country_coverage_rows=[_country_coverage_row()])
    service = MapService(repository)

    result = asyncio.run(service.list_country_coverage(user_id="user-a"))

    assert len(result) == 1
    assert result[0].iso_code == "BE"
    assert result[0].catalog_beer_count == 5
    assert result[0].tried_beer_count == 2


def test_list_country_coverage_passes_user_id_through():
    repository = _FakeMapRepository()
    service = MapService(repository)

    asyncio.run(service.list_country_coverage(user_id="user-a"))

    assert repository.last_country_coverage_call == {"user_id": "user-a"}
