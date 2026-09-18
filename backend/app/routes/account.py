from fastapi import APIRouter, Depends, HTTPException, status

from app.auth.dependencies import get_current_user
from app.dependencies import get_account_service
from app.services.account import AccountService
from app.services.supabase_admin_client import SupabaseAdminClientError

# No router-level `dependencies=[Depends(get_current_user)]` (same reasoning
# as beer_logs/collection): this route needs the actual user id, not just
# auth as a gate.
router = APIRouter(prefix="/account", tags=["account"])


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    user_id: str = Depends(get_current_user),
    service: AccountService = Depends(get_account_service),
) -> None:
    # user_id comes exclusively from the verified JWT -- there is no
    # path/body parameter on this route, so a caller can never request
    # another account's deletion.
    try:
        await service.delete_account(user_id=user_id)
    except SupabaseAdminClientError as exc:
        # Covers both an unconfigured secret key and a genuine Admin API
        # failure -- both are infrastructure conditions, not the caller's
        # fault, so both map to 503 (mirrors how app/auth/ already maps a
        # JWKS-retrieval failure to 503), never a generic 500.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to delete account at this time.",
        ) from exc
