from datetime import date

from app.dependencies import get_statistics_service
from app.main import app
from app.schemas.statistics import (
    AmountSpentByCurrency,
    MonthlyActivityPoint,
    StatisticsOut,
    YearlyActivityPoint,
)


def _canned_statistics() -> StatisticsOut:
    return StatisticsOut(
        total_unique_beers=5,
        total_logs=7,
        countries_discovered=3,
        styles_discovered=4,
        breweries_discovered=5,
        average_rating=3.5,
        amount_spent=[AmountSpentByCurrency(currency="USD", total="12.50")],
        monthly_activity=[MonthlyActivityPoint(month=date(2026, 9, 1), log_count=2)],
        yearly_activity=[YearlyActivityPoint(year=2026, log_count=7)],
        favorite_style="IPA",
        favorite_country=None,
        favorite_brewery="Test Brewery",
    )


class _FakeStatisticsService:
    def __init__(self, result: StatisticsOut) -> None:
        self._result = result

    async def get_statistics(self, *, user_id: str) -> StatisticsOut:
        return self._result


def _override(fake) -> None:
    app.dependency_overrides[get_statistics_service] = lambda: fake


def _clear_override() -> None:
    app.dependency_overrides.pop(get_statistics_service, None)


def test_get_statistics_without_token_is_unauthorized(client, unauthenticated):
    response = client.get("/statistics")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_get_statistics_returns_full_body(client, authenticated):
    fake = _FakeStatisticsService(_canned_statistics())
    _override(fake)
    try:
        response = client.get("/statistics")
    finally:
        _clear_override()

    assert response.status_code == 200
    body = response.json()
    assert body["total_unique_beers"] == 5
    assert body["total_logs"] == 7
    assert body["countries_discovered"] == 3
    assert body["styles_discovered"] == 4
    assert body["breweries_discovered"] == 5
    assert body["average_rating"] == 3.5
    assert body["amount_spent"] == [{"currency": "USD", "total": "12.50"}]
    assert body["monthly_activity"] == [{"month": "2026-09-01", "log_count": 2}]
    assert body["yearly_activity"] == [{"year": 2026, "log_count": 7}]
    assert body["favorite_style"] == "IPA"
    assert body["favorite_country"] is None
    assert body["favorite_brewery"] == "Test Brewery"


def test_post_statistics_is_405(client, authenticated):
    fake = _FakeStatisticsService(_canned_statistics())
    _override(fake)
    try:
        response = client.post("/statistics")
    finally:
        _clear_override()

    assert response.status_code == 405
