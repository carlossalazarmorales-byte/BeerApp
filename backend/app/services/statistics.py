from app.repositories.statistics import StatisticsRepository
from app.schemas.statistics import (
    AmountSpentByCurrency,
    MonthlyActivityPoint,
    StatisticsOut,
    YearlyActivityPoint,
)


class StatisticsService:
    def __init__(self, repository: StatisticsRepository) -> None:
        self._repository = repository

    async def get_statistics(self, *, user_id: str) -> StatisticsOut:
        data = await self._repository.get_statistics(user_id=user_id)
        overview = data["overview"]
        favorites = data["favorites"]
        average_rating = overview["average_rating"]
        return StatisticsOut(
            total_unique_beers=overview["total_unique_beers"],
            total_logs=overview["total_logs"],
            countries_discovered=overview["countries_discovered"],
            styles_discovered=overview["styles_discovered"],
            breweries_discovered=overview["breweries_discovered"],
            # asyncpg returns avg(smallint) as a Decimal; converted to float
            # here since StatisticsOut.average_rating isn't money-precision.
            average_rating=float(average_rating) if average_rating is not None else None,
            amount_spent=[
                AmountSpentByCurrency.model_validate(dict(row)) for row in data["amount_spent"]
            ],
            monthly_activity=[
                MonthlyActivityPoint.model_validate(dict(row)) for row in data["monthly_activity"]
            ],
            yearly_activity=[
                YearlyActivityPoint.model_validate(dict(row)) for row in data["yearly_activity"]
            ],
            favorite_style=favorites["favorite_style"],
            favorite_country=favorites["favorite_country"],
            favorite_brewery=favorites["favorite_brewery"],
        )
