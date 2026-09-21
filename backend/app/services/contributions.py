import asyncpg

from app.errors import ConflictError, NotFoundError, SessionInvalidError
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.contributions import ContributionRepository
from app.schemas.beers import BeerOut
from app.schemas.breweries import BreweryOut
from app.schemas.common import Page
from app.schemas.contributions import (
    BeerContributionCreate,
    BeerContributionOut,
    BeerDuplicateCandidatesOut,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryContributionOut,
    BreweryDuplicateCandidatesOut,
    BreweryDuplicateCheckQuery,
    ContributionSummaryOut,
)
from app.services.db_errors import is_user_foreign_key

# Enough to show a user "did you mean one of these?" without turning the
# duplicate check into a second search endpoint.
_CANDIDATE_LIMIT = 5

# The only unique indexes on the contribution tables besides the primary key
# are the own-duplicate guards, so a UniqueViolationError on any of these
# means "you already submitted this".
_OWN_DUPLICATE_INDEXES = frozenset(
    {
        "beer_contributions_own_pending_brewery_uidx",
        "beer_contributions_own_pending_proposed_brewery_uidx",
        "brewery_contributions_own_pending_country_uidx",
        "brewery_contributions_own_pending_proposed_country_uidx",
    }
)

# Which catalog entity a failed foreign key referred to -- maps to a 404 like
# BeerLogService does for beer_id. user_id_fkey / resolved_*_fkey are
# deliberately absent: those are not client-referenceable, so they stay
# unexpected errors (500) rather than being misreported as "not found".
_FOREIGN_KEY_ENTITY = {
    "beer_contributions_brewery_id_fkey": "Brewery",
    "beer_contributions_style_id_fkey": "Beer style",
    "brewery_contributions_country_id_fkey": "Country",
}


def _already_submitted() -> ConflictError:
    return ConflictError(
        "already_submitted", "You already have an identical suggestion pending review."
    )


class ContributionService:
    """User-submitted proposals for catalog growth (Phase 13).

    A contribution is NOT a catalog row. Nothing here writes public.beers,
    public.breweries, public.beer_styles or public.countries -- the injected
    catalog repositories are used for reads only, and the contribution
    repository has no catalog write method. Approval into the canonical
    catalog is a future, privileged, moderator-only step that does not exist
    yet (see docs/DECISIONS.md).
    """

    def __init__(
        self,
        repository: ContributionRepository,
        beers: BeerRepository,
        breweries: BreweryRepository,
    ) -> None:
        self._repository = repository
        self._beers = beers
        self._breweries = breweries

    async def submit_beer(
        self, *, user_id: str, payload: BeerContributionCreate
    ) -> BeerContributionOut:
        if payload.barcode is not None:
            # A UX guard, not the invariant: beers_barcode_unique_idx is the
            # real one, and a future approval step re-checks it inside its own
            # transaction. Hard block -- never create a second owner of a code.
            if await self._beers.get_by_barcode(payload.barcode) is not None:
                raise ConflictError(
                    "barcode_in_catalog", "A beer with this barcode is already in the catalog."
                )

        try:
            row = await self._repository.create_beer(
                user_id=user_id,
                official_name=payload.official_name,
                brewery_id=_uuid_or_none(payload.brewery_id),
                proposed_brewery_name=payload.proposed_brewery_name,
                style_id=_uuid_or_none(payload.style_id),
                proposed_style_name=payload.proposed_style_name,
                abv=payload.abv,
                barcode=payload.barcode,
            )
        except asyncpg.UniqueViolationError as exc:
            raise _translate_unique_violation(exc) from exc
        except asyncpg.ForeignKeyViolationError as exc:
            raise _translate_foreign_key_violation(exc, payload) from exc
        return BeerContributionOut.model_validate(dict(row))

    async def submit_brewery(
        self, *, user_id: str, payload: BreweryContributionCreate
    ) -> BreweryContributionOut:
        try:
            row = await self._repository.create_brewery(
                user_id=user_id,
                name=payload.name,
                country_id=_uuid_or_none(payload.country_id),
                proposed_country_name=payload.proposed_country_name,
                region=payload.region,
                city=payload.city,
            )
        except asyncpg.UniqueViolationError as exc:
            raise _translate_unique_violation(exc) from exc
        except asyncpg.ForeignKeyViolationError as exc:
            raise _translate_foreign_key_violation(exc, payload) from exc
        return BreweryContributionOut.model_validate(dict(row))

    async def list_history(
        self, *, user_id: str, page: int, page_size: int
    ) -> Page[ContributionSummaryOut]:
        rows, total = await self._repository.list_history(
            user_id=user_id, page=page, page_size=page_size
        )
        return Page[ContributionSummaryOut](
            items=[ContributionSummaryOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def beer_duplicate_candidates(
        self, *, user_id: str, query: BeerDuplicateCheckQuery
    ) -> BeerDuplicateCandidatesOut:
        brewery_id = _uuid_or_none(query.brewery_id)

        barcode_match: BeerOut | None = None
        pending_barcode_duplicate_exists = False
        if query.barcode is not None:
            row = await self._beers.get_by_barcode(query.barcode)
            if row is not None:
                barcode_match = BeerOut.model_validate(dict(row))
            else:
                # Only meaningful when the catalog doesn't already own the
                # code -- a canonical match is a hard block by itself.
                pending_barcode_duplicate_exists = (
                    await self._repository.other_user_pending_barcode_exists(
                        user_id=user_id, barcode=query.barcode
                    )
                )

        beer_rows = await self._beers.find_by_name_and_brewery(
            name=query.official_name,
            brewery_id=brewery_id,
            brewery_name=query.proposed_brewery_name,
            limit=_CANDIDATE_LIMIT,
        )
        brewery_rows = (
            await self._breweries.find_by_name(
                name=query.proposed_brewery_name, country_id=None, limit=_CANDIDATE_LIMIT
            )
            if query.proposed_brewery_name is not None
            else []
        )
        already_submitted = await self._repository.has_own_pending_beer(
            user_id=user_id,
            official_name=query.official_name,
            brewery_id=brewery_id,
            proposed_brewery_name=query.proposed_brewery_name,
        )

        return BeerDuplicateCandidatesOut(
            barcode_match=barcode_match,
            name_matches=[BeerOut.model_validate(dict(row)) for row in beer_rows],
            brewery_matches=[BreweryOut.model_validate(dict(row)) for row in brewery_rows],
            already_submitted=already_submitted,
            pending_barcode_duplicate_exists=pending_barcode_duplicate_exists,
        )

    async def brewery_duplicate_candidates(
        self, *, user_id: str, query: BreweryDuplicateCheckQuery
    ) -> BreweryDuplicateCandidatesOut:
        country_id = _uuid_or_none(query.country_id)
        # A brewery whose country isn't in the catalog can't already be in
        # the catalog under that country, so there is nothing to compare.
        rows = (
            await self._breweries.find_by_name(
                name=query.name, country_id=country_id, limit=_CANDIDATE_LIMIT
            )
            if country_id is not None
            else []
        )
        already_submitted = await self._repository.has_own_pending_brewery(
            user_id=user_id,
            name=query.name,
            country_id=country_id,
            proposed_country_name=query.proposed_country_name,
        )
        return BreweryDuplicateCandidatesOut(
            name_matches=[BreweryOut.model_validate(dict(row)) for row in rows],
            already_submitted=already_submitted,
        )


def _uuid_or_none(value) -> str | None:
    return str(value) if value is not None else None


def _translate_unique_violation(exc: asyncpg.UniqueViolationError) -> Exception:
    if exc.constraint_name in _OWN_DUPLICATE_INDEXES:
        return _already_submitted()
    # Anything else is not a state this service knows how to explain.
    return exc


def _translate_foreign_key_violation(
    exc: asyncpg.ForeignKeyViolationError,
    payload: BeerContributionCreate | BreweryContributionCreate,
) -> Exception:
    if is_user_foreign_key(exc):
        # The caller's own account is gone (a still-valid token for a deleted
        # user): the same 401 a bad token gets, not a 404 and not a 500.
        return SessionInvalidError()
    entity = _FOREIGN_KEY_ENTITY.get(exc.constraint_name or "")
    if entity is None:
        return exc
    referenced = {
        "Brewery": getattr(payload, "brewery_id", None),
        "Beer style": getattr(payload, "style_id", None),
        "Country": getattr(payload, "country_id", None),
    }[entity]
    return NotFoundError(f"{entity} {referenced} not found")
