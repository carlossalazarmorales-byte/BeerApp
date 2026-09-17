from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.dependencies import get_statistics_service
from app.schemas.statistics import StatisticsOut
from app.services.statistics import StatisticsService

# Same per-route (not router-level) get_current_user pattern as beer_logs
# and collection -- every route here needs the actual user id, not just an
# auth gate.
router = APIRouter(prefix="/statistics", tags=["statistics"])


@router.get("", response_model=StatisticsOut)
async def get_statistics(
    user_id: str = Depends(get_current_user),
    service: StatisticsService = Depends(get_statistics_service),
) -> StatisticsOut:
    return await service.get_statistics(user_id=user_id)
