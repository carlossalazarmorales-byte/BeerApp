from app.repositories.beer_styles import BeerStyleRepository
from app.schemas.beer_styles import BeerStyleOut


class BeerStyleService:
    def __init__(self, repository: BeerStyleRepository) -> None:
        self._repository = repository

    async def list_beer_styles(self) -> list[BeerStyleOut]:
        rows = await self._repository.list_all()
        return [BeerStyleOut.model_validate(dict(row)) for row in rows]
