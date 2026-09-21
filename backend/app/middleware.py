"""Pure-ASGI middleware: request body size limit and request logging.

Pure ASGI (not `BaseHTTPMiddleware`) so a streamed body can be counted as it
arrives, and so a downstream failure is logged without swallowing it.
"""

import logging
import re
import time
import uuid

from starlette.datastructures import MutableHeaders
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.errors import error_envelope

access_logger = logging.getLogger("app.access")

_TOO_LARGE_MESSAGE = "Request body is too large."
_REQUEST_ID_PATTERN = re.compile(r"[A-Za-z0-9._-]{1,64}")
# An unmatched path is attacker-controlled text; keep the log line bounded.
_MAX_LOGGED_PATH = 200


def resolve_request_id(candidate: str | None) -> str:
    """Keep a client-supplied X-Request-ID only if it is short and made of
    safe characters (so it can never inject into a log line or header);
    otherwise generate a fresh one.
    """
    if candidate and _REQUEST_ID_PATTERN.fullmatch(candidate):
        return candidate
    return uuid.uuid4().hex


def _header(scope: Scope, name: bytes) -> str | None:
    for key, value in scope.get("headers", []):
        if key == name:
            return value.decode("latin-1")
    return None


class BodySizeLimitMiddleware:
    """Rejects a request body larger than `max_bytes` with 413 in the normal
    error envelope.

    Two independent checks, because neither alone is enough:
    - a declared `Content-Length` over the limit is refused immediately,
      without reading any of the body;
    - the bytes actually received are counted as they stream in, so a chunked
      body (no Content-Length) or a client that understates its length is still
      cut off as soon as the limit is crossed -- the server never buffers an
      unbounded body. That failure is raised as an `HTTPException(413)` from
      `receive()`, which FastAPI's body parsing re-raises untouched and the
      standard handler turns into the envelope.
    """

    def __init__(self, app: ASGIApp, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        declared = _header(scope, b"content-length")
        if declared is not None and declared.isascii() and declared.isdigit():
            if int(declared) > self.max_bytes:
                response = JSONResponse(
                    status_code=413,
                    content=error_envelope("payload_too_large", _TOO_LARGE_MESSAGE),
                )
                await response(scope, receive, send)
                return

        received = 0

        async def limited_receive() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    raise HTTPException(status_code=413, detail=_TOO_LARGE_MESSAGE)
            return message

        await self.app(scope, limited_receive, send)


class RequestLogMiddleware:
    """One log line per request: request id, method, path, status, duration.

    The path is the matched route TEMPLATE (`/beers/{beer_id}`) when there is
    one, else the raw path truncated -- never the query string, which carries
    search text and barcodes. Request bodies, the Authorization header and
    tokens are never read or logged. Also stamps every response with
    `X-Request-ID` and exposes the id to error handlers via `request.state`.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = resolve_request_id(_header(scope, b"x-request-id"))
        scope.setdefault("state", {})["request_id"] = request_id
        started = time.perf_counter()
        # If the app raises before responding, the 500 is produced by the
        # outer error middleware, so 500 is the truthful default.
        status_code = 500

        async def send_with_request_id(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                message.setdefault("headers", [])
                MutableHeaders(scope=message)["X-Request-ID"] = request_id
            await send(message)

        try:
            await self.app(scope, receive, send_with_request_id)
        finally:
            route = scope.get("route")
            path = getattr(route, "path", None) or str(scope.get("path", ""))[:_MAX_LOGGED_PATH]
            access_logger.info(
                "request_id=%s method=%s path=%s status=%s duration_ms=%.1f",
                request_id,
                scope.get("method", "-"),
                path,
                status_code,
                (time.perf_counter() - started) * 1000,
            )
