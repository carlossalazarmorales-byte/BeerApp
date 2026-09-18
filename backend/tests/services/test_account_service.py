import asyncio

import pytest

from app.services.account import AccountService
from app.services.supabase_admin_client import SupabaseAdminClientError

_USER_ID = "11111111-1111-1111-1111-111111111111"


def _run(coro):
    return asyncio.run(coro)


class _FakeAdminClient:
    def __init__(self, *, error: Exception | None = None) -> None:
        self.calls: list[str] = []
        self._error = error

    async def delete_user(self, user_id: str) -> None:
        self.calls.append(user_id)
        if self._error is not None:
            raise self._error


def test_delete_account_delegates_to_admin_client_with_the_given_user_id():
    admin_client = _FakeAdminClient()
    service = AccountService(admin_client)

    _run(service.delete_account(user_id=_USER_ID))

    assert admin_client.calls == [_USER_ID]


def test_delete_account_propagates_admin_client_errors_unchanged():
    admin_client = _FakeAdminClient(error=SupabaseAdminClientError("boom"))
    service = AccountService(admin_client)

    with pytest.raises(SupabaseAdminClientError):
        _run(service.delete_account(user_id=_USER_ID))
