"""Route-level input bounds: invalid input must be a 422, never a database
error. Complements tests/schemas/test_input_bounds.py (schema level).
"""

import pytest
from fastapi.routing import APIRoute

from app.dependencies import (
    get_beer_log_service,
    get_beer_service,
    get_contribution_service,
    get_map_service,
)
from app.main import app
from app.schemas.common import MAX_PAGE, Page

_BEER_ID = "44444444-4444-4444-4444-444444444444"


class _Untouched:
    """Stands in for a service that must never be reached on invalid input."""

    def __getattr__(self, name):
        raise AssertionError(f"service.{name} must not be called for an invalid request")


class _EmptyPageService:
    async def list_beers(self, **kwargs):
        return Page(items=[], page=kwargs["page"], page_size=kwargs["page_size"], total=0)

    async def list_logs(self, **kwargs):
        return Page(items=[], page=kwargs["page"], page_size=kwargs["page_size"], total=0)


@pytest.fixture
def override(client):
    applied = []

    def _apply(dependency, instance):
        app.dependency_overrides[dependency] = lambda: instance
        applied.append(dependency)

    yield _apply
    for dependency in applied:
        app.dependency_overrides.pop(dependency, None)


# -- pagination ---------------------------------------------------------------


def _api_routes():
    """Every APIRoute, including those inside lazily-included routers (this
    FastAPI version wraps `include_router` targets in `_IncludedRouter`)."""
    for route in app.routes:
        if isinstance(route, APIRoute):
            yield route
        elif hasattr(route, "original_router"):
            yield from (r for r in route.original_router.routes if isinstance(r, APIRoute))


def _routes_with_page_param():
    return [
        (route, param)
        for route in _api_routes()
        for param in route.dependant.query_params
        if param.name == "page"
    ]


def test_every_paginated_route_caps_page_at_max_page():
    found = _routes_with_page_param()
    assert len(found) >= 7, "expected every list endpoint to be discovered"

    for route, param in found:
        limits = {getattr(m, "le", None) for m in param.field_info.metadata}
        assert MAX_PAGE in limits, f"{route.path} has no upper bound on page"


def test_max_page_times_max_page_size_stays_far_inside_a_bigint_offset():
    assert MAX_PAGE * 100 < 2**31


def test_page_above_the_maximum_is_422(client, authenticated, override):
    override(get_beer_service, _Untouched())

    response = client.get("/beers", params={"page": MAX_PAGE + 1})

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_page_at_the_maximum_is_accepted(client, authenticated, override):
    override(get_beer_service, _EmptyPageService())

    response = client.get("/beers", params={"page": MAX_PAGE})

    assert response.status_code == 200
    assert response.json()["page"] == MAX_PAGE


def test_absurd_page_numbers_are_422_not_a_database_error(client, authenticated, override):
    override(get_beer_log_service, _Untouched())

    for page in (10**12, 10**30):
        assert client.get("/beer-logs", params={"page": page}).status_code == 422


# -- NUL in search text -------------------------------------------------------


def test_search_text_with_a_nul_character_is_422_on_catalog_search(client, authenticated, override):
    override(get_beer_service, _Untouched())

    assert client.get("/beers", params={"q": "ab\x00cd"}).status_code == 422


def test_search_text_with_a_nul_character_is_422_on_the_map(client, authenticated, override):
    override(get_map_service, _Untouched())

    assert client.get("/map/beers", params={"q": "ab\x00cd"}).status_code == 422
    assert client.get("/map/breweries", params={"q": "ab\x00cd"}).status_code == 422


def test_ordinary_search_text_is_still_accepted(client, authenticated, override):
    override(get_beer_service, _EmptyPageService())

    assert client.get("/beers", params={"q": "cerveza \U0001f37a"}).status_code == 200


# -- barcode ------------------------------------------------------------------


def test_non_ascii_digit_barcode_path_is_422(client, authenticated, override):
    override(get_beer_service, _Untouched())
    arabic_indic = "5000213007075".translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))

    response = client.get(f"/beers/barcode/{arabic_indic}")

    assert response.status_code == 422


# -- request bodies -----------------------------------------------------------


def _log_body(**fields) -> dict:
    return {"beer_id": _BEER_ID, **fields}


@pytest.mark.parametrize(
    "fields",
    [
        {"price": "100000000.00", "currency": "EUR"},
        {"price": "12.345", "currency": "EUR"},
        {"price": "1e400", "currency": "EUR"},
        {"serving_volume_ml": 2_147_483_648},
        {"review": "a\x00b"},
    ],
)
def test_out_of_range_beer_log_body_is_422_before_the_service(
    client, authenticated, override, fields
):
    override(get_beer_log_service, _Untouched())

    response = client.post("/beer-logs", json=_log_body(**fields))

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_contribution_body_with_a_nul_character_is_422(client, authenticated, override):
    override(get_contribution_service, _Untouched())

    response = client.post(
        "/beer-contributions",
        json={"official_name": "Hazy\x00IPA", "brewery_id": "55555555-5555-5555-5555-555555555555"},
    )

    assert response.status_code == 422


def test_validation_errors_do_not_echo_the_offending_value(client, authenticated, override):
    override(get_beer_log_service, _Untouched())

    response = client.post("/beer-logs", json=_log_body(price="100000000.00", currency="EUR"))

    assert "100000000" not in response.text
