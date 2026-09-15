import asyncio
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

import asyncpg
import pytest

from app.errors import InvalidRequestError, NotFoundError
from app.schemas.beer_logs import BeerLogCreate, BeerLogUpdate
from app.services.beer_logs import BeerLogService

_NOW = datetime.now(UTC)
_USER_ID = "11111111-1111-1111-1111-111111111111"
_BEER_ID = UUID("44444444-4444-4444-4444-444444444444")
_LOG_ID = "55555555-5555-5555-5555-555555555555"


def _log_row(**overrides) -> dict:
    row = {
        "id": UUID(_LOG_ID),
        "user_id": UUID(_USER_ID),
        "beer_id": _BEER_ID,
        "rating": None,
        "review": None,
        "consumed_at": _NOW,
        "serving_note": None,
        "price": None,
        "currency": None,
        "venue_name": None,
        "serving_volume_ml": None,
        "created_at": _NOW,
        "updated_at": _NOW,
    }
    row.update(overrides)
    return row


class _FakeBeerLogRepository:
    def __init__(self) -> None:
        self.create_calls: list[dict] = []
        self.update_calls: list[dict] = []
        self.create_error: Exception | None = None
        self.get_by_id_result: dict | None = None
        self.update_result: dict | None = None
        self._update_result_set = False

    def set_update_result(self, value: dict | None) -> None:
        self.update_result = value
        self._update_result_set = True

    async def create(self, **kwargs) -> dict:
        self.create_calls.append(kwargs)
        if self.create_error is not None:
            raise self.create_error
        return _log_row(**kwargs)

    async def list_paginated(self, **kwargs):
        return [], 0

    async def get_by_id(self, *, log_id: str, user_id: str) -> dict | None:
        return self.get_by_id_result

    async def update(self, *, log_id: str, user_id: str, fields: dict) -> dict | None:
        self.update_calls.append(fields)
        if self._update_result_set:
            return self.update_result
        # Default: merge fields onto the seeded "existing" row, like a real
        # UPDATE ... RETURNING would.
        base = dict(self.get_by_id_result or _log_row())
        base.update(fields)
        return base

    async def delete(self, *, log_id: str, user_id: str) -> bool:
        return True


def _run(coro):
    return asyncio.run(coro)


# -- create_log: consumed_at defaulting -------------------------------------


def test_create_log_defaults_consumed_at_to_aware_now_when_omitted():
    repository = _FakeBeerLogRepository()
    service = BeerLogService(repository)

    _run(service.create_log(user_id=_USER_ID, payload=BeerLogCreate(beer_id=_BEER_ID)))

    consumed_at = repository.create_calls[0]["consumed_at"]
    assert consumed_at is not None
    assert consumed_at.tzinfo is not None


def test_create_log_preserves_caller_supplied_consumed_at():
    supplied = datetime.now(UTC) - timedelta(days=2)
    repository = _FakeBeerLogRepository()
    service = BeerLogService(repository)

    _run(
        service.create_log(
            user_id=_USER_ID, payload=BeerLogCreate(beer_id=_BEER_ID, consumed_at=supplied)
        )
    )

    assert repository.create_calls[0]["consumed_at"] == supplied


def test_create_log_future_consumed_at_raises_invalid_request_error():
    future = datetime.now(UTC) + timedelta(days=1)
    repository = _FakeBeerLogRepository()
    service = BeerLogService(repository)

    with pytest.raises(InvalidRequestError):
        _run(
            service.create_log(
                user_id=_USER_ID, payload=BeerLogCreate(beer_id=_BEER_ID, consumed_at=future)
            )
        )


def test_create_log_foreign_key_violation_becomes_not_found():
    repository = _FakeBeerLogRepository()
    repository.create_error = asyncpg.ForeignKeyViolationError("no such beer")
    service = BeerLogService(repository)

    with pytest.raises(NotFoundError):
        _run(service.create_log(user_id=_USER_ID, payload=BeerLogCreate(beer_id=_BEER_ID)))


def test_create_log_serving_volume_ml_passes_through_untouched():
    repository = _FakeBeerLogRepository()
    service = BeerLogService(repository)

    _run(
        service.create_log(
            user_id=_USER_ID,
            payload=BeerLogCreate(beer_id=_BEER_ID, serving_volume_ml=330),
        )
    )

    assert repository.create_calls[0]["serving_volume_ml"] == 330


def test_create_log_omitted_serving_volume_ml_stays_none():
    repository = _FakeBeerLogRepository()
    service = BeerLogService(repository)

    _run(service.create_log(user_id=_USER_ID, payload=BeerLogCreate(beer_id=_BEER_ID)))

    assert repository.create_calls[0]["serving_volume_ml"] is None


# -- update_log: not-found/not-owned ----------------------------------------


def test_update_log_raises_not_found_when_repository_returns_none():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = None
    service = BeerLogService(repository)

    with pytest.raises(NotFoundError):
        _run(
            service.update_log(user_id=_USER_ID, log_id=_LOG_ID, payload=BeerLogUpdate(review="x"))
        )


def test_update_log_future_consumed_at_raises_invalid_request_error():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row()
    service = BeerLogService(repository)
    future = datetime.now(UTC) + timedelta(days=1)

    with pytest.raises(InvalidRequestError):
        _run(
            service.update_log(
                user_id=_USER_ID, log_id=_LOG_ID, payload=BeerLogUpdate(consumed_at=future)
            )
        )


# -- update_log: price/currency resulting-state matrix ----------------------


def test_update_log_review_only_leaves_existing_price_currency_untouched():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=Decimal("10.00"), currency="USD")
    service = BeerLogService(repository)

    result = _run(
        service.update_log(user_id=_USER_ID, log_id=_LOG_ID, payload=BeerLogUpdate(review="Nice"))
    )

    assert result.price == Decimal("10.00")
    assert result.currency == "USD"


def test_update_log_setting_price_when_no_existing_currency_is_rejected():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=None, currency=None)
    service = BeerLogService(repository)

    with pytest.raises(InvalidRequestError):
        _run(
            service.update_log(
                user_id=_USER_ID,
                log_id=_LOG_ID,
                payload=BeerLogUpdate(price=Decimal("5.00")),
            )
        )


def test_update_log_clearing_only_currency_is_rejected_when_price_stays_set():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=Decimal("10.00"), currency="USD")
    service = BeerLogService(repository)

    with pytest.raises(InvalidRequestError):
        _run(
            service.update_log(
                user_id=_USER_ID, log_id=_LOG_ID, payload=BeerLogUpdate(currency=None)
            )
        )


def test_update_log_clearing_both_price_and_currency_together_succeeds():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=Decimal("10.00"), currency="USD")
    service = BeerLogService(repository)

    result = _run(
        service.update_log(
            user_id=_USER_ID,
            log_id=_LOG_ID,
            payload=BeerLogUpdate(price=None, currency=None),
        )
    )

    assert result.price is None
    assert result.currency is None


def test_update_log_setting_price_and_currency_together_from_empty_succeeds():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=None, currency=None)
    service = BeerLogService(repository)

    result = _run(
        service.update_log(
            user_id=_USER_ID,
            log_id=_LOG_ID,
            payload=BeerLogUpdate(price=Decimal("5.00"), currency="EUR"),
        )
    )

    assert result.price == Decimal("5.00")
    assert result.currency == "EUR"


# -- update_log: serving_volume_ml never cross-validated --------------------


def test_update_log_serving_volume_ml_passes_through_untouched_by_other_checks():
    repository = _FakeBeerLogRepository()
    repository.get_by_id_result = _log_row(price=None, currency=None)
    service = BeerLogService(repository)

    result = _run(
        service.update_log(
            user_id=_USER_ID,
            log_id=_LOG_ID,
            payload=BeerLogUpdate(serving_volume_ml=500),
        )
    )

    assert result.serving_volume_ml == 500


# -- delete_log ---------------------------------------------------------


def test_delete_log_raises_not_found_when_repository_reports_no_row_deleted():
    class _NothingDeletedRepository(_FakeBeerLogRepository):
        async def delete(self, *, log_id: str, user_id: str) -> bool:
            return False

    service = BeerLogService(_NothingDeletedRepository())

    with pytest.raises(NotFoundError):
        _run(service.delete_log(user_id=_USER_ID, log_id=_LOG_ID))
