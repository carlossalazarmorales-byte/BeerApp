from app.dependencies import get_account_service
from app.main import app
from app.services.supabase_admin_client import (
    SupabaseAdminClientError,
    SupabaseAdminClientNotConfigured,
)

_USER_ID = "11111111-1111-1111-1111-111111111111"


class _FakeAccountService:
    def __init__(self, *, error: Exception | None = None) -> None:
        self.calls: list[str] = []
        self._error = error

    async def delete_account(self, *, user_id: str) -> None:
        self.calls.append(user_id)
        if self._error is not None:
            raise self._error


def _override(fake) -> None:
    app.dependency_overrides[get_account_service] = lambda: fake


def _clear_override() -> None:
    app.dependency_overrides.pop(get_account_service, None)


def test_delete_account_without_token_is_unauthorized(client, unauthenticated):
    response = client.delete("/account")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_delete_account_success_returns_204_with_empty_body(client, authenticated):
    fake = _FakeAccountService()
    _override(fake)
    try:
        response = client.delete("/account")
    finally:
        _clear_override()

    assert response.status_code == 204
    assert response.content == b""
    # user_id comes exclusively from the verified JWT -- there is no
    # client-suppliable id on this route at all.
    assert fake.calls == [_USER_ID]


def test_delete_account_admin_client_error_is_service_unavailable(client, authenticated):
    fake = _FakeAccountService(error=SupabaseAdminClientError("boom"))
    _override(fake)
    try:
        response = client.delete("/account")
    finally:
        _clear_override()

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "service_unavailable"


def test_delete_account_not_configured_is_also_service_unavailable(client, authenticated):
    fake = _FakeAccountService(error=SupabaseAdminClientNotConfigured("no key"))
    _override(fake)
    try:
        response = client.delete("/account")
    finally:
        _clear_override()

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "service_unavailable"
