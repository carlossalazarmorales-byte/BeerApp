from app.repositories.countries import CountryRepository
from app.schemas.countries import CountryOut


class CountryService:
    def __init__(self, repository: CountryRepository) -> None:
        self._repository = repository

    async def list_countries(self) -> list[CountryOut]:
        rows = await self._repository.list_all()
        return [CountryOut.model_validate(dict(row)) for row in rows]
