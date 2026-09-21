from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.auth.dependencies import get_current_user
from app.dependencies import get_brewery_service
from app.schemas.breweries import BreweryOut
from app.schemas.common import MAX_PAGE, Page
from app.services.breweries import BreweryService

router = APIRouter(
    prefix="/breweries",
    tags=["breweries"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=Page[BreweryOut])
async def list_breweries(
    country_id: UUID | None = None,
    page: int = Query(default=1, ge=1, le=MAX_PAGE),
    page_size: int = Query(default=20, ge=1, le=100),
    service: BreweryService = Depends(get_brewery_service),
) -> Page[BreweryOut]:
    return await service.list_breweries(
        country_id=str(country_id) if country_id is not None else None,
        page=page,
        page_size=page_size,
    )


@router.get("/{brewery_id}", response_model=BreweryOut)
async def get_brewery(
    brewery_id: UUID,
    service: BreweryService = Depends(get_brewery_service),
) -> BreweryOut:
    return await service.get_brewery(str(brewery_id))
