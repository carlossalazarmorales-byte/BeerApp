from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.dependencies import get_country_service
from app.schemas.countries import CountryOut
from app.services.countries import CountryService

router = APIRouter(
    prefix="/countries",
    tags=["countries"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=list[CountryOut])
async def list_countries(
    service: CountryService = Depends(get_country_service),
) -> list[CountryOut]:
    return await service.list_countries()
