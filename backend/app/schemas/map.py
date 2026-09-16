from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel


class MapBeerOut(BaseModel):
    """Self-sufficient beer marker for the map's preview card -- no field
    here should ever require a follow-up request. `latitude`/`longitude` are
    the beer's own coordinate pair if both are set, otherwise its brewery's
    pair (see MapRepository) -- never a mix of one table's latitude with the
    other's longitude. `country_name`/`region` mirror that same
    beer-then-brewery fallback for display only, independent of which pair
    backs the coordinates. Full beer detail (description, ABV, image, ...)
    is only fetched if the user taps "View details".
    """

    beer_id: UUID
    official_name: str
    brewery_name: str
    latitude: Decimal
    longitude: Decimal
    country_name: str | None
    region: str | None
    is_tried: bool
    is_favorite: bool
    is_wishlist: bool


class MapBreweryOut(BaseModel):
    """Self-sufficient brewery marker for the map's preview card. No
    personal-state fields -- breweries have no favorite/wishlist/tried
    concept (see docs/DATA_MODEL rule: personal state lives only on
    beer-scoped entities)."""

    brewery_id: UUID
    name: str
    latitude: Decimal
    longitude: Decimal
    country_name: str | None
    city: str | None
    region: str | None
    description: str | None
    website: str | None
    verified: bool


class CappedList[T](BaseModel):
    """Wraps an unpaginated-but-safety-capped map response. `truncated=True`
    means the server-side cap was hit and `items` is not the complete result
    -- the client must surface that rather than treating the returned set
    (or any camera-fit computed from it) as complete. This cap is a Phase 8
    safety backstop, not real pagination -- see docs/DECISIONS.md; viewport/
    bounding-box querying is the actual future scale solution."""

    items: list[T]
    truncated: bool
