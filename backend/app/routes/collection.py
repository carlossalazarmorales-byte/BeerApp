from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.auth.dependencies import get_current_user
from app.dependencies import get_collection_service
from app.schemas.collection import CollectionBeerOut, CollectionStateOut, CollectionStateUpdate
from app.schemas.common import Page
from app.services.collection import CollectionService

_Sort = Literal["recent", "rating", "name"]

# No router-level `dependencies=[Depends(get_current_user)]` (unlike the
# catalog routers): those only need auth as a gate and never consume the
# returned value, but every route here needs the actual user id, so
# get_current_user is declared per-route as an ordinary parameter instead --
# same reasoning as beer_logs.
router = APIRouter(prefix="/collection", tags=["collection"])


@router.get("/logged", response_model=Page[CollectionBeerOut])
async def list_logged_collection(
    country_id: UUID | None = None,
    style_id: UUID | None = None,
    brewery_id: UUID | None = None,
    sort: _Sort = "recent",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
    service: CollectionService = Depends(get_collection_service),
) -> Page[CollectionBeerOut]:
    return await service.list_logged(
        user_id=user_id,
        country_id=str(country_id) if country_id is not None else None,
        style_id=str(style_id) if style_id is not None else None,
        brewery_id=str(brewery_id) if brewery_id is not None else None,
        sort=sort,
        page=page,
        page_size=page_size,
    )


@router.get("/favorites", response_model=Page[CollectionBeerOut])
async def list_favorite_collection(
    country_id: UUID | None = None,
    style_id: UUID | None = None,
    brewery_id: UUID | None = None,
    sort: _Sort = "recent",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
    service: CollectionService = Depends(get_collection_service),
) -> Page[CollectionBeerOut]:
    return await service.list_favorites(
        user_id=user_id,
        country_id=str(country_id) if country_id is not None else None,
        style_id=str(style_id) if style_id is not None else None,
        brewery_id=str(brewery_id) if brewery_id is not None else None,
        sort=sort,
        page=page,
        page_size=page_size,
    )


@router.get("/wishlist", response_model=Page[CollectionBeerOut])
async def list_wishlist_collection(
    country_id: UUID | None = None,
    style_id: UUID | None = None,
    brewery_id: UUID | None = None,
    sort: _Sort = "recent",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
    service: CollectionService = Depends(get_collection_service),
) -> Page[CollectionBeerOut]:
    return await service.list_wishlist(
        user_id=user_id,
        country_id=str(country_id) if country_id is not None else None,
        style_id=str(style_id) if style_id is not None else None,
        brewery_id=str(brewery_id) if brewery_id is not None else None,
        sort=sort,
        page=page,
        page_size=page_size,
    )


# Declared after the literal /logged, /favorites, /wishlist routes above --
# route matching is registration-order-sensitive, and {beer_id} is UUID-typed
# so it must not intercept those literal paths.


@router.get("/{beer_id}", response_model=CollectionStateOut)
async def get_collection_state(
    beer_id: UUID,
    user_id: str = Depends(get_current_user),
    service: CollectionService = Depends(get_collection_service),
) -> CollectionStateOut:
    return await service.get_state(user_id=user_id, beer_id=str(beer_id))


@router.patch("/{beer_id}", response_model=CollectionStateOut)
async def update_collection_state(
    beer_id: UUID,
    payload: CollectionStateUpdate,
    user_id: str = Depends(get_current_user),
    service: CollectionService = Depends(get_collection_service),
) -> CollectionStateOut:
    return await service.set_state(user_id=user_id, beer_id=str(beer_id), payload=payload)
