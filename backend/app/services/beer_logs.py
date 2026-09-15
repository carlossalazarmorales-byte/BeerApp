from datetime import UTC, datetime

import asyncpg

from app.errors import InvalidRequestError, NotFoundError
from app.repositories.beer_logs import BeerLogRepository
from app.schemas.beer_logs import BeerLogCreate, BeerLogOut, BeerLogUpdate
from app.schemas.common import Page


class BeerLogService:
    def __init__(self, repository: BeerLogRepository) -> None:
        self._repository = repository

    async def create_log(self, *, user_id: str, payload: BeerLogCreate) -> BeerLogOut:
        # Resolved explicitly here rather than omitting the column and
        # relying on the DB's `default now()`: the repository's create()
        # uses one fixed, static SQL string with a fixed parameter list, so
        # it never has a code path that could bind NULL into consumed_at's
        # NOT NULL column. datetime.now(UTC) is timezone-aware (never the
        # naive/deprecated utcnow()), and payload.consumed_at -- if
        # supplied -- already passed BeerLogCreate's _require_aware_or_none
        # check, so this comparison is always aware-vs-aware and cannot
        # raise TypeError.
        consumed_at = payload.consumed_at if payload.consumed_at is not None else datetime.now(UTC)
        if consumed_at > datetime.now(UTC):
            raise InvalidRequestError("consumed_at cannot be in the future.")

        try:
            row = await self._repository.create(
                user_id=user_id,
                beer_id=str(payload.beer_id),
                rating=payload.rating,
                review=payload.review,
                consumed_at=consumed_at,
                serving_note=payload.serving_note,
                price=payload.price,
                currency=payload.currency,
                venue_name=payload.venue_name,
                serving_volume_ml=payload.serving_volume_ml,
            )
        except asyncpg.ForeignKeyViolationError as exc:
            raise NotFoundError(f"Beer {payload.beer_id} not found") from exc
        return BeerLogOut.model_validate(dict(row))

    async def list_logs(
        self, *, user_id: str, beer_id: str | None, page: int, page_size: int
    ) -> Page[BeerLogOut]:
        rows, total = await self._repository.list_paginated(
            user_id=user_id, beer_id=beer_id, page=page, page_size=page_size
        )
        return Page[BeerLogOut](
            items=[BeerLogOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def get_log(self, *, user_id: str, log_id: str) -> BeerLogOut:
        row = await self._repository.get_by_id(log_id=log_id, user_id=user_id)
        if row is None:
            raise NotFoundError(f"Beer log {log_id} not found")
        return BeerLogOut.model_validate(dict(row))

    async def update_log(self, *, user_id: str, log_id: str, payload: BeerLogUpdate) -> BeerLogOut:
        # The existing row is fetched first for two reasons: it's the
        # ownership/existence check (missing or not-owned both land here,
        # both become the same 404 -- there is no separate ownership branch
        # to leak which case it was), and it's what lets the price/currency
        # check below validate the *resulting* state rather than just the
        # two fields present in this request.
        existing = await self._repository.get_by_id(log_id=log_id, user_id=user_id)
        if existing is None:
            raise NotFoundError(f"Beer log {log_id} not found")

        patch = payload.model_dump(exclude_unset=True)

        if "consumed_at" in patch and patch["consumed_at"] > datetime.now(UTC):
            # patch["consumed_at"] already passed BeerLogUpdate's
            # _require_aware_or_none check, so this is always aware-vs-aware.
            raise InvalidRequestError("consumed_at cannot be in the future.")

        resulting_price = patch.get("price", existing["price"])
        resulting_currency = patch.get("currency", existing["currency"])
        if (resulting_price is None) != (resulting_currency is None):
            raise InvalidRequestError("price and currency must both be set or both be cleared.")

        updated = await self._repository.update(log_id=log_id, user_id=user_id, fields=patch)
        if updated is None:
            raise NotFoundError(f"Beer log {log_id} not found")
        return BeerLogOut.model_validate(dict(updated))

    async def delete_log(self, *, user_id: str, log_id: str) -> None:
        deleted = await self._repository.delete(log_id=log_id, user_id=user_id)
        if not deleted:
            raise NotFoundError(f"Beer log {log_id} not found")
