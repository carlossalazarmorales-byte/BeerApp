from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.auth.dependencies import get_current_user
from app.dependencies import get_beer_service
from app.schemas.beers import BeerOut
from app.schemas.common import Page
from app.services.beers import BeerService

router = APIRouter(
    prefix="/beers",
    tags=["beers"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=Page[BeerOut])
async def list_beers(
    country_id: UUID | None = None,
    style_id: UUID | None = None,
    brewery_id: UUID | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    service: BeerService = Depends(get_beer_service),
) -> Page[BeerOut]:
    return await service.list_beers(
        country_id=str(country_id) if country_id is not None else None,
        style_id=str(style_id) if style_id is not None else None,
        brewery_id=str(brewery_id) if brewery_id is not None else None,
        page=page,
        page_size=page_size,
    )


@router.get("/{beer_id}", response_model=BeerOut)
async def get_beer(
    beer_id: UUID,
    service: BeerService = Depends(get_beer_service),
) -> BeerOut:
    return await service.get_beer(str(beer_id))
