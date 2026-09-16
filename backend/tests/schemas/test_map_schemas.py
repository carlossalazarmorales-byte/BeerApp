from decimal import Decimal
from uuid import uuid4

from app.schemas.map import CappedList, MapBeerOut, MapBreweryOut

_BEER_ID = uuid4()
_BREWERY_ID = uuid4()


def _beer_out(**overrides) -> MapBeerOut:
    fields = {
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
    fields.update(overrides)
    return MapBeerOut(**fields)


def test_beer_marker_latitude_longitude_serialize_as_json_strings():
    # The Flutter client's json_parsing.dart parses latitude/longitude via a
    # string-tolerant helper specifically because FastAPI/Pydantic serialize
    # Decimal fields as JSON strings, not bare numbers -- a regression here
    # would silently break that client assumption.
    dumped = _beer_out().model_dump(mode="json")
    assert isinstance(dumped["latitude"], str)
    assert isinstance(dumped["longitude"], str)
    assert dumped["latitude"] == "50.229"
    assert dumped["longitude"] == "5.686"


def test_brewery_marker_latitude_longitude_serialize_as_json_strings():
    brewery = MapBreweryOut(
        brewery_id=_BREWERY_ID,
        name="Brasserie d'Achouffe",
        latitude=Decimal("50.229"),
        longitude=Decimal("5.686"),
        country_name="Belgium",
        city="Achouffe",
        region=None,
        description=None,
        website=None,
        verified=True,
    )
    dumped = brewery.model_dump(mode="json")
    assert isinstance(dumped["latitude"], str)
    assert isinstance(dumped["longitude"], str)


def test_capped_list_carries_truncated_flag_through():
    capped = CappedList[MapBeerOut](items=[_beer_out()], truncated=True)
    assert capped.truncated is True
    assert len(capped.items) == 1

    not_truncated = CappedList[MapBeerOut](items=[], truncated=False)
    assert not_truncated.truncated is False
