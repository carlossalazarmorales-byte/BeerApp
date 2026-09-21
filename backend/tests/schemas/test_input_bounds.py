"""Request-schema bounds that mirror what the database can actually store.

Every value rejected here would otherwise reach Postgres and come back as an
unmapped asyncpg error -- a 500 -- or, for `price`, be silently rounded. The
limits are derived from the column types, not chosen as product rules:

- `user_beer_logs.price` is `numeric(10, 2)` -> at most 8 whole digits and
  exactly two decimal places: 0 .. 99,999,999.99.
- `user_beer_logs.serving_volume_ml` is `integer` (int4) -> <= 2,147,483,647.
- Postgres `text` cannot contain a NUL (U+0000) character.
"""

from decimal import Decimal
from uuid import UUID

import pytest
from pydantic import ValidationError

from app.schemas.beer_logs import BeerLogCreate, BeerLogUpdate
from app.schemas.contributions import (
    BeerContributionCreate,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryDuplicateCheckQuery,
)

_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")
_BREWERY_ID = UUID("55555555-5555-5555-5555-555555555555")
_COUNTRY_ID = UUID("66666666-6666-6666-6666-666666666666")


def _create(**fields) -> BeerLogCreate:
    return BeerLogCreate(beer_id=_BEER_ID, **fields)


def _priced_create(price) -> BeerLogCreate:
    return _create(price=price, currency="EUR")


# -- price: numeric(10, 2) ----------------------------------------------------


@pytest.mark.parametrize(
    "price",
    [0, Decimal("0.00"), Decimal("12.5"), 12.5, "12.50", Decimal("99999999.99"), "1e2"],
)
def test_price_within_numeric_10_2_is_accepted(price):
    assert _priced_create(price).price is not None


@pytest.mark.parametrize(
    "price",
    [
        Decimal("100000000.00"),  # 9 whole digits: numeric(10,2) overflow
        Decimal("99999999.995"),  # rounds up past the maximum
        Decimal("12.345"),  # a third decimal Postgres would silently round
        "1e400",  # astronomically large
        "1e-5",  # a fractional part far below the scale
        "NaN",
        "Infinity",
        "-Infinity",
        Decimal("-0.01"),
    ],
)
def test_price_outside_numeric_10_2_is_a_validation_error(price):
    with pytest.raises(ValidationError):
        _priced_create(price)


@pytest.mark.parametrize("price", [Decimal("100000000.00"), Decimal("12.345"), "1e400", "NaN"])
def test_update_price_outside_numeric_10_2_is_a_validation_error(price):
    with pytest.raises(ValidationError):
        BeerLogUpdate(price=price)


def test_update_accepts_the_maximum_price():
    assert BeerLogUpdate(price=Decimal("99999999.99")).price == Decimal("99999999.99")


# -- serving_volume_ml: integer (int4) ----------------------------------------


@pytest.mark.parametrize("volume", [1, 330, 2_147_483_647])
def test_serving_volume_within_int4_is_accepted(volume):
    assert _create(serving_volume_ml=volume).serving_volume_ml == volume


@pytest.mark.parametrize("volume", [0, -1, 2_147_483_648, 10**30])
def test_serving_volume_outside_int4_or_non_positive_is_a_validation_error(volume):
    with pytest.raises(ValidationError):
        _create(serving_volume_ml=volume)
    with pytest.raises(ValidationError):
        BeerLogUpdate(serving_volume_ml=volume)


# -- NUL characters in free text ----------------------------------------------


@pytest.mark.parametrize("field", ["review", "serving_note", "venue_name"])
def test_beer_log_text_with_a_nul_character_is_a_validation_error(field):
    with pytest.raises(ValidationError):
        _create(**{field: "before\x00after"})
    with pytest.raises(ValidationError):
        BeerLogUpdate(**{field: "before\x00after"})


@pytest.mark.parametrize("field", ["review", "serving_note", "venue_name"])
def test_beer_log_text_with_newlines_and_emoji_is_still_accepted(field):
    value = "línea uno\nline two \U0001f37a"
    assert getattr(_create(**{field: value}), field) == value


def test_contribution_text_with_a_nul_character_is_a_validation_error():
    with pytest.raises(ValidationError):
        BeerContributionCreate(official_name="Hazy\x00IPA", brewery_id=_BREWERY_ID)
    with pytest.raises(ValidationError):
        BeerContributionCreate(official_name="Hazy IPA", proposed_brewery_name="Hop\x00House")
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="Hop\x00House", country_id=_COUNTRY_ID)
    with pytest.raises(ValidationError):
        BreweryContributionCreate(name="Hop House", proposed_country_name="Ire\x00land")


def test_duplicate_check_query_text_with_a_nul_character_is_a_validation_error():
    with pytest.raises(ValidationError):
        BeerDuplicateCheckQuery(official_name="Hazy\x00IPA", brewery_id=_BREWERY_ID)
    with pytest.raises(ValidationError):
        BreweryDuplicateCheckQuery(name="Hop\x00House", country_id=_COUNTRY_ID)


def test_contribution_barcode_with_non_ascii_digits_is_a_validation_error():
    # Arabic-Indic digits: str.isdigit() is True and int() parses them, but the
    # database CHECK is ASCII-only -- previously a 500 after the fact.
    arabic_indic = "4006381333931".translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))

    with pytest.raises(ValidationError):
        BeerContributionCreate(
            official_name="Hazy IPA", brewery_id=_BREWERY_ID, barcode=arabic_indic
        )
