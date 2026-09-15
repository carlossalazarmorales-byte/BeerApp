from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BeerStyleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    category: str | None
    description: str | None
    origin_country_id: UUID | None
    typical_abv_min: Decimal | None
    typical_abv_max: Decimal | None
    created_at: datetime
    updated_at: datetime
