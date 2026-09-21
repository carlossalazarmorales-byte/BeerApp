from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import AfterValidator

from app.auth.dependencies import get_current_user
from app.dependencies import get_beer_service
from app.schemas.beers import BeerOut
from app.schemas.common import MAX_PAGE, NO_NUL_PATTERN, Page
from app.services.barcode import canonicalize_barcode
from app.services.beers import BeerService

# A canonicalization failure (wrong shape, unsupported length, bad check
# digit) raises ValueError, which Pydantic surfaces as a normal request
# validation error -- routed to the existing RequestValidationError -> 422
# handler with no new exception class or handler needed.
CanonicalBarcode = Annotated[str, AfterValidator(canonicalize_barcode)]

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
    q: str | None = Query(default=None, max_length=100, pattern=NO_NUL_PATTERN),
    page: int = Query(default=1, ge=1, le=MAX_PAGE),
    page_size: int = Query(default=20, ge=1, le=100),
    service: BeerService = Depends(get_beer_service),
) -> Page[BeerOut]:
    return await service.list_beers(
        country_id=str(country_id) if country_id is not None else None,
        style_id=str(style_id) if style_id is not None else None,
        brewery_id=str(brewery_id) if brewery_id is not None else None,
        q=q,
        page=page,
        page_size=page_size,
    )


@router.get("/{beer_id}", response_model=BeerOut)
async def get_beer(
    beer_id: UUID,
    service: BeerService = Depends(get_beer_service),
) -> BeerOut:
    return await service.get_beer(str(beer_id))


@router.get("/barcode/{barcode}", response_model=BeerOut)
async def get_beer_by_barcode(
    barcode: CanonicalBarcode,
    service: BeerService = Depends(get_beer_service),
) -> BeerOut:
    return await service.get_beer_by_barcode(barcode)
