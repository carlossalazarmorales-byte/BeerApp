"""Client-visible error contract for infrastructure failures.

- Genuine, temporary database/network unavailability -> sanitized 503.
- Programming errors, constraint violations, bad SQL, unexpected exceptions ->
  still 500 (never disguised as "try again later").
- Neither ever echoes exception text (which can carry hosts, users, SQL,
  constraint names or credentials) back to the client or into the logs.
- A valid token for an account that no longer exists -> the same 401 a bad
  token gets, revealing nothing about anyone else's data.
"""

import logging
import socket

import asyncpg
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.errors import (
    DATABASE_UNAVAILABLE_ERRORS,
    SessionInvalidError,
    register_exception_handlers,
)

_LEAKY = "host=10.0.0.5 user=beerapp_backend password=hunter2 constraint=secret_fkey"

_UNAVAILABLE = [
    asyncpg.PostgresConnectionError(_LEAKY),
    asyncpg.ConnectionDoesNotExistError(_LEAKY),
    asyncpg.TooManyConnectionsError(_LEAKY),
    asyncpg.CannotConnectNowError(_LEAKY),
    asyncpg.AdminShutdownError(_LEAKY),
    asyncpg.QueryCanceledError(_LEAKY),
    TimeoutError(_LEAKY),
    ConnectionRefusedError(_LEAKY),
    ConnectionResetError(_LEAKY),
    socket.gaierror(_LEAKY),
]

_NOT_UNAVAILABLE = [
    asyncpg.UndefinedTableError(_LEAKY),
    asyncpg.PostgresSyntaxError(_LEAKY),
    asyncpg.DataError(_LEAKY),
    asyncpg.UniqueViolationError(_LEAKY),
    asyncpg.CheckViolationError(_LEAKY),
    asyncpg.InterfaceError(_LEAKY),
    TypeError(_LEAKY),
    KeyError(_LEAKY),
    ValueError(_LEAKY),
    RuntimeError(_LEAKY),
]


def _id(exc: Exception) -> str:
    return type(exc).__name__


def _client(exc: Exception) -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/boom")
    async def boom():
        raise exc

    # The catch-all handler re-raises after responding (Starlette contract);
    # the test wants the response the client would see.
    return TestClient(app, raise_server_exceptions=False)


@pytest.mark.parametrize("exc", _UNAVAILABLE, ids=_id)
def test_temporary_unavailability_is_a_sanitized_503(exc, caplog):
    with caplog.at_level(logging.DEBUG):
        response = _client(exc).get("/boom")

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "service_unavailable",
            "message": "The service is temporarily unavailable. Please try again.",
        }
    }
    assert "hunter2" not in response.text
    assert "10.0.0.5" not in response.text
    # Logged for operators by exception TYPE only: the message can carry
    # hosts, users or credentials.
    assert "hunter2" not in caplog.text
    assert "10.0.0.5" not in caplog.text


@pytest.mark.parametrize("exc", _NOT_UNAVAILABLE, ids=_id)
def test_programming_and_data_errors_are_never_reported_as_503(exc, caplog):
    with caplog.at_level(logging.DEBUG):
        response = _client(exc).get("/boom")

    assert response.status_code == 500
    assert response.json() == {
        "error": {"code": "internal_error", "message": "An unexpected error occurred."}
    }
    assert "hunter2" not in response.text
    assert "secret_fkey" not in response.text


def test_the_unavailable_set_covers_exactly_what_the_tests_expect():
    for exc in _UNAVAILABLE:
        assert isinstance(exc, DATABASE_UNAVAILABLE_ERRORS), type(exc)
    for exc in _NOT_UNAVAILABLE:
        assert not isinstance(exc, DATABASE_UNAVAILABLE_ERRORS), type(exc)


def test_unhandled_error_response_carries_no_stack_trace_or_type_name():
    response = _client(RuntimeError(_LEAKY)).get("/boom")

    assert response.status_code == 500
    assert "Traceback" not in response.text
    assert "RuntimeError" not in response.text


def test_unhandled_error_is_logged_with_its_traceback_for_operators(caplog):
    with caplog.at_level(logging.ERROR, logger="app.errors"):
        _client(RuntimeError("boom-detail")).get("/boom")

    assert any(r.exc_info for r in caplog.records)


# -- a valid token for an account that no longer exists -----------------------


def test_session_invalid_is_the_same_401_a_bad_token_gets():
    response = _client(SessionInvalidError()).get("/boom")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json() == {
        "error": {"code": "unauthorized", "message": "Missing or invalid credentials."}
    }


# -- 413 envelope code --------------------------------------------------------


def test_payload_too_large_uses_the_standard_envelope():
    from fastapi import HTTPException

    exc = HTTPException(status_code=413, detail="Request body is too large.")
    response = _client(exc).get("/boom")

    assert response.status_code == 413
    assert response.json() == {
        "error": {"code": "payload_too_large", "message": "Request body is too large."}
    }
