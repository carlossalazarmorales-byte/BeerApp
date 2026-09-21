from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.common import NO_NUL_PATTERN

# Limits below mirror what the columns can store, not product rules.
# user_beer_logs.price is numeric(10, 2): at most 8 whole digits, 2 decimals.
MAX_PRICE = Decimal("99999999.99")
# user_beer_logs.serving_volume_ml is integer (int4).
MAX_SERVING_VOLUME_ML = 2_147_483_647


def _require_aware_or_none(value: datetime | None) -> datetime | None:
    """A client-supplied consumed_at with no UTC offset would otherwise
    parse into a naive datetime, and comparing that against
    datetime.now(UTC) in the service layer raises TypeError instead of
    failing cleanly. Rejecting a naive value here, at the schema boundary,
    turns that into an ordinary 422 and guarantees every consumed_at that
    reaches the service is timezone-aware.
    """
    if value is not None and value.tzinfo is None:
        raise ValueError("consumed_at must include a UTC offset (timezone-aware).")
    return value


class BeerLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    beer_id: UUID
    rating: int | None
    review: str | None
    consumed_at: datetime
    serving_note: str | None
    price: Decimal | None
    currency: str | None
    venue_name: str | None
    serving_volume_ml: int | None
    created_at: datetime
    updated_at: datetime


class BeerLogCreate(BaseModel):
    # extra="forbid" so a client can never smuggle in e.g. "user_id" -- the
    # owner is always the verified JWT's sub, taken from get_current_user in
    # the route, never from the request body.
    model_config = ConfigDict(extra="forbid")

    beer_id: UUID
    rating: int | None = Field(default=None, ge=1, le=5)
    review: str | None = Field(default=None, max_length=2000, pattern=NO_NUL_PATTERN)
    consumed_at: datetime | None = Field(default=None)
    serving_note: str | None = Field(default=None, max_length=500, pattern=NO_NUL_PATTERN)
    price: Decimal | None = Field(default=None, ge=0, le=MAX_PRICE, max_digits=10, decimal_places=2)
    currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    venue_name: str | None = Field(default=None, max_length=200, pattern=NO_NUL_PATTERN)
    serving_volume_ml: int | None = Field(default=None, gt=0, le=MAX_SERVING_VOLUME_ML)

    @field_validator("consumed_at")
    @classmethod
    def _validate_consumed_at_tz(cls, value: datetime | None) -> datetime | None:
        return _require_aware_or_none(value)

    @model_validator(mode="after")
    def _price_currency_paired(self) -> "BeerLogCreate":
        # Self-contained (CREATE has no prior row state), so this stays a
        # 422 model_validator -- contrast with BeerLogUpdate, where the same
        # pairing must be checked against the existing row (see
        # BeerLogService.update_log), not just the two request fields.
        if (self.price is None) != (self.currency is None):
            raise ValueError("price and currency must both be set or both be omitted.")
        return self


class BeerLogUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    rating: int | None = Field(default=None, ge=1, le=5)
    review: str | None = Field(default=None, max_length=2000, pattern=NO_NUL_PATTERN)
    consumed_at: datetime | None = Field(default=None)
    serving_note: str | None = Field(default=None, max_length=500, pattern=NO_NUL_PATTERN)
    price: Decimal | None = Field(default=None, ge=0, le=MAX_PRICE, max_digits=10, decimal_places=2)
    currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    venue_name: str | None = Field(default=None, max_length=200, pattern=NO_NUL_PATTERN)
    serving_volume_ml: int | None = Field(default=None, gt=0, le=MAX_SERVING_VOLUME_ML)

    @field_validator("consumed_at")
    @classmethod
    def _validate_consumed_at_tz(cls, value: datetime | None) -> datetime | None:
        return _require_aware_or_none(value)

    @model_validator(mode="after")
    def _reject_empty_patch(self) -> "BeerLogUpdate":
        # model_fields_set (not "is every field None") is what distinguishes
        # "omitted" from "explicitly set to null" -- an empty body has
        # nothing in model_fields_set at all.
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")
        return self

    @model_validator(mode="after")
    def _consumed_at_not_nullable(self) -> "BeerLogUpdate":
        # consumed_at is NOT NULL at the DB layer -- explicitly clearing it
        # is rejected here (self-contained, doesn't need existing-row
        # state, unlike the price/currency pairing check in the service).
        if "consumed_at" in self.model_fields_set and self.consumed_at is None:
            raise ValueError("consumed_at cannot be cleared.")
        return self

    # price/currency pairing is deliberately NOT validated on this model --
    # it can only be validated correctly against the row's existing state
    # (see BeerLogService.update_log), which this schema doesn't have.
