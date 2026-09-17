from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.dependencies import get_achievements_service
from app.schemas.achievements import AchievementsOut
from app.services.achievements import AchievementsService

router = APIRouter(prefix="/achievements", tags=["achievements"])


@router.get("", response_model=AchievementsOut)
async def get_achievements(
    user_id: str = Depends(get_current_user),
    service: AchievementsService = Depends(get_achievements_service),
) -> AchievementsOut:
    return await service.get_achievements(user_id=user_id)
