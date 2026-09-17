from datetime import date
from decimal import Decimal

from app.schemas.statistics import (
    AmountSpentByCurrency,
    MonthlyActivityPoint,
    StatisticsOut,
    YearlyActivityPoint,
)


def _full_statistics_dict() -> dict:
    return {
        "total_unique_beers": 5,
        "total_logs": 7,
        "countries_discovered": 3,
        "styles_discovered": 4,
        "breweries_discovered": 5,
        "average_rating": 3.6666666667,
        "amount_spent": [{"currency": "USD", "total": Decimal("12.50")}],
        "monthly_activity": [{"month": date(2026, 9, 1), "log_count": 2}],
        "yearly_activity": [{"year": 2026, "log_count": 7}],
        "favorite_style": "IPA",
        "favorite_country": "Ireland",
        "favorite_brewery": "Test Brewery",
    }


def test_statistics_out_validates_a_fully_populated_dict():
    stats = StatisticsOut.model_validate(_full_statistics_dict())

    assert stats.total_logs == 7
    assert stats.amount_spent[0].currency == "USD"
    assert stats.favorite_style == "IPA"


def test_statistics_out_validates_zero_favorites_as_none():
    payload = _full_statistics_dict()
    payload.update(favorite_style=None, favorite_country=None, favorite_brewery=None)

    stats = StatisticsOut.model_validate(payload)

    assert stats.favorite_style is None
    assert stats.favorite_country is None
    assert stats.favorite_brewery is None


def test_statistics_out_average_rating_none_when_no_rated_logs():
    payload = _full_statistics_dict()
    payload["average_rating"] = None

    stats = StatisticsOut.model_validate(payload)

    assert stats.average_rating is None


def test_amount_spent_decimal_total_serializes_as_json_string():
    amount = AmountSpentByCurrency(currency="USD", total=Decimal("12.50"))

    dumped = amount.model_dump(mode="json")

    assert dumped["total"] == "12.50"
    assert isinstance(dumped["total"], str)


def test_monthly_activity_point_field_types():
    point = MonthlyActivityPoint(month=date(2026, 1, 1), log_count=0)

    assert point.month == date(2026, 1, 1)
    assert point.log_count == 0


def test_yearly_activity_point_field_types():
    point = YearlyActivityPoint(year=2025, log_count=3)

    assert point.year == 2025
    assert point.log_count == 3
