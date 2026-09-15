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
