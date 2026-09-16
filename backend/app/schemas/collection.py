from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, model_validator


class CollectionStateOut(BaseModel):
    beer_id: UUID
    is_favorite: bool
    is_wishlist: bool


class CollectionStateUpdate(BaseModel):
    # extra="forbid" so a client can never smuggle in e.g. "user_id" -- the
    # owner is always the verified JWT's sub, and beer_id always comes from
    # the path, never the body.
    model_config = ConfigDict(extra="forbid")

    is_favorite: bool | None = None
    is_wishlist: bool | None = None

    @model_validator(mode="after")
    def _reject_empty_patch(self) -> "CollectionStateUpdate":
        # model_fields_set (not "both None") distinguishes "omitted" from
        # "explicitly set" -- an empty body has nothing in model_fields_set.
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")
        return self


class CollectionBeerOut(BaseModel):
    beer_id: UUID
    official_name: str
    brewery_name: str
    style_name: str | None
    country_name: str | None
    image_url: str | None
    abv: Decimal | None
    is_favorite: bool
    is_wishlist: bool
    latest_rating: int | None
    latest_consumed_at: datetime | None
