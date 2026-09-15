from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas.beer_logs import BeerLogCreate, BeerLogUpdate

_BEER_ID = uuid4()


# -- consumed_at timezone-awareness ----------------------------------------


def test_create_omitted_consumed_at_is_allowed():
    payload = BeerLogCreate(beer_id=_BEER_ID)
    assert payload.consumed_at is None


def test_create_aware_consumed_at_is_accepted():
    aware = datetime.now(UTC)
    payload = BeerLogCreate(beer_id=_BEER_ID, consumed_at=aware)
    assert payload.consumed_at == aware


def test_create_naive_consumed_at_is_rejected_cleanly():
    naive = datetime(2026, 1, 1, 10, 0, 0)  # no tzinfo
    with pytest.raises(ValidationError):
        BeerLogCreate(beer_id=_BEER_ID, consumed_at=naive)


def test_update_naive_consumed_at_is_rejected_cleanly():
    naive = datetime(2026, 1, 1, 10, 0, 0)
    with pytest.raises(ValidationError):
        BeerLogUpdate(consumed_at=naive)


def test_update_aware_consumed_at_is_accepted():
    aware = datetime.now(UTC) - timedelta(days=1)
    payload = BeerLogUpdate(consumed_at=aware)
    assert payload.consumed_at == aware


def test_update_consumed_at_null_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogUpdate(consumed_at=None)
    # Explicit key present with value None must also be rejected, not just
    # a bare positional omission -- model_construct-style dict input:
    with pytest.raises(ValidationError):
        BeerLogUpdate.model_validate({"consumed_at": None})


# -- BeerLogUpdate empty-patch / extra-field rejection ----------------------


def test_update_empty_patch_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogUpdate()


def test_update_single_field_is_accepted():
    payload = BeerLogUpdate(review="Great beer")
    assert payload.model_fields_set == {"review"}


def test_update_rejects_unknown_field_eg_user_id():
    with pytest.raises(ValidationError):
        BeerLogUpdate.model_validate({"review": "x", "user_id": str(uuid4())})


def test_create_rejects_unknown_field_eg_user_id():
    with pytest.raises(ValidationError):
        BeerLogCreate.model_validate({"beer_id": str(_BEER_ID), "user_id": str(uuid4())})


# -- price/currency same-request pairing (BeerLogCreate only) --------------


def test_create_price_without_currency_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogCreate(beer_id=_BEER_ID, price="5.00")


def test_create_currency_without_price_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogCreate(beer_id=_BEER_ID, currency="USD")


def test_create_price_and_currency_together_is_accepted():
    payload = BeerLogCreate(beer_id=_BEER_ID, price="5.00", currency="USD")
    assert payload.currency == "USD"


# -- serving_volume_ml ------------------------------------------------------


def test_create_serving_volume_ml_omitted_is_none():
    payload = BeerLogCreate(beer_id=_BEER_ID)
    assert payload.serving_volume_ml is None


def test_create_serving_volume_ml_zero_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogCreate(beer_id=_BEER_ID, serving_volume_ml=0)


def test_create_serving_volume_ml_negative_is_rejected():
    with pytest.raises(ValidationError):
        BeerLogCreate(beer_id=_BEER_ID, serving_volume_ml=-330)


def test_create_serving_volume_ml_positive_is_accepted():
    payload = BeerLogCreate(beer_id=_BEER_ID, serving_volume_ml=330)
    assert payload.serving_volume_ml == 330


def test_update_serving_volume_ml_null_is_accepted_as_a_clear():
    payload = BeerLogUpdate(serving_volume_ml=None)
    assert "serving_volume_ml" in payload.model_fields_set
    assert payload.model_dump(exclude_unset=True) == {"serving_volume_ml": None}
