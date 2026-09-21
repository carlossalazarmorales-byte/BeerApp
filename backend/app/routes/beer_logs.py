from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from app.auth.dependencies import get_current_user
from app.dependencies import get_beer_log_service
from app.schemas.beer_logs import BeerLogCreate, BeerLogOut, BeerLogUpdate
from app.schemas.common import MAX_PAGE, Page
from app.services.beer_logs import BeerLogService

# No router-level `dependencies=[Depends(get_current_user)]` (unlike the
# catalog routers): those only need auth as a gate and never consume the
# returned value, but every route here needs the actual user id, so
# get_current_user is declared per-route as an ordinary parameter instead.
router = APIRouter(prefix="/beer-logs", tags=["beer-logs"])


@router.post("", response_model=BeerLogOut, status_code=status.HTTP_201_CREATED)
async def create_beer_log(
    payload: BeerLogCreate,
    user_id: str = Depends(get_current_user),
    service: BeerLogService = Depends(get_beer_log_service),
) -> BeerLogOut:
    return await service.create_log(user_id=user_id, payload=payload)


@router.get("", response_model=Page[BeerLogOut])
async def list_beer_logs(
    beer_id: UUID | None = None,
    page: int = Query(default=1, ge=1, le=MAX_PAGE),
    page_size: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user),
    service: BeerLogService = Depends(get_beer_log_service),
) -> Page[BeerLogOut]:
    # Always scoped to the caller -- there is no user_id query param at all,
    # so "whose logs" is never a client-controlled input.
    return await service.list_logs(
        user_id=user_id,
        beer_id=str(beer_id) if beer_id is not None else None,
        page=page,
        page_size=page_size,
    )


@router.get("/{log_id}", response_model=BeerLogOut)
async def get_beer_log(
    log_id: UUID,
    user_id: str = Depends(get_current_user),
    service: BeerLogService = Depends(get_beer_log_service),
) -> BeerLogOut:
    return await service.get_log(user_id=user_id, log_id=str(log_id))


@router.patch("/{log_id}", response_model=BeerLogOut)
async def update_beer_log(
    log_id: UUID,
    payload: BeerLogUpdate,
    user_id: str = Depends(get_current_user),
    service: BeerLogService = Depends(get_beer_log_service),
) -> BeerLogOut:
    return await service.update_log(user_id=user_id, log_id=str(log_id), payload=payload)


@router.delete("/{log_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_beer_log(
    log_id: UUID,
    user_id: str = Depends(get_current_user),
    service: BeerLogService = Depends(get_beer_log_service),
) -> None:
    await service.delete_log(user_id=user_id, log_id=str(log_id))
