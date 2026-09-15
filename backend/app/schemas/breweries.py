from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BreweryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    country_id: UUID
    region: str | None
    city: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    description: str | None
    website: str | None
    logo_url: str | None
    verified: bool
    source: str | None
    created_at: datetime
    updated_at: datetime
