from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.auth.dependencies import get_current_user
from app.dependencies import get_map_service
from app.schemas.common import NO_NUL_PATTERN
from app.schemas.map import CappedList, MapBeerOut, MapBreweryOut, MapCountryCoverageOut
from app.services.map import MapService

_MapState = Literal["all", "tried", "not_tried", "favorites", "wishlist"]

# No router-level `dependencies=[Depends(get_current_user)]` for /beers --
# the state filter needs the actual user id, so get_current_user is declared
# per-route instead, same reasoning as collection.py/beer_logs.py.
router = APIRouter(prefix="/map", tags=["map"])


@router.get("/beers", response_model=CappedList[MapBeerOut])
async def list_map_beers(
    state: _MapState = "all",
    country_id: UUID | None = None,
    q: str | None = Query(default=None, max_length=100, pattern=NO_NUL_PATTERN),
    user_id: str = Depends(get_current_user),
    service: MapService = Depends(get_map_service),
) -> CappedList[MapBeerOut]:
    return await service.list_beers(
        user_id=user_id,
        state=state,
        country_id=str(country_id) if country_id is not None else None,
        q=q,
    )


@router.get("/breweries", response_model=CappedList[MapBreweryOut])
async def list_map_breweries(
    country_id: UUID | None = None,
    q: str | None = Query(default=None, max_length=100, pattern=NO_NUL_PATTERN),
    user_id: str = Depends(get_current_user),
    service: MapService = Depends(get_map_service),
) -> CappedList[MapBreweryOut]:
    return await service.list_breweries(
        country_id=str(country_id) if country_id is not None else None,
        q=q,
    )


@router.get("/countries", response_model=list[MapCountryCoverageOut])
async def list_map_country_coverage(
    user_id: str = Depends(get_current_user),
    service: MapService = Depends(get_map_service),
) -> list[MapCountryCoverageOut]:
    return await service.list_country_coverage(user_id=user_id)
