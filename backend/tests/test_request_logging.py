"""Request logging: one line per request with a request id, method, PATH (never
the query string), status and duration -- and nothing sensitive.

Never logged: request bodies, the Authorization header or any token, query
strings (they carry search text and barcodes), database URLs, Supabase keys.
"""

import logging

import pytest
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.errors import register_exception_handlers
from app.logging_config import configure_logging
from app.middleware import RequestLogMiddleware, resolve_request_id

_SECRET_TOKEN = "eyJhbGciOiJFUzI1NiJ9.SECRET-PAYLOAD.SECRET-SIGNATURE"
_SECRET_BODY = "hunter2-password-in-body"


def _client() -> TestClient:
    app = FastAPI()
    register_exception_handlers(app)
    app.add_middleware(RequestLogMiddleware)

    @app.get("/items/{item_id}")
    async def item(item_id: str):
        return {"id": item_id}

    @app.post("/submit")
    async def submit(request: Request):
        await request.body()
        return {"ok": True}

    @app.get("/boom")
    async def boom():
        raise RuntimeError("internal detail")

    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def access_log(caplog):
    with caplog.at_level(logging.INFO, logger="app.access"):
        yield caplog


def _access_records(caplog):
    return [r for r in caplog.records if r.name == "app.access"]


# -- what is logged ------------------------------------------------------------


def test_one_line_per_request_with_method_path_status_duration_and_request_id(access_log):
    response = _client().get("/items/42")

    (record,) = _access_records(access_log)
    message = record.getMessage()
    assert "method=GET" in message
    assert "path=/items/{item_id}" in message  # the route template, not the raw id
    assert "status=200" in message
    assert "duration_ms=" in message
    assert f"request_id={response.headers['x-request-id']}" in message


def test_the_query_string_is_never_logged(access_log):
    _client().get("/items/42", params={"q": "secret-search", "token": "abc123", "barcode": "5000"})

    text = access_log.text
    for leaked in ("secret-search", "abc123", "5000", "q=", "token="):
        assert leaked not in text


def test_authorization_headers_and_tokens_are_never_logged(access_log):
    _client().get("/items/42", headers={"Authorization": f"Bearer {_SECRET_TOKEN}"})

    assert "SECRET" not in access_log.text
    assert "Bearer" not in access_log.text
    assert "eyJ" not in access_log.text


def test_request_bodies_are_never_logged(access_log):
    _client().post("/submit", json={"password": _SECRET_BODY})

    assert _SECRET_BODY not in access_log.text
    assert "password" not in access_log.text


def test_an_unmatched_path_is_logged_without_its_query_string(access_log):
    response = _client().get("/no/such/route", params={"q": "secret-search"})

    assert response.status_code == 404
    (record,) = _access_records(access_log)
    assert "path=/no/such/route" in record.getMessage()
    assert "status=404" in record.getMessage()
    assert "secret-search" not in access_log.text


def test_a_very_long_unmatched_path_is_truncated_in_the_log(access_log):
    _client().get("/" + "a" * 5000)

    (record,) = _access_records(access_log)
    assert len(record.getMessage()) < 500


# -- request ids -----------------------------------------------------------------


def test_every_response_carries_a_generated_request_id():
    response = _client().get("/items/1")

    request_id = response.headers["x-request-id"]
    assert len(request_id) == 32 and set(request_id) <= set("0123456789abcdef")


def test_distinct_requests_get_distinct_ids():
    client = _client()

    assert (
        client.get("/items/1").headers["x-request-id"]
        != client.get("/items/1").headers["x-request-id"]
    )


def test_a_well_formed_incoming_request_id_is_kept():
    response = _client().get("/items/1", headers={"X-Request-ID": "trace-abc_123.9"})

    assert response.headers["x-request-id"] == "trace-abc_123.9"


@pytest.mark.parametrize(
    "unsafe",
    ["has space", "x" * 65, "semi;colon", 'quote"', "new\nline", "", "<script>", "a/b"],
)
def test_an_unsafe_incoming_request_id_is_replaced(unsafe):
    generated = resolve_request_id(unsafe)

    assert generated != unsafe
    assert len(generated) == 32


def test_resolve_request_id_keeps_safe_values_and_generates_when_absent():
    assert resolve_request_id("abc-123") == "abc-123"
    assert len(resolve_request_id(None)) == 32


# -- failures --------------------------------------------------------------------


def test_an_unhandled_error_is_logged_as_500_and_still_returns_the_request_id(access_log):
    response = _client().get("/boom")

    assert response.status_code == 500
    (record,) = _access_records(access_log)
    assert "status=500" in record.getMessage()
    assert response.headers["x-request-id"] in record.getMessage()
    assert "internal detail" not in record.getMessage()


def test_the_500_body_stays_the_sanitized_envelope():
    response = _client().get("/boom")

    assert response.json() == {
        "error": {"code": "internal_error", "message": "An unexpected error occurred."}
    }


def test_the_operator_error_log_correlates_by_request_id(caplog):
    with caplog.at_level(logging.ERROR, logger="app.errors"):
        response = _client().get("/boom")

    (record,) = [r for r in caplog.records if r.name == "app.errors"]
    assert response.headers["x-request-id"] in record.getMessage()
    assert "/boom" in record.getMessage()


# -- configuration -----------------------------------------------------------------


@pytest.fixture
def restore_loggers():
    names = ["app", "uvicorn.access", "httpx", "httpcore"]
    saved = {n: logging.getLogger(n).level for n in names}
    yield
    for name, level in saved.items():
        logging.getLogger(name).setLevel(level)


def test_configure_logging_sets_the_app_level_and_quiets_noisy_libraries(restore_loggers):
    configure_logging("WARNING")

    assert logging.getLogger("app").level == logging.WARNING
    # uvicorn's own access log includes the query string; ours replaces it.
    assert logging.getLogger("uvicorn.access").level >= logging.WARNING
    assert logging.getLogger("httpx").level >= logging.WARNING
    assert logging.getLogger("httpcore").level >= logging.WARNING


def test_configure_logging_is_idempotent(restore_loggers):
    logger = logging.getLogger("app")
    before = len(logger.handlers)

    configure_logging("INFO")
    configure_logging("INFO")

    assert len(logger.handlers) - before <= 1
