from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.auth.dependencies import get_current_user
from app.dependencies import get_contribution_service
from app.schemas.common import Page
from app.schemas.contributions import (
    BeerContributionCreate,
    BeerContributionOut,
    BeerDuplicateCandidatesOut,
    BeerDuplicateCheckQuery,
    BreweryContributionCreate,
    BreweryContributionOut,
    BreweryDuplicateCandidatesOut,
    BreweryDuplicateCheckQuery,
    ContributionSummaryOut,
)
from app.services.contributions import ContributionService

# No router-level auth dependency and no path prefix (unlike the catalog
# routers): every route needs the actual user id, and the three URL families
# below share one service. The owner is only ever the verified JWT's sub --
# there is no user_id parameter or body field anywhere here.
router = APIRouter(tags=["contributions"])


@router.post(
    "/beer-contributions",
    response_model=BeerContributionOut,
    status_code=status.HTTP_201_CREATED,
)
async def submit_beer_contribution(
    payload: BeerContributionCreate,
    user_id: str = Depends(get_current_user),
    service: ContributionService = Depends(get_contribution_service),
) -> BeerContributionOut:
    return await service.submit_beer(user_id=user_id, payload=payload)


@router.post(
    "/brewery-contributions",
    response_model=BreweryContributionOut,
    status_code=status.HTTP_201_CREATED,
)
async def submit_brewery_contribution(
    payload: BreweryContributionCreate,
    user_id: str = Depends(get_current_user),
    service: ContributionService = Depends(get_contribution_service),
) -> BreweryContributionOut:
    return await service.submit_brewery(user_id=user_id, payload=payload)


@router.get("/contributions", response_model=Page[ContributionSummaryOut])
async def list_contributions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
    service: ContributionService = Depends(get_contribution_service),
) -> Page[ContributionSummaryOut]:
    # Always the caller's own history -- there is no user_id query param.
    return await service.list_history(user_id=user_id, page=page, page_size=page_size)


@router.get(
    "/beer-contributions/duplicate-candidates",
    response_model=BeerDuplicateCandidatesOut,
)
async def beer_duplicate_candidates(
    query: Annotated[BeerDuplicateCheckQuery, Query()],
    user_id: str = Depends(get_current_user),
    service: ContributionService = Depends(get_contribution_service),
) -> BeerDuplicateCandidatesOut:
    return await service.beer_duplicate_candidates(user_id=user_id, query=query)


@router.get(
    "/brewery-contributions/duplicate-candidates",
    response_model=BreweryDuplicateCandidatesOut,
)
async def brewery_duplicate_candidates(
    query: Annotated[BreweryDuplicateCheckQuery, Query()],
    user_id: str = Depends(get_current_user),
    service: ContributionService = Depends(get_contribution_service),
) -> BreweryDuplicateCandidatesOut:
    return await service.brewery_duplicate_candidates(user_id=user_id, query=query)
