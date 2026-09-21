import asyncpg

from app.errors import NotFoundError
from app.repositories.collection import CollectionRepository
from app.repositories.scoped_connection import scoped_connection
from app.schemas.collection import CollectionBeerOut, CollectionStateOut, CollectionStateUpdate
from app.schemas.common import Page
from app.services.achievement_evaluator import AchievementEvaluator
from app.services.db_errors import translate_beer_write_foreign_key_violation

_BEER_FOREIGN_KEY = "user_beer_collection_beer_id_fkey"


class CollectionService:
    def __init__(
        self,
        repository: CollectionRepository,
        pool: asyncpg.Pool,
        achievement_evaluator: AchievementEvaluator,
    ) -> None:
        self._repository = repository
        self._pool = pool
        self._achievement_evaluator = achievement_evaluator

    async def list_logged(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> Page[CollectionBeerOut]:
        rows, total = await self._repository.list_logged(
            user_id=user_id,
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            sort=sort,
            page=page,
            page_size=page_size,
        )
        return Page[CollectionBeerOut](
            items=[CollectionBeerOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def list_favorites(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> Page[CollectionBeerOut]:
        rows, total = await self._repository.list_favorites(
            user_id=user_id,
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            sort=sort,
            page=page,
            page_size=page_size,
        )
        return Page[CollectionBeerOut](
            items=[CollectionBeerOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def list_wishlist(
        self,
        *,
        user_id: str,
        country_id: str | None,
        style_id: str | None,
        brewery_id: str | None,
        sort: str,
        page: int,
        page_size: int,
    ) -> Page[CollectionBeerOut]:
        rows, total = await self._repository.list_wishlist(
            user_id=user_id,
            country_id=country_id,
            style_id=style_id,
            brewery_id=brewery_id,
            sort=sort,
            page=page,
            page_size=page_size,
        )
        return Page[CollectionBeerOut](
            items=[CollectionBeerOut.model_validate(dict(row)) for row in rows],
            page=page,
            page_size=page_size,
            total=total,
        )

    async def get_state(self, *, user_id: str, beer_id: str) -> CollectionStateOut:
        row = await self._repository.get_state(user_id=user_id, beer_id=beer_id)
        if row is None:
            # No row at all -- not even a NULL-collection-state row -- means
            # the LEFT JOIN's driving beers table had nothing at this id:
            # beer_id isn't a real catalog beer. A real beer with no
            # collection row still returns exactly one row (both flags
            # coalesced to false), so this 404 never fires for "not yet in
            # your collection", only for "not a real beer".
            raise NotFoundError(f"Beer {beer_id} not found")
        return CollectionStateOut.model_validate(dict(row))

    async def set_state(
        self, *, user_id: str, beer_id: str, payload: CollectionStateUpdate
    ) -> CollectionStateOut:
        # Owns the transaction so the Collection mutation and any achievement
        # unlock it causes commit or roll back together -- see
        # docs/DECISIONS.md. If evaluate_and_unlock raises, the exception
        # propagates out of this `async with` block and the whole
        # transaction, mutation included, rolls back rather than risking a
        # permanently-earned achievement being silently lost.
        async with scoped_connection(self._pool, user_id) as conn:
            try:
                result = await self._repository.set_state_on_connection(
                    conn,
                    user_id=user_id,
                    beer_id=beer_id,
                    is_favorite=payload.is_favorite,
                    is_wishlist=payload.is_wishlist,
                )
            except asyncpg.ForeignKeyViolationError as exc:
                raise translate_beer_write_foreign_key_violation(
                    exc, beer_constraint=_BEER_FOREIGN_KEY, beer_id=beer_id
                ) from exc
            await self._achievement_evaluator.evaluate_and_unlock(conn, user_id=user_id)
        return CollectionStateOut.model_validate(result)
