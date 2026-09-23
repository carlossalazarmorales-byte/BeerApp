from app.repositories.map import MapRepository
from app.schemas.map import CappedList, MapBeerOut, MapBreweryOut, MapCountryCoverageOut


class MapService:
    def __init__(self, repository: MapRepository) -> None:
        self._repository = repository

    async def list_beers(
        self, *, user_id: str, state: str, country_id: str | None, q: str | None
    ) -> CappedList[MapBeerOut]:
        rows, truncated = await self._repository.list_beers(
            user_id=user_id, state=state, country_id=country_id, q=_normalize_q(q)
        )
        return CappedList[MapBeerOut](
            items=[MapBeerOut.model_validate(dict(row)) for row in rows],
            truncated=truncated,
        )

    async def list_breweries(
        self, *, country_id: str | None, q: str | None
    ) -> CappedList[MapBreweryOut]:
        rows, truncated = await self._repository.list_breweries(
            country_id=country_id, q=_normalize_q(q)
        )
        return CappedList[MapBreweryOut](
            items=[MapBreweryOut.model_validate(dict(row)) for row in rows],
            truncated=truncated,
        )

    async def list_country_coverage(self, *, user_id: str) -> list[MapCountryCoverageOut]:
        rows = await self._repository.list_country_coverage(user_id=user_id)
        return [MapCountryCoverageOut.model_validate(dict(row)) for row in rows]


def _normalize_q(q: str | None) -> str | None:
    # Same normalization as BeerService.list_beers: surrounding whitespace
    # stripped, whitespace-only treated as "no search".
    normalized = q.strip() if q is not None else None
    return normalized or None
