from app.errors import NotFoundError
from app.repositories.breweries import BreweryRepository
from app.schemas.breweries import BreweryOut
from app.schemas.common import Page


class BreweryService:
    def __init__(self, repository: BreweryRepository) -> None:
        self._repository = repository

    async def list_breweries(
        self, *, country_id: str | None, page: int, page_size: int
    ) -> Page[BreweryOut]:
        rows, total = await self._repository.list_paginated(
            country_id=country_id, page=page, page_size=page_size
        )
        return Page[BreweryOut](
            items=[BreweryOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def get_brewery(self, brewery_id: str) -> BreweryOut:
        row = await self._repository.get_by_id(brewery_id)
        if row is None:
            raise NotFoundError(f"Brewery {brewery_id} not found")
        return BreweryOut.model_validate(dict(row))
