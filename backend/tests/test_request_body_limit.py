"""Request-body size limit: enforced from Content-Length AND from the bytes
actually received (chunked / lying clients), returning 413 in the normal error
envelope without ever buffering an unbounded body.

The middleware is exercised at the ASGI level so chunked bodies (no
Content-Length) are real, and so "the body was never read" is observable.
"""

import asyncio
import json
from dataclasses import dataclass

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user
from app.errors import register_exception_handlers
from app.main import create_app
from app.middleware import BodySizeLimitMiddleware

_LIMIT = 100


@dataclass
class _Result:
    status: int
    headers: dict[str, str]
    body: bytes
    receive_calls: int

    def json(self):
        return json.loads(self.body)


def _build_app(limit: int = _LIMIT) -> tuple[FastAPI, list[int]]:
    app = FastAPI()
    register_exception_handlers(app)
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=limit)
    handled: list[int] = []

    @app.post("/count")
    async def count(request: Request):
        handled.append(1)
        return {"bytes": len(await request.body())}

    @app.post("/json")
    async def parse_json(payload: dict):
        handled.append(1)
        return {"keys": len(payload)}

    @app.get("/ping")
    async def ping():
        return {"ok": True}

    return app, handled


async def _call(
    app,
    *,
    method: str = "POST",
    path: str = "/count",
    content_length: int | None = None,
    chunks: tuple[bytes, ...] = (b"",),
    content_type: bytes | None = None,
) -> _Result:
    headers = [(b"host", b"test")]
    if content_length is not None:
        headers.append((b"content-length", str(content_length).encode()))
    if content_type:
        headers.append((b"content-type", content_type))
    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": method,
        "scheme": "http",
        "path": path,
        "raw_path": path.encode(),
        "query_string": b"",
        "root_path": "",
        "headers": headers,
        "client": ("127.0.0.1", 1234),
        "server": ("test", 80),
    }
    state = {"i": 0, "calls": 0}
    sent: list[dict] = []

    async def receive():
        state["calls"] += 1
        if state["i"] < len(chunks):
            body = chunks[state["i"]]
            state["i"] += 1
            return {"type": "http.request", "body": body, "more_body": state["i"] < len(chunks)}
        return {"type": "http.disconnect"}

    async def send(message):
        sent.append(message)

    await app(scope, receive, send)

    start = next(m for m in sent if m["type"] == "http.response.start")
    body = b"".join(m.get("body", b"") for m in sent if m["type"] == "http.response.body")
    return _Result(
        status=start["status"],
        headers={k.decode().lower(): v.decode() for k, v in start["headers"]},
        body=body,
        receive_calls=state["calls"],
    )


def _run(coro):
    return asyncio.run(coro)


# -- Content-Length ------------------------------------------------------------


def test_declared_length_over_the_limit_is_413_without_reading_the_body():
    app, handled = _build_app()

    result = _run(_call(app, content_length=_LIMIT + 1, chunks=(b"x" * (_LIMIT + 1),)))

    assert result.status == 413
    assert result.json() == {
        "error": {"code": "payload_too_large", "message": "Request body is too large."}
    }
    assert handled == []
    assert result.receive_calls == 0


def test_declared_length_exactly_at_the_limit_is_accepted():
    app, handled = _build_app()

    result = _run(_call(app, content_length=_LIMIT, chunks=(b"x" * _LIMIT,)))

    assert result.status == 200
    assert result.json() == {"bytes": _LIMIT}
    assert handled == [1]


def test_a_lying_content_length_cannot_bypass_the_limit():
    app, handled = _build_app()

    # Claims 10 bytes, sends 150: the bytes actually received are what count.
    result = _run(_call(app, content_length=10, chunks=(b"x" * 50,) * 3))

    assert result.status == 413
    assert result.json()["error"]["code"] == "payload_too_large"


# -- streamed / chunked bodies (no Content-Length) ------------------------------


def test_chunked_body_over_the_limit_is_413_and_reading_stops_early():
    app, _ = _build_app()
    chunks = (b"x" * 15,) * 100  # 1500 bytes in 100 chunks

    result = _run(_call(app, chunks=chunks))

    assert result.status == 413
    assert result.json()["error"]["code"] == "payload_too_large"
    # Stops shortly after the limit is crossed rather than draining the stream.
    assert result.receive_calls <= (_LIMIT // 15) + 2


def test_chunked_body_within_the_limit_is_accepted():
    app, handled = _build_app()

    result = _run(_call(app, chunks=(b"x" * 20,) * 4))

    assert result.status == 200
    assert result.json() == {"bytes": 80}
    assert handled == [1]


def test_a_json_body_route_also_yields_413_not_a_generic_400():
    # FastAPI wraps body-read failures in a 400 ("error parsing the body")
    # unless the failure is an HTTPException -- the limit must survive that.
    app, handled = _build_app()
    payload = json.dumps({"k": "v" * 500}).encode()

    result = _run(
        _call(
            app,
            path="/json",
            chunks=(payload[:200], payload[200:400], payload[400:]),
            content_type=b"application/json",
        )
    )

    assert result.status == 413
    assert result.json()["error"]["code"] == "payload_too_large"
    assert handled == []


def test_requests_without_a_body_are_unaffected():
    app, _ = _build_app()

    result = _run(_call(app, method="GET", path="/ping"))

    assert result.status == 200


def test_the_413_message_reveals_nothing_about_the_request():
    app, _ = _build_app()

    result = _run(_call(app, content_length=10_000, chunks=(b"secret-token",)))

    assert b"secret-token" not in result.body


# -- wired into the real application --------------------------------------------


def _real_client(limit: int) -> TestClient:
    app = create_app(docs_enabled=False, max_request_body_bytes=limit)

    def _unauthorized():
        from fastapi import HTTPException

        raise HTTPException(
            status_code=401,
            detail="Missing or invalid credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    app.dependency_overrides[get_current_user] = _unauthorized
    return TestClient(app, raise_server_exceptions=False)


def test_the_real_app_rejects_an_oversized_body_before_authentication_runs():
    client = _real_client(200)

    response = client.post("/beer-logs", json={"review": "x" * 1000})

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "payload_too_large"


def test_the_real_app_still_reaches_authentication_for_a_normal_body():
    client = _real_client(200)

    response = client.post("/beer-logs", json={"beer_id": "44444444-4444-4444-4444-444444444444"})

    assert response.status_code == 401


def test_the_default_limit_leaves_ample_room_for_the_largest_legitimate_body():
    from app.config import RuntimeSettings

    # Largest legitimate JSON body: a beer log with every text field full and
    # 4-byte characters (review 2000 + note 500 + venue 200) is ~11 KB.
    largest_legitimate = (2000 + 500 + 200) * 4 + 1024
    assert RuntimeSettings(_env_file=None).max_request_body_bytes >= largest_legitimate
