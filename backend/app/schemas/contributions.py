from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, model_validator

from app.schemas.beers import BeerOut
from app.schemas.breweries import BreweryOut
from app.services.barcode import canonicalize_barcode

ContributionStatus = Literal["pending", "approved", "rejected"]
ContributionKind = Literal["beer", "brewery"]


def _text(max_length: int):
    """A required free-text field: internal whitespace collapsed and edges
    trimmed, then required to be non-blank and within `max_length`. Applied at
    the schema boundary so the stored value, the duplicate-check comparison
    and the database's `lower(btrim(...))` unique indexes all see the same
    normalized form.
    """

    def _validate(value: str) -> str:
        collapsed = " ".join(value.split())
        if not collapsed:
            raise ValueError("must not be blank.")
        if len(collapsed) > max_length:
            raise ValueError(f"must be at most {max_length} characters.")
        return collapsed

    return Annotated[str, AfterValidator(_validate)]


_Text100 = _text(100)
_Text200 = _text(200)

# Reuses Phase 11's canonicalizer (EAN-8/EAN-13/UPC-A -> canonical GTIN, GS1
# check digit, UPC-E rejected) rather than a second validator. A ValueError
# becomes an ordinary 422, exactly as on GET /beers/barcode/{barcode}.
_CanonicalBarcode = Annotated[str, AfterValidator(canonicalize_barcode)]

# numeric(4,2) in the database: 0-99.99, two decimals.
_Abv = Annotated[Decimal, Field(ge=0, le=Decimal("99.99"), max_digits=4, decimal_places=2)]


def _exactly_one(first: object, second: object, message: str) -> None:
    if (first is None) == (second is None):
        raise ValueError(message)


class BeerContributionCreate(BaseModel):
    # extra="forbid": a client can never supply `user_id`, `status`, or any
    # review field -- the owner is the verified JWT's sub and the status is
    # always 'pending', both fixed server-side.
    model_config = ConfigDict(extra="forbid")

    official_name: _Text200
    brewery_id: UUID | None = None
    proposed_brewery_name: _Text200 | None = None
    style_id: UUID | None = None
    proposed_style_name: _Text100 | None = None
    abv: _Abv | None = None
    barcode: _CanonicalBarcode | None = None

    @model_validator(mode="after")
    def _brewery_is_canonical_xor_proposed(self) -> "BeerContributionCreate":
        _exactly_one(
            self.brewery_id,
            self.proposed_brewery_name,
            "Provide exactly one of brewery_id or proposed_brewery_name.",
        )
        return self

    @model_validator(mode="after")
    def _style_is_not_both(self) -> "BeerContributionCreate":
        if self.style_id is not None and self.proposed_style_name is not None:
            raise ValueError("Provide at most one of style_id or proposed_style_name.")
        return self


class BreweryContributionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: _Text200
    country_id: UUID | None = None
    proposed_country_name: _Text100 | None = None
    region: _Text100 | None = None
    city: _Text100 | None = None

    @model_validator(mode="after")
    def _country_is_canonical_xor_proposed(self) -> "BreweryContributionCreate":
        _exactly_one(
            self.country_id,
            self.proposed_country_name,
            "Provide exactly one of country_id or proposed_country_name.",
        )
        return self


class BeerContributionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    # No user_id: a contribution is private to its author, and the author
    # already knows who they are.
    id: UUID
    official_name: str
    brewery_id: UUID | None
    proposed_brewery_name: str | None
    style_id: UUID | None
    proposed_style_name: str | None
    abv: Decimal | None
    barcode: str | None
    status: ContributionStatus
    created_at: datetime


class BreweryContributionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    country_id: UUID | None
    proposed_country_name: str | None
    region: str | None
    city: str | None
    status: ContributionStatus
    created_at: datetime


class ContributionSummaryOut(BaseModel):
    """One row of the caller's own submission history, across both kinds."""

    model_config = ConfigDict(from_attributes=True)

    kind: ContributionKind
    id: UUID
    title: str
    status: ContributionStatus
    created_at: datetime


class BeerDuplicateCheckQuery(BaseModel):
    """Query parameters of GET /beer-contributions/duplicate-candidates --
    the same identifying fields as a submission, validated identically.
    """

    model_config = ConfigDict(extra="forbid")

    official_name: _Text200
    brewery_id: UUID | None = None
    proposed_brewery_name: _Text200 | None = None
    barcode: _CanonicalBarcode | None = None

    @model_validator(mode="after")
    def _brewery_is_canonical_xor_proposed(self) -> "BeerDuplicateCheckQuery":
        _exactly_one(
            self.brewery_id,
            self.proposed_brewery_name,
            "Provide exactly one of brewery_id or proposed_brewery_name.",
        )
        return self


class BreweryDuplicateCheckQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: _Text200
    country_id: UUID | None = None
    proposed_country_name: _Text100 | None = None

    @model_validator(mode="after")
    def _country_is_canonical_xor_proposed(self) -> "BreweryDuplicateCheckQuery":
        _exactly_one(
            self.country_id,
            self.proposed_country_name,
            "Provide exactly one of country_id or proposed_country_name.",
        )
        return self


class BeerDuplicateCandidatesOut(BaseModel):
    """Everything here is either canonical catalog data (already readable by
    any user via /beers and /breweries) or a boolean about the caller's own
    suggestions. It never carries another user's contribution -- no row, id,
    user_id or identity.
    """

    # HARD block: a canonical beer already owns this barcode.
    barcode_match: BeerOut | None
    # Soft warnings: canonical beers that look like the same beer.
    name_matches: list[BeerOut]
    # Soft warning for a proposed brewery: canonical breweries with that name.
    brewery_matches: list[BreweryOut]
    # HARD block: the caller already has an identical pending suggestion.
    already_submitted: bool
    # Soft, non-blocking: ANOTHER user's pending suggestion carries this
    # barcode. Boolean only -- see private.other_user_pending_beer_barcode_exists.
    pending_barcode_duplicate_exists: bool


class BreweryDuplicateCandidatesOut(BaseModel):
    name_matches: list[BreweryOut]
    already_submitted: bool
