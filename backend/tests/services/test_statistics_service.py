import asyncio
from decimal import Decimal

from app.services.statistics import StatisticsService

_USER_ID = "11111111-1111-1111-1111-111111111111"


def _repository_result(**overrides) -> dict:
    result = {
        "overview": {
            "total_logs": 0,
            "total_unique_beers": 0,
            "average_rating": None,
            "countries_discovered": 0,
            "styles_discovered": 0,
            "breweries_discovered": 0,
        },
        "amount_spent": [],
        "monthly_activity": [],
        "yearly_activity": [],
        "favorites": {
            "favorite_style": None,
            "favorite_country": None,
            "favorite_brewery": None,
        },
    }
    result.update(overrides)
    return result


class _FakeStatisticsRepository:
    def __init__(self) -> None:
        self.result: dict = _repository_result()

    async def get_statistics(self, *, user_id: str) -> dict:
        return self.result


def _run(coro):
    return asyncio.run(coro)


def test_overview_counts_pass_through_unchanged():
    repository = _FakeStatisticsRepository()
    repository.result = _repository_result(
        overview={
            "total_logs": 7,
            "total_unique_beers": 5,
            "average_rating": None,
            "countries_discovered": 3,
            "styles_discovered": 4,
            "breweries_discovered": 5,
        }
    )
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert stats.total_logs == 7
    assert stats.total_unique_beers == 5
    assert stats.countries_discovered == 3
    assert stats.styles_discovered == 4
    assert stats.breweries_discovered == 5


def test_average_rating_is_none_when_repository_returns_none():
    repository = _FakeStatisticsRepository()
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert stats.average_rating is None


def test_average_rating_decimal_is_converted_to_float():
    repository = _FakeStatisticsRepository()
    repository.result = _repository_result(
        overview={
            "total_logs": 3,
            "total_unique_beers": 3,
            "average_rating": Decimal("3.6666666667"),
            "countries_discovered": 1,
            "styles_discovered": 1,
            "breweries_discovered": 1,
        }
    )
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert isinstance(stats.average_rating, float)
    assert abs(stats.average_rating - 3.6666666667) < 1e-6


def test_amount_spent_list_mapping_preserves_order_and_totals():
    repository = _FakeStatisticsRepository()
    repository.result = _repository_result(
        amount_spent=[
            {"currency": "EUR", "total": Decimal("5.00")},
            {"currency": "USD", "total": Decimal("12.50")},
        ]
    )
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert [(a.currency, a.total) for a in stats.amount_spent] == [
        ("EUR", Decimal("5.00")),
        ("USD", Decimal("12.50")),
    ]


def test_monthly_and_yearly_activity_list_mapping():
    from datetime import date

    repository = _FakeStatisticsRepository()
    repository.result = _repository_result(
        monthly_activity=[{"month": date(2026, 9, 1), "log_count": 2}],
        yearly_activity=[{"year": 2026, "log_count": 7}],
    )
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert stats.monthly_activity[0].month == date(2026, 9, 1)
    assert stats.monthly_activity[0].log_count == 2
    assert stats.yearly_activity[0].year == 2026
    assert stats.yearly_activity[0].log_count == 7


def test_zero_favorites_passthrough_end_to_end():
    repository = _FakeStatisticsRepository()
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert stats.favorite_style is None
    assert stats.favorite_country is None
    assert stats.favorite_brewery is None


def test_non_null_favorites_passthrough():
    repository = _FakeStatisticsRepository()
    repository.result = _repository_result(
        favorites={
            "favorite_style": "IPA",
            "favorite_country": "Ireland",
            "favorite_brewery": "Test Brewery",
        }
    )
    service = StatisticsService(repository)

    stats = _run(service.get_statistics(user_id=_USER_ID))

    assert stats.favorite_style == "IPA"
    assert stats.favorite_country == "Ireland"
    assert stats.favorite_brewery == "Test Brewery"
