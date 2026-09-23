from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BeerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    official_name: str
    brewery_id: UUID
    style_id: UUID | None
    country_id: UUID | None
    region: str | None
    city: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    abv: Decimal | None
    ibu: int | None
    description: str | None
    image_url: str | None
    barcode: str | None
    verified: bool
    source: str | None
    created_at: datetime
    updated_at: datetime


class BeerCatalogOut(BeerOut):
    """`GET /beers` list response shape -- `BeerOut` plus the requesting
    user's per-beer `is_tried` state (Discover and Add Beer both call this
    endpoint; the flag lets each screen decide its own locked/unlocked
    presentation from the same response). Never added to `BeerOut` itself or
    to the `beers` table -- see CLAUDE.md's Data Model Rule and the identical
    precedent in `schemas/map.py`'s `MapBeerOut.is_tried`.
    """

    is_tried: bool
