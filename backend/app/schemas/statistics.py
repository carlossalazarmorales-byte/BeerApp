from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class AmountSpentByCurrency(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    currency: str
    # Decimal, not float -- money, same reasoning as BeerLogOut.price.
    # Serializes as a JSON string, same convention as price/abv elsewhere.
    total: Decimal


class MonthlyActivityPoint(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    # First day of a UTC calendar month, e.g. 2026-09-01. Always exactly 12
    # points, trailing rolling window, zero-filled -- see StatisticsRepository.
    month: date
    log_count: int


class YearlyActivityPoint(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    # All-time, one row per UTC calendar year that has >=1 log -- not
    # zero-filled, deliberately a different shape from MonthlyActivityPoint.
    year: int
    log_count: int


class StatisticsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    total_unique_beers: int
    total_logs: int
    countries_discovered: int
    styles_discovered: int
    breweries_discovered: int
    # float, not Decimal -- an average has no fixed-precision meaning worth
    # preserving as a string the way price does. None when the user has no
    # rated logs (never 0 -- 0 would be a real, misleadingly bad rating).
    average_rating: float | None
    amount_spent: list[AmountSpentByCurrency]
    monthly_activity: list[MonthlyActivityPoint]
    yearly_activity: list[YearlyActivityPoint]
    # Display name of the mode among the user's Collection favorites (see
    # StatisticsRepository) -- None when the user has zero favorites, never
    # an error and never a fabricated "most common" among nothing.
    favorite_style: str | None
    favorite_country: str | None
    favorite_brewery: str | None
