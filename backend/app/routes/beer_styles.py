from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.dependencies import get_beer_style_service
from app.schemas.beer_styles import BeerStyleOut
from app.services.beer_styles import BeerStyleService

router = APIRouter(
    prefix="/beer-styles",
    tags=["beer-styles"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=list[BeerStyleOut])
async def list_beer_styles(
    service: BeerStyleService = Depends(get_beer_style_service),
) -> list[BeerStyleOut]:
    return await service.list_beer_styles()
