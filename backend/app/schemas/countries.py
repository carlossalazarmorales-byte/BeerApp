from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CountryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    iso_code: str
    name: str
    continent: str
    created_at: datetime
    updated_at: datetime
