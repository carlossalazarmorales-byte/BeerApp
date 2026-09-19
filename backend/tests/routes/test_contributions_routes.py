from datetime import UTC, datetime
from uuid import UUID, uuid4

import pytest

from app.dependencies import get_contribution_service
from app.errors import ConflictError, NotFoundError
from app.main import app
from app.schemas.common import Page
from app.schemas.contributions import (
    BeerContributionOut,
    BeerDuplicateCandidatesOut,
    BreweryContributionOut,
    BreweryDuplicateCandidatesOut,
    ContributionSummaryOut,
)

_NOW = datetime.now(UTC)
_USER_A = "11111111-1111-1111-1111-111111111111"
_USER_B = "99999999-9999-9999-9999-999999999999"
_BREWERY_ID = "44444444-4444-4444-4444-444444444444"
_COUNTRY_ID = "66666666-6666-6666-6666-666666666666"

_BEER_BODY = {"official_name": "Hazy IPA", "brewery_id": _BREWERY_ID}
_BREWERY_BODY = {"name": "Hop House", "country_id": _COUNTRY_ID}
_BEER_CHECK = {"official_name": "Hazy IPA", "brewery_id": _BREWERY_ID}
_BREWERY_CHECK = {"name": "Hop House", "country_id": _COUNTRY_ID}


class _FakeContributionService:
    """Stands in for ContributionService: records exactly what the route hands
    it (in particular the user id, which must come from the JWT alone) and can
    be told to raise.
    """

    def __init__(self) -> None:
        self.error: Exception | None = None
        self.calls: list[tuple] = []
        self.pending_barcode_duplicate_exists = False

    def _maybe_raise(self) -> None:
        if self.error is not None:
            raise self.error

    async def submit_beer(self, *, user_id: str, payload):
        self.calls.append(("submit_beer", user_id, payload))
        self._maybe_raise()
        return BeerContributionOut(
            id=uuid4(),
            official_name=payload.official_name,
            brewery_id=payload.brewery_id,
            proposed_brewery_name=payload.proposed_brewery_name,
            style_id=payload.style_id,
            proposed_style_name=payload.proposed_style_name,
            abv=payload.abv,
            barcode=payload.barcode,
            status="pending",
            created_at=_NOW,
        )

    async def submit_brewery(self, *, user_id: str, payload):
        self.calls.append(("submit_brewery", user_id, payload))
        self._maybe_raise()
        return BreweryContributionOut(
            id=uuid4(),
            name=payload.name,
            country_id=payload.country_id,
            proposed_country_name=payload.proposed_country_name,
            region=payload.region,
            city=payload.city,
            status="pending",
            created_at=_NOW,
        )

    async def list_history(self, *, user_id: str, page: int, page_size: int):
        self.calls.append(("list_history", user_id, page, page_size))
        self._maybe_raise()
        item = ContributionSummaryOut(
            kind="beer", id=uuid4(), title="Hazy IPA", status="pending", created_at=_NOW
        )
        return Page[ContributionSummaryOut](items=[item], page=page, page_size=page_size, total=1)

    async def beer_duplicate_candidates(self, *, user_id: str, query):
        self.calls.append(("beer_duplicate_candidates", user_id, query))
        self._maybe_raise()
        return BeerDuplicateCandidatesOut(
            barcode_match=None,
            name_matches=[],
            brewery_matches=[],
            already_submitted=False,
            pending_barcode_duplicate_exists=self.pending_barcode_duplicate_exists,
        )

    async def brewery_duplicate_candidates(self, *, user_id: str, query):
        self.calls.append(("brewery_duplicate_candidates", user_id, query))
        self._maybe_raise()
        return BreweryDuplicateCandidatesOut(name_matches=[], already_submitted=False)


@pytest.fixture
def service():
    fake = _FakeContributionService()
    app.dependency_overrides[get_contribution_service] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_contribution_service, None)


# -- auth gating --------------------------------------------------------------


@pytest.mark.parametrize(
    ("method", "path", "kwargs"),
    [
        ("post", "/beer-contributions", {"json": _BEER_BODY}),
        ("post", "/brewery-contributions", {"json": _BREWERY_BODY}),
        ("get", "/contributions", {}),
        ("get", "/beer-contributions/duplicate-candidates", {"params": _BEER_CHECK}),
        ("get", "/brewery-contributions/duplicate-candidates", {"params": _BREWERY_CHECK}),
    ],
)
def test_every_endpoint_requires_authentication(
    client, unauthenticated, service, method, path, kwargs
):
    response = getattr(client, method)(path, **kwargs)
    assert response.status_code == 401
    assert service.calls == []


# -- submit beer --------------------------------------------------------------


def test_submit_beer_returns_201_pending_and_no_owner_field(client, authenticated, service):
    response = client.post("/beer-contributions", json={**_BEER_BODY, "abv": "6.5"})

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "pending"
    assert body["official_name"] == "Hazy IPA"
    assert body["brewery_id"] == _BREWERY_ID
    assert "user_id" not in body


def test_submit_beer_owner_comes_only_from_the_jwt(client, authenticated_as, service):
    authenticated_as(_USER_B)
    response = client.post("/beer-contributions", json=_BEER_BODY)

    assert response.status_code == 201
    assert service.calls[0][1] == _USER_B


@pytest.mark.parametrize("field", ["user_id", "status", "reviewed_at", "resolved_beer_id"])
def test_submit_beer_cannot_forge_owner_or_moderation_fields(client, authenticated, service, field):
    response = client.post("/beer-contributions", json={**_BEER_BODY, field: _USER_B})

    assert response.status_code == 422
    assert service.calls == []


def test_submit_beer_with_a_proposed_brewery_needs_no_brewery_contribution(
    client, authenticated, service
):
    response = client.post(
        "/beer-contributions",
        json={"official_name": "Hazy IPA", "proposed_brewery_name": "Brand New Brewery"},
    )

    assert response.status_code == 201
    assert response.json()["proposed_brewery_name"] == "Brand New Brewery"
    assert response.json()["brewery_id"] is None


@pytest.mark.parametrize(
    "body",
    [
        {"official_name": "Hazy IPA"},  # no brewery at all
        {**_BEER_BODY, "proposed_brewery_name": "Both"},  # both brewery forms
        {**_BEER_BODY, "official_name": "   "},  # blank name
        {**_BEER_BODY, "abv": "100"},  # out of range
        {**_BEER_BODY, "barcode": "4006381333932"},  # bad check digit
        {**_BEER_BODY, "barcode": "12345"},  # unsupported length
    ],
)
def test_submit_beer_invalid_bodies_are_422(client, authenticated, service, body):
    response = client.post("/beer-contributions", json=body)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert service.calls == []


def test_submit_beer_canonicalizes_the_barcode_before_the_service_sees_it(
    client, authenticated, service
):
    response = client.post("/beer-contributions", json={**_BEER_BODY, "barcode": "036000291452"})

    assert response.status_code == 201
    assert service.calls[0][2].barcode == "0036000291452"


def test_submit_beer_barcode_already_in_catalog_is_409_with_a_machine_code(
    client, authenticated, service
):
    service.error = ConflictError("barcode_in_catalog", "A beer with this barcode exists.")

    response = client.post("/beer-contributions", json=_BEER_BODY)

    assert response.status_code == 409
    assert response.json() == {
        "error": {"code": "barcode_in_catalog", "message": "A beer with this barcode exists."}
    }


def test_submit_beer_own_duplicate_is_409_already_submitted(client, authenticated, service):
    service.error = ConflictError("already_submitted", "You already have this pending.")

    response = client.post("/beer-contributions", json=_BEER_BODY)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "already_submitted"


def test_submit_beer_unknown_catalog_reference_is_404(client, authenticated, service):
    service.error = NotFoundError("Brewery x not found")

    response = client.post("/beer-contributions", json=_BEER_BODY)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


# -- submit brewery -----------------------------------------------------------


def test_submit_brewery_returns_201_pending_and_no_owner_field(client, authenticated, service):
    response = client.post("/brewery-contributions", json={**_BREWERY_BODY, "city": "Munich"})

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "pending"
    assert body["city"] == "Munich"
    assert "user_id" not in body


def test_submit_brewery_with_a_proposed_country(client, authenticated, service):
    response = client.post(
        "/brewery-contributions", json={"name": "Hop House", "proposed_country_name": "Atlantis"}
    )

    assert response.status_code == 201
    assert response.json()["country_id"] is None
    assert response.json()["proposed_country_name"] == "Atlantis"


@pytest.mark.parametrize(
    "body",
    [
        {"name": "Hop House"},  # no country at all
        {**_BREWERY_BODY, "proposed_country_name": "Both"},
        {**_BREWERY_BODY, "user_id": _USER_B},
        {**_BREWERY_BODY, "status": "approved"},
        {**_BREWERY_BODY, "latitude": 1.0},  # coordinates are not collected
    ],
)
def test_submit_brewery_invalid_bodies_are_422(client, authenticated, service, body):
    response = client.post("/brewery-contributions", json=body)

    assert response.status_code == 422
    assert service.calls == []


def test_submit_brewery_own_duplicate_is_409(client, authenticated, service):
    service.error = ConflictError("already_submitted", "You already have this pending.")

    response = client.post("/brewery-contributions", json=_BREWERY_BODY)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "already_submitted"


# -- history ------------------------------------------------------------------


def test_history_is_always_scoped_to_the_caller(client, authenticated_as, service):
    authenticated_as(_USER_A)
    response = client.get("/contributions")

    assert response.status_code == 200
    assert service.calls == [("list_history", _USER_A, 1, 20)]
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["kind"] == "beer"
    assert set(body["items"][0]) == {"kind", "id", "title", "status", "created_at"}


def test_history_has_no_user_id_parameter(client, authenticated, service):
    # An unknown query parameter is ignored by FastAPI -- what matters is that
    # it can never select whose history is returned.
    client.get("/contributions", params={"user_id": _USER_B})
    assert service.calls[0][1] == _USER_A


@pytest.mark.parametrize("params", [{"page": 0}, {"page_size": 0}, {"page_size": 101}])
def test_history_pagination_bounds_are_422(client, authenticated, service, params):
    assert client.get("/contributions", params=params).status_code == 422


# -- duplicate candidates -----------------------------------------------------


def test_beer_duplicate_candidates_response_has_exactly_the_documented_keys(
    client, authenticated, service
):
    response = client.get("/beer-contributions/duplicate-candidates", params=_BEER_CHECK)

    assert response.status_code == 200
    assert set(response.json()) == {
        "barcode_match",
        "name_matches",
        "brewery_matches",
        "already_submitted",
        "pending_barcode_duplicate_exists",
    }


def test_pending_barcode_flag_is_returned_as_a_plain_boolean_and_is_not_an_error(
    client, authenticated, service
):
    service.pending_barcode_duplicate_exists = True

    response = client.get(
        "/beer-contributions/duplicate-candidates",
        params={**_BEER_CHECK, "barcode": "4006381333931"},
    )

    assert response.status_code == 200
    assert response.json()["pending_barcode_duplicate_exists"] is True


def test_beer_duplicate_candidates_owner_comes_only_from_the_jwt(client, authenticated_as, service):
    authenticated_as(_USER_B)
    client.get("/beer-contributions/duplicate-candidates", params=_BEER_CHECK)
    assert service.calls[0][:2] == ("beer_duplicate_candidates", _USER_B)


def test_beer_duplicate_candidates_canonicalize_the_barcode(client, authenticated, service):
    client.get(
        "/beer-contributions/duplicate-candidates",
        params={**_BEER_CHECK, "barcode": "036000291452"},
    )
    assert service.calls[0][2].barcode == "0036000291452"


@pytest.mark.parametrize(
    "params",
    [
        {"official_name": "Hazy IPA"},  # no brewery at all
        {**_BEER_CHECK, "proposed_brewery_name": "Both"},
        {"brewery_id": _BREWERY_ID},  # no name
        {**_BEER_CHECK, "barcode": "4006381333932"},
        {**_BEER_CHECK, "user_id": _USER_B},  # extra="forbid" on the query model
    ],
)
def test_beer_duplicate_candidates_invalid_queries_are_422(client, authenticated, service, params):
    response = client.get("/beer-contributions/duplicate-candidates", params=params)

    assert response.status_code == 422
    assert service.calls == []


def test_brewery_duplicate_candidates(client, authenticated, service):
    response = client.get("/brewery-contributions/duplicate-candidates", params=_BREWERY_CHECK)

    assert response.status_code == 200
    assert set(response.json()) == {"name_matches", "already_submitted"}


@pytest.mark.parametrize(
    "params",
    [{"name": "Hop House"}, {**_BREWERY_CHECK, "proposed_country_name": "Both"}],
)
def test_brewery_duplicate_candidates_invalid_queries_are_422(
    client, authenticated, service, params
):
    response = client.get("/brewery-contributions/duplicate-candidates", params=params)

    assert response.status_code == 422
    assert service.calls == []


def test_uuid_typed_ids_are_parsed_at_the_route(client, authenticated, service):
    client.post("/beer-contributions", json=_BEER_BODY)
    assert service.calls[0][2].brewery_id == UUID(_BREWERY_ID)
