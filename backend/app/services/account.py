from app.services.supabase_admin_client import SupabaseAdminClient


class AccountService:
    """Deliberately thin: no table writes needed here at all. Deleting the
    auth.users row (via the Admin API, below) cascades automatically to
    profiles/user_beer_logs/user_beer_collection/user_achievements and, since
    Phase 13, beer_contributions/brewery_contributions through their existing
    ON DELETE CASCADE foreign keys -- see docs/DATABASE.md.
    """

    def __init__(self, admin_client: SupabaseAdminClient) -> None:
        self._admin_client = admin_client

    async def delete_account(self, *, user_id: str) -> None:
        await self._admin_client.delete_user(user_id)
