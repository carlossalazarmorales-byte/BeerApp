import asyncio
from datetime import UTC, datetime
from uuid import UUID

import pytest

from app.errors import NotFoundError
from app.services.beers import BeerService
from app.services.breweries import BreweryService

_NOW = datetime.now(UTC)
_COUNTRY_ID = UUID("11111111-1111-1111-1111-111111111111")
_BREWERY_ID = UUID("33333333-3333-3333-3333-333333333333")


def _brewery_row(name: str) -> dict:
    return {
        "id": UUID("22222222-2222-2222-2222-222222222222"),
        "name": name,
        "country_id": _COUNTRY_ID,
        "region": None,
        "city": None,
        "latitude": None,
        "longitude": None,
        "description": None,
        "website": None,
        "logo_url": None,
        "verified": False,
        "source": None,
        "created_at": _NOW,
        "updated_at": _NOW,
    }


def _beer_row(name: str) -> dict:
    return {
        "id": UUID("44444444-4444-4444-4444-444444444444"),
        "official_name": name,
        "brewery_id": _BREWERY_ID,
        "style_id": None,
        "country_id": None,
        "region": None,
        "city": None,
        "latitude": None,
        "longitude": None,
        "abv": None,
        "ibu": None,
        "description": None,
        "image_url": None,
        "barcode": None,
        "verified": False,
        "source": None,
        "created_at": _NOW,
        "updated_at": _NOW,
        "is_tried": False,
    }


class _FakeBreweryRepository:
    def __init__(self, rows: list[dict], total: int) -> None:
        self._rows = rows
        self._total = total
        self.last_call: dict | None = None

    async def list_paginated(self, *, country_id, page, page_size):
        self.last_call = {"country_id": country_id, "page": page, "page_size": page_size}
        return self._rows, self._total

    async def get_by_id(self, brewery_id: str):
        return None


class _FakeBeerRepository:
    def __init__(self, rows: list[dict], total: int) -> None:
        self._rows = rows
        self._total = total
        self.received_q: str | None = "not called"

    async def list_paginated(self, **kwargs):
        self.received_q = kwargs.get("q")
        return self._rows, self._total

    async def get_by_id(self, beer_id: str):
        return None

    async def get_by_barcode(self, barcode: str):
        for row in self._rows:
            if row.get("barcode") == barcode:
                return row
        return None


def test_brewery_service_builds_page_envelope_from_repository_result():
    repository = _FakeBreweryRepository([_brewery_row("Achouffe")], total=37)
    service = BreweryService(repository)

    page = asyncio.run(service.list_breweries(country_id=str(_COUNTRY_ID), page=2, page_size=10))

    assert repository.last_call == {"country_id": str(_COUNTRY_ID), "page": 2, "page_size": 10}
    assert page.page == 2
    assert page.page_size == 10
    assert page.total == 37
    assert page.items[0].name == "Achouffe"


def test_brewery_service_get_by_id_raises_not_found_when_repository_returns_none():
    repository = _FakeBreweryRepository([], total=0)
    service = BreweryService(repository)

    with pytest.raises(NotFoundError):
        asyncio.run(service.get_brewery(str(_BREWERY_ID)))


def test_beer_service_builds_page_envelope_from_repository_result():
    repository = _FakeBeerRepository([_beer_row("La Chouffe")], total=8)
    service = BeerService(repository)

    page = asyncio.run(
        service.list_beers(
            user_id="user-1", country_id=None, style_id=None, brewery_id=None, page=1, page_size=20
        )
    )

    assert page.total == 8
    assert page.items[0].official_name == "La Chouffe"


def test_beer_service_get_by_id_raises_not_found_when_repository_returns_none():
    repository = _FakeBeerRepository([], total=0)
    service = BeerService(repository)

    with pytest.raises(NotFoundError):
        asyncio.run(service.get_beer("44444444-4444-4444-4444-444444444444"))


def test_beer_service_get_by_barcode_returns_matching_beer():
    row = _beer_row("La Chouffe")
    row["barcode"] = "5000213007075"
    repository = _FakeBeerRepository([row], total=1)
    service = BeerService(repository)

    beer = asyncio.run(service.get_beer_by_barcode("5000213007075"))

    assert beer.official_name == "La Chouffe"
    assert beer.barcode == "5000213007075"


def test_beer_service_get_by_barcode_raises_not_found_when_repository_returns_none():
    repository = _FakeBeerRepository([], total=0)
    service = BeerService(repository)

    with pytest.raises(NotFoundError):
        asyncio.run(service.get_beer_by_barcode("5000213007075"))


def test_beer_service_strips_surrounding_whitespace_from_q():
    repository = _FakeBeerRepository([_beer_row("La Chouffe")], total=1)
    service = BeerService(repository)

    asyncio.run(
        service.list_beers(
            user_id="user-1",
            country_id=None,
            style_id=None,
            brewery_id=None,
            q="  stout  ",
            page=1,
            page_size=20,
        )
    )

    assert repository.received_q == "stout"


def test_beer_service_treats_whitespace_only_q_as_no_search():
    repository = _FakeBeerRepository([_beer_row("La Chouffe")], total=1)
    service = BeerService(repository)

    asyncio.run(
        service.list_beers(
            user_id="user-1",
            country_id=None,
            style_id=None,
            brewery_id=None,
            q="   ",
            page=1,
            page_size=20,
        )
    )

    assert repository.received_q is None


def test_beer_service_treats_none_q_as_no_search():
    repository = _FakeBeerRepository([_beer_row("La Chouffe")], total=1)
    service = BeerService(repository)

    asyncio.run(
        service.list_beers(
            user_id="user-1",
            country_id=None,
            style_id=None,
            brewery_id=None,
            q=None,
            page=1,
            page_size=20,
        )
    )

    assert repository.received_q is None
