import asyncio

import httpx
import pytest

from app.services.supabase_admin_client import (
    SupabaseAdminClient,
    SupabaseAdminClientError,
    SupabaseAdminClientNotConfigured,
)

_SUPABASE_URL = "https://example.supabase.co"
_USER_ID = "11111111-1111-1111-1111-111111111111"
# Fixture placeholder only -- never a real secret, and never asserted/printed
# in a way that could leak a real value into failure output.
_SECRET_KEY = "sb_secret_test_only"


def _run(coro):
    return asyncio.run(coro)


def _client_with(handler, *, secret_key: str | None = _SECRET_KEY) -> SupabaseAdminClient:
    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return SupabaseAdminClient(http_client, supabase_url=_SUPABASE_URL, secret_key=secret_key)


def test_delete_user_sends_correct_url_and_apikey_header_only():
    captured: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        captured.append(request)
        return httpx.Response(200, json={})

    client = _client_with(handler)

    _run(client.delete_user(_USER_ID))

    assert len(captured) == 1
    request = captured[0]
    assert request.method == "DELETE"
    assert str(request.url) == f"{_SUPABASE_URL}/auth/v1/admin/users/{_USER_ID}"
    assert request.headers["apikey"] == _SECRET_KEY
    # New sb_secret_... keys are not JWTs -- must never be sent as a bearer
    # token, per current Supabase docs (see docs/DECISIONS.md).
    assert "authorization" not in request.headers


def test_delete_user_404_is_treated_as_success():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404, json={"message": "not found"})

    client = _client_with(handler)

    _run(client.delete_user(_USER_ID))  # must not raise


def test_delete_user_other_non_2xx_raises_error():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"message": "boom"})

    client = _client_with(handler)

    with pytest.raises(SupabaseAdminClientError):
        _run(client.delete_user(_USER_ID))


def test_delete_user_network_error_raises_error():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    client = _client_with(handler)

    with pytest.raises(SupabaseAdminClientError):
        _run(client.delete_user(_USER_ID))


def test_delete_user_without_secret_key_raises_not_configured_and_makes_no_request():
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        return httpx.Response(200, json={})

    client = _client_with(handler, secret_key=None)

    with pytest.raises(SupabaseAdminClientNotConfigured):
        _run(client.delete_user(_USER_ID))

    assert calls["count"] == 0


def test_not_configured_error_message_never_includes_a_secret_value():
    client = _client_with(lambda request: httpx.Response(200, json={}), secret_key=None)

    with pytest.raises(SupabaseAdminClientNotConfigured) as excinfo:
        _run(client.delete_user(_USER_ID))

    assert _SECRET_KEY not in str(excinfo.value)
