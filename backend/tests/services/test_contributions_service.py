import asyncio
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

import asyncpg
import pytest

from app.errors import ConflictError, NotFoundError, SessionInvalidError
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.contributions import ContributionRepository
from app.schemas.contributions import (
    BeerContributionCreate,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryDuplicateCheckQuery,
)
from app.services.contributions import ContributionService

_NOW = datetime.now(UTC)
_USER = "11111111-1111-1111-1111-111111111111"
_BREWERY_ID = UUID("44444444-4444-4444-4444-444444444444")
_STYLE_ID = UUID("55555555-5555-5555-5555-555555555555")
_COUNTRY_ID = UUID("66666666-6666-6666-6666-666666666666")
_BARCODE = "4006381333931"


def _run(coro):
    return asyncio.run(coro)


def _beer_row(**overrides) -> dict:
    row = {
        "id": uuid4(),
        "official_name": "Hazy IPA",
        "brewery_id": _BREWERY_ID,
        "proposed_brewery_name": None,
        "style_id": None,
        "proposed_style_name": None,
        "abv": None,
        "barcode": None,
        "status": "pending",
        "created_at": _NOW,
    }
    row.update(overrides)
    return row


def _brewery_row(**overrides) -> dict:
    row = {
        "id": uuid4(),
        "name": "Hop House",
        "country_id": _COUNTRY_ID,
        "proposed_country_name": None,
        "region": None,
        "city": None,
        "status": "pending",
        "created_at": _NOW,
    }
    row.update(overrides)
    return row


def _canonical_beer(**overrides) -> dict:
    row = {
        "id": uuid4(),
        "official_name": "Hazy IPA",
        "brewery_id": _BREWERY_ID,
        "style_id": None,
        "country_id": None,
        "region": None,
        "city": None,
        "latitude": None,
        "longitude": None,
        "abv": Decimal("6.5"),
        "ibu": None,
        "description": None,
        "image_url": None,
        "barcode": None,
        "verified": True,
        "source": "dev-seed",
        "created_at": _NOW,
        "updated_at": _NOW,
    }
    row.update(overrides)
    return row


def _canonical_brewery(**overrides) -> dict:
    row = {
        "id": _BREWERY_ID,
        "name": "Hop House",
        "country_id": _COUNTRY_ID,
        "region": None,
        "city": None,
        "latitude": None,
        "longitude": None,
        "description": None,
        "website": None,
        "logo_url": None,
        "verified": True,
        "source": "dev-seed",
        "created_at": _NOW,
        "updated_at": _NOW,
    }
    row.update(overrides)
    return row


class _FakeContributionRepository:
    def __init__(self) -> None:
        self.create_beer_calls: list[dict] = []
        self.create_brewery_calls: list[dict] = []
        self.create_error: Exception | None = None
        self.history: tuple[list[dict], int] = ([], 0)
        self.own_pending_beer = False
        self.own_pending_brewery = False
        self.other_user_pending_barcode = False
        self.pending_barcode_calls: list[dict] = []
        self.own_pending_beer_calls: list[dict] = []
        self.own_pending_brewery_calls: list[dict] = []

    async def create_beer(self, **kwargs) -> dict:
        self.create_beer_calls.append(kwargs)
        if self.create_error is not None:
            raise self.create_error
        return _beer_row(**{k: v for k, v in kwargs.items() if k != "user_id"})

    async def create_brewery(self, **kwargs) -> dict:
        self.create_brewery_calls.append(kwargs)
        if self.create_error is not None:
            raise self.create_error
        return _brewery_row(**{k: v for k, v in kwargs.items() if k != "user_id"})

    async def list_history(self, *, user_id: str, page: int, page_size: int):
        return self.history

    async def has_own_pending_beer(self, **kwargs) -> bool:
        self.own_pending_beer_calls.append(kwargs)
        return self.own_pending_beer

    async def has_own_pending_brewery(self, **kwargs) -> bool:
        self.own_pending_brewery_calls.append(kwargs)
        return self.own_pending_brewery

    async def other_user_pending_barcode_exists(self, **kwargs) -> bool:
        self.pending_barcode_calls.append(kwargs)
        return self.other_user_pending_barcode


class _FakeBeers:
    def __init__(self) -> None:
        self.barcode_owner: dict | None = None
        self.name_matches: list[dict] = []
        self.barcode_calls: list[str] = []
        self.name_calls: list[dict] = []

    async def get_by_barcode(self, barcode: str):
        self.barcode_calls.append(barcode)
        return self.barcode_owner

    async def find_by_name_and_brewery(self, **kwargs):
        self.name_calls.append(kwargs)
        return self.name_matches


class _FakeBreweries:
    def __init__(self) -> None:
        self.name_matches: list[dict] = []
        self.name_calls: list[dict] = []

    async def find_by_name(self, **kwargs):
        self.name_calls.append(kwargs)
        return self.name_matches


def _service():
    repository, beers, breweries = _FakeContributionRepository(), _FakeBeers(), _FakeBreweries()
    return ContributionService(repository, beers, breweries), repository, beers, breweries


def _pg_error(cls, constraint_name: str) -> Exception:
    error = cls("simulated")
    error.constraint_name = constraint_name
    return error


# -- the service can only ever propose, never write the catalog ---------------


def test_catalog_repositories_used_for_duplicate_checks_are_read_only():
    forbidden = ("create", "insert", "update", "delete", "upsert", "set_", "remove")
    for repository in (BeerRepository, BreweryRepository):
        public = [name for name in vars(repository) if not name.startswith("_")]
        assert not [n for n in public if n.startswith(forbidden)], (repository, public)


def test_contribution_repository_has_no_update_or_delete_methods():
    public = [name for name in vars(ContributionRepository) if not name.startswith("_")]
    assert not [n for n in public if n.startswith(("update", "delete", "approve", "reject"))]


# -- submit_beer --------------------------------------------------------------


def test_submit_beer_stores_a_pending_normalized_suggestion_for_the_caller():
    service, repository, beers, _ = _service()
    payload = BeerContributionCreate(
        official_name="  Hazy   IPA ",
        brewery_id=_BREWERY_ID,
        style_id=_STYLE_ID,
        abv="6.5",
        barcode="036000291452",
    )

    result = _run(service.submit_beer(user_id=_USER, payload=payload))

    assert result.status == "pending"
    (call,) = repository.create_beer_calls
    assert call["user_id"] == _USER
    assert call["official_name"] == "Hazy IPA"
    # UUIDs are passed to the repository as strings, like BeerLogService does.
    assert call["brewery_id"] == str(_BREWERY_ID)
    assert call["style_id"] == str(_STYLE_ID)
    assert call["abv"] == Decimal("6.5")
    assert call["barcode"] == "0036000291452"
    assert beers.barcode_calls == ["0036000291452"]


def test_submit_beer_with_a_proposed_brewery_and_style_passes_the_free_text_through():
    service, repository, _, _ = _service()
    payload = BeerContributionCreate(
        official_name="Hazy IPA",
        proposed_brewery_name="Brand New Brewery",
        proposed_style_name="Weird Style",
    )

    _run(service.submit_beer(user_id=_USER, payload=payload))

    (call,) = repository.create_beer_calls
    assert call["brewery_id"] is None
    assert call["proposed_brewery_name"] == "Brand New Brewery"
    assert call["style_id"] is None
    assert call["proposed_style_name"] == "Weird Style"


def test_submit_beer_without_a_barcode_never_queries_the_catalog_barcode():
    service, _, beers, _ = _service()
    _run(
        service.submit_beer(
            user_id=_USER,
            payload=BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID),
        )
    )
    assert beers.barcode_calls == []


def test_submit_beer_with_a_barcode_already_in_the_catalog_is_a_hard_conflict():
    service, repository, beers, _ = _service()
    beers.barcode_owner = _canonical_beer(barcode=_BARCODE)
    payload = BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID, barcode=_BARCODE)

    with pytest.raises(ConflictError) as raised:
        _run(service.submit_beer(user_id=_USER, payload=payload))

    assert raised.value.code == "barcode_in_catalog"
    # Nothing was written.
    assert repository.create_beer_calls == []


@pytest.mark.parametrize(
    "index",
    [
        "beer_contributions_own_pending_brewery_uidx",
        "beer_contributions_own_pending_proposed_brewery_uidx",
    ],
)
def test_submit_beer_own_duplicate_is_a_hard_conflict(index):
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(asyncpg.UniqueViolationError, index)

    with pytest.raises(ConflictError) as raised:
        _run(
            service.submit_beer(
                user_id=_USER,
                payload=BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID),
            )
        )
    assert raised.value.code == "already_submitted"


def test_submit_beer_does_not_disguise_an_unknown_unique_violation():
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(asyncpg.UniqueViolationError, "something_else")

    with pytest.raises(asyncpg.UniqueViolationError):
        _run(
            service.submit_beer(
                user_id=_USER,
                payload=BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID),
            )
        )


@pytest.mark.parametrize(
    ("constraint", "fields", "expected"),
    [
        ("beer_contributions_brewery_id_fkey", {"brewery_id": _BREWERY_ID}, "Brewery"),
        (
            "beer_contributions_style_id_fkey",
            {"brewery_id": _BREWERY_ID, "style_id": _STYLE_ID},
            "Beer style",
        ),
    ],
)
def test_submit_beer_unknown_catalog_reference_is_not_found(constraint, fields, expected):
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(asyncpg.ForeignKeyViolationError, constraint)

    with pytest.raises(NotFoundError, match=expected):
        _run(
            service.submit_beer(
                user_id=_USER, payload=BeerContributionCreate(official_name="X", **fields)
            )
        )


def test_submit_beer_reports_a_deleted_account_as_session_invalid_not_not_found():
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(
        asyncpg.ForeignKeyViolationError, "beer_contributions_user_id_fkey"
    )
    with pytest.raises(SessionInvalidError):
        _run(
            service.submit_beer(
                user_id=_USER,
                payload=BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID),
            )
        )


# -- submit_brewery -----------------------------------------------------------


def test_submit_brewery_stores_a_pending_suggestion_for_the_caller():
    service, repository, _, _ = _service()
    payload = BreweryContributionCreate(
        name=" Hop  House ", country_id=_COUNTRY_ID, region="Bavaria", city="Munich"
    )

    result = _run(service.submit_brewery(user_id=_USER, payload=payload))

    assert result.status == "pending"
    (call,) = repository.create_brewery_calls
    assert call == {
        "user_id": _USER,
        "name": "Hop House",
        "country_id": str(_COUNTRY_ID),
        "proposed_country_name": None,
        "region": "Bavaria",
        "city": "Munich",
    }


def test_submit_brewery_with_a_proposed_country_never_needs_a_catalog_country():
    service, repository, _, _ = _service()
    _run(
        service.submit_brewery(
            user_id=_USER,
            payload=BreweryContributionCreate(name="X", proposed_country_name="Atlantis"),
        )
    )
    (call,) = repository.create_brewery_calls
    assert call["country_id"] is None
    assert call["proposed_country_name"] == "Atlantis"


def test_submit_brewery_own_duplicate_is_a_hard_conflict():
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(
        asyncpg.UniqueViolationError, "brewery_contributions_own_pending_country_uidx"
    )
    with pytest.raises(ConflictError) as raised:
        _run(
            service.submit_brewery(
                user_id=_USER,
                payload=BreweryContributionCreate(name="X", country_id=_COUNTRY_ID),
            )
        )
    assert raised.value.code == "already_submitted"


def test_submit_brewery_unknown_country_is_not_found():
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(
        asyncpg.ForeignKeyViolationError, "brewery_contributions_country_id_fkey"
    )
    with pytest.raises(NotFoundError, match="Country"):
        _run(
            service.submit_brewery(
                user_id=_USER,
                payload=BreweryContributionCreate(name="X", country_id=_COUNTRY_ID),
            )
        )


# -- history ------------------------------------------------------------------


def test_list_history_wraps_rows_in_a_page():
    service, repository, _, _ = _service()
    repository.history = (
        [
            {
                "kind": "beer",
                "id": uuid4(),
                "title": "Hazy IPA",
                "status": "pending",
                "created_at": _NOW,
            },
            {
                "kind": "brewery",
                "id": uuid4(),
                "title": "Hop House",
                "status": "pending",
                "created_at": _NOW,
            },
        ],
        2,
    )

    page = _run(service.list_history(user_id=_USER, page=1, page_size=20))

    assert page.total == 2
    assert [item.kind for item in page.items] == ["beer", "brewery"]
    assert page.page == 1 and page.page_size == 20


# -- beer duplicate candidates ------------------------------------------------


def _beer_query(**overrides) -> BeerDuplicateCheckQuery:
    fields = {"official_name": "Hazy IPA", "brewery_id": _BREWERY_ID}
    fields.update(overrides)
    return BeerDuplicateCheckQuery(**fields)


def test_candidates_without_a_barcode_never_ask_about_barcodes():
    service, repository, beers, _ = _service()

    result = _run(service.beer_duplicate_candidates(user_id=_USER, query=_beer_query()))

    assert result.barcode_match is None
    assert result.pending_barcode_duplicate_exists is False
    assert beers.barcode_calls == []
    assert repository.pending_barcode_calls == []


def test_candidates_flag_another_users_pending_barcode_without_blocking():
    service, repository, _, _ = _service()
    repository.other_user_pending_barcode = True

    result = _run(
        service.beer_duplicate_candidates(user_id=_USER, query=_beer_query(barcode=_BARCODE))
    )

    assert result.pending_barcode_duplicate_exists is True
    assert result.barcode_match is None
    assert repository.pending_barcode_calls == [{"user_id": _USER, "barcode": _BARCODE}]


def test_candidates_report_a_canonical_barcode_owner_as_a_hard_match_and_skip_the_flag():
    service, repository, beers, _ = _service()
    beers.barcode_owner = _canonical_beer(barcode=_BARCODE)
    repository.other_user_pending_barcode = True

    result = _run(
        service.beer_duplicate_candidates(user_id=_USER, query=_beer_query(barcode=_BARCODE))
    )

    assert result.barcode_match is not None
    assert result.barcode_match.barcode == _BARCODE
    assert result.pending_barcode_duplicate_exists is False
    assert repository.pending_barcode_calls == []


def test_candidates_pass_the_canonical_brewery_id_and_return_name_matches():
    service, _, beers, breweries = _service()
    beers.name_matches = [_canonical_beer(), _canonical_beer()]

    result = _run(service.beer_duplicate_candidates(user_id=_USER, query=_beer_query()))

    assert len(result.name_matches) == 2
    assert result.brewery_matches == []
    (call,) = beers.name_calls
    assert call["name"] == "Hazy IPA"
    assert call["brewery_id"] == str(_BREWERY_ID)
    assert call["brewery_name"] is None
    assert breweries.name_calls == []  # a canonical brewery needs no brewery lookup


def test_candidates_for_a_proposed_brewery_also_suggest_same_named_breweries():
    service, _, beers, breweries = _service()
    breweries.name_matches = [_canonical_brewery()]

    result = _run(
        service.beer_duplicate_candidates(
            user_id=_USER,
            query=BeerDuplicateCheckQuery(
                official_name="Hazy IPA", proposed_brewery_name="Hop House"
            ),
        )
    )

    assert [b.name for b in result.brewery_matches] == ["Hop House"]
    (call,) = beers.name_calls
    assert call["brewery_id"] is None
    assert call["brewery_name"] == "Hop House"
    assert breweries.name_calls == [{"name": "Hop House", "country_id": None, "limit": 5}]


def test_candidates_report_the_callers_own_identical_pending_suggestion():
    service, repository, _, _ = _service()
    repository.own_pending_beer = True

    result = _run(service.beer_duplicate_candidates(user_id=_USER, query=_beer_query()))

    assert result.already_submitted is True
    assert repository.own_pending_beer_calls[0]["user_id"] == _USER


def test_candidates_result_never_contains_other_users_contribution_data():
    service, repository, _, _ = _service()
    repository.other_user_pending_barcode = True
    result = _run(
        service.beer_duplicate_candidates(user_id=_USER, query=_beer_query(barcode=_BARCODE))
    )
    dumped = result.model_dump()
    assert set(dumped) == {
        "barcode_match",
        "name_matches",
        "brewery_matches",
        "already_submitted",
        "pending_barcode_duplicate_exists",
    }
    assert dumped["pending_barcode_duplicate_exists"] is True


# -- brewery duplicate candidates ---------------------------------------------


def test_brewery_candidates_compare_name_within_the_canonical_country():
    service, _, _, breweries = _service()
    breweries.name_matches = [_canonical_brewery()]

    result = _run(
        service.brewery_duplicate_candidates(
            user_id=_USER,
            query=BreweryDuplicateCheckQuery(name="Hop House", country_id=_COUNTRY_ID),
        )
    )

    assert [b.name for b in result.name_matches] == ["Hop House"]
    assert breweries.name_calls == [
        {"name": "Hop House", "country_id": str(_COUNTRY_ID), "limit": 5}
    ]


def test_brewery_candidates_for_a_proposed_country_have_no_catalog_comparison():
    service, repository, _, breweries = _service()
    repository.own_pending_brewery = True

    result = _run(
        service.brewery_duplicate_candidates(
            user_id=_USER,
            query=BreweryDuplicateCheckQuery(name="Hop House", proposed_country_name="Atlantis"),
        )
    )

    assert result.name_matches == []
    assert result.already_submitted is True
    assert breweries.name_calls == []
    assert repository.own_pending_brewery_calls == [
        {
            "user_id": _USER,
            "name": "Hop House",
            "country_id": None,
            "proposed_country_name": "Atlantis",
        }
    ]


def test_submit_brewery_reports_a_deleted_account_as_session_invalid():
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(
        asyncpg.ForeignKeyViolationError, "brewery_contributions_user_id_fkey"
    )

    with pytest.raises(SessionInvalidError):
        _run(
            service.submit_brewery(
                user_id=_USER,
                payload=BreweryContributionCreate(name="X", country_id=_COUNTRY_ID),
            )
        )


def test_a_resolved_link_fk_failure_is_still_an_unexpected_error():
    # resolved_*_fkey is not client-referenceable and not about the caller's
    # session, so it must neither become a 404 nor a 401.
    service, repository, _, _ = _service()
    repository.create_error = _pg_error(
        asyncpg.ForeignKeyViolationError, "beer_contributions_resolved_beer_id_fkey"
    )

    with pytest.raises(asyncpg.ForeignKeyViolationError):
        _run(
            service.submit_beer(
                user_id=_USER,
                payload=BeerContributionCreate(official_name="X", brewery_id=_BREWERY_ID),
            )
        )
