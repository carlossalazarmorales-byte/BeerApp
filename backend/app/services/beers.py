from app.errors import NotFoundError
from app.repositories.beers import BeerRepository
from app.schemas.beers import BeerOut
from app.schemas.common import Page


class BeerService:
    def __init__(self, repository: BeerRepository) -> None:
        self._repository = repository

    async def list_beers(
        self,
        *,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        q: str | None = None,
        page: int,
        page_size: int,
    ) -> Page[BeerOut]:
        # Normalized here, not trusted from the caller: surrounding whitespace
        # is stripped and a whitespace-only query is treated as "no search"
        # rather than reaching the repository as an empty/blank ILIKE term.
        normalized_q = q.strip() if q is not None else None
        if not normalized_q:
            normalized_q = None

        rows, total = await self._repository.list_paginated(
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            q=normalized_q,
            page=page,
            page_size=page_size,
        )
        return Page[BeerOut](
            items=[BeerOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def get_beer(self, beer_id: str) -> BeerOut:
        row = await self._repository.get_by_id(beer_id)
        if row is None:
            raise NotFoundError(f"Beer {beer_id} not found")
        return BeerOut.model_validate(dict(row))
