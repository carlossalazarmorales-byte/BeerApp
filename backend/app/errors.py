import logging
import socket

import asyncpg
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("app.errors")

# The one message for a missing/invalid/expired token AND for a valid token
# whose account no longer exists -- identical on purpose, so the two cannot be
# told apart (and nothing about any other user is revealed).
UNAUTHORIZED_MESSAGE = "Missing or invalid credentials."

UNAVAILABLE_MESSAGE = "The service is temporarily unavailable. Please try again."

_STATUS_CODES = {
    status.HTTP_400_BAD_REQUEST: "invalid_request",
    status.HTTP_401_UNAUTHORIZED: "unauthorized",
    status.HTTP_404_NOT_FOUND: "not_found",
    status.HTTP_409_CONFLICT: "conflict",
    status.HTTP_413_CONTENT_TOO_LARGE: "payload_too_large",
    status.HTTP_422_UNPROCESSABLE_CONTENT: "validation_error",
    status.HTTP_503_SERVICE_UNAVAILABLE: "service_unavailable",
}

# Genuine, TEMPORARY availability failures of the database or the network path
# to it -- the caller did nothing wrong and a retry may succeed -- reported as
# a sanitized 503. Deliberately narrow: constraint violations, bad SQL, data
# errors, `asyncpg.InterfaceError` and every other exception are bugs or
# invalid state, not "try again later", and stay 500.
#
# - PostgresConnectionError: connection lost / could not connect / rejected.
# - TooManyConnectionsError, CannotConnectNowError, AdminShutdownError,
#   CrashShutdownError: the server is saturated, starting up or going down.
# - QueryCanceledError: the server cancelled a statement (statement_timeout).
# - TimeoutError: our own acquire/command timeouts (asyncio.TimeoutError is
#   TimeoutError on Python 3.11+).
# - ConnectionError (refused/reset/aborted) and socket.gaierror (DNS): the
#   network path to the database.
DATABASE_UNAVAILABLE_ERRORS: tuple[type[BaseException], ...] = (
    asyncpg.PostgresConnectionError,
    asyncpg.TooManyConnectionsError,
    asyncpg.CannotConnectNowError,
    asyncpg.AdminShutdownError,
    asyncpg.CrashShutdownError,
    asyncpg.QueryCanceledError,
    TimeoutError,
    ConnectionError,
    socket.gaierror,
)


class NotFoundError(Exception):
    """Raised by a service when a requested entity doesn't exist, or exists
    but isn't owned by the caller -- the two cases are deliberately
    indistinguishable to the client (see beer_logs).
    """


class InvalidRequestError(Exception):
    """Raised by a service for a request that is structurally valid but
    semantically wrong given the resource's current state (e.g. a future
    consumed_at, or a price/currency pairing that would result from a PATCH
    on a beer log). First real use of the 400 status -- Phase 3's read-only
    endpoints had no such case.
    """


class ConflictError(Exception):
    """Raised by a service when a request is well-formed but collides with
    existing state -- first used by Phase 13 contributions (a barcode already
    in the catalog, or the caller's own identical pending suggestion).

    Unlike the other error classes, `code` is a specific machine-readable
    reason carried in the standard envelope's `error.code` (e.g.
    `barcode_in_catalog`), because a client must be able to tell two
    different 409 causes apart without parsing the human message.
    """

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class SessionInvalidError(Exception):
    """Raised by a service when a write fails because the caller's own account
    no longer exists -- i.e. a still-valid access token for a user that was
    deleted (`DELETE /account` cannot revoke an already-issued access JWT).

    Reported as the same 401 a bad token gets, not a 404: the credential no
    longer corresponds to an account. It says nothing about any other user's
    data or whether any other resource exists.
    """


def error_envelope(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


def _request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    code = _STATUS_CODES.get(exc.status_code, "error")
    return JSONResponse(
        status_code=exc.status_code,
        content=error_envelope(code, str(exc.detail)),
        headers=getattr(exc, "headers", None),
    )


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    # Malformed UUIDs, out-of-range page/page_size, and other typed
    # request-shape errors FastAPI/Pydantic owns all land here as 422.
    # There is deliberately no custom validation that turns these into 400 --
    # 400 is reserved for a semantic-but-structurally-valid error, of which
    # Phase 3's six read endpoints have none. The message never echoes the
    # offending value.
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content=error_envelope("validation_error", "Request validation failed."),
    )


async def not_found_handler(request: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content=error_envelope("not_found", str(exc)),
    )


async def invalid_request_handler(request: Request, exc: InvalidRequestError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=error_envelope("invalid_request", str(exc)),
    )


async def conflict_handler(request: Request, exc: ConflictError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content=error_envelope(exc.code, str(exc)),
    )


async def session_invalid_handler(request: Request, exc: SessionInvalidError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_401_UNAUTHORIZED,
        content=error_envelope("unauthorized", UNAUTHORIZED_MESSAGE),
        headers={"WWW-Authenticate": "Bearer"},
    )


async def database_unavailable_handler(request: Request, exc: Exception) -> JSONResponse:
    # Logged by exception TYPE only: the message of a driver/network error can
    # carry hosts, usernames, or fragments of a connection string.
    logger.warning(
        "Database unavailable while processing %s %s: %s (request_id=%s)",
        request.method,
        request.url.path,
        type(exc).__name__,
        _request_id(request),
    )
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=error_envelope("service_unavailable", UNAVAILABLE_MESSAGE),
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    # Catches asyncpg/httpx and any other infrastructure failure. JWT
    # verification failures never reach this handler -- they're caught and
    # converted to 401 inside app.auth itself, and JWKS network failures are
    # raised there as an explicit 503 HTTPException. Raw driver/library
    # exceptions and stack traces never reach the client; the full traceback
    # goes to the server log only, correlated by request id.
    request_id = _request_id(request)
    logger.exception(
        "Unhandled error while processing %s %s (request_id=%s)",
        request.method,
        request.url.path,
        request_id,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_envelope("internal_error", "An unexpected error occurred."),
        # The 500 is produced outside the request-log middleware, so it adds
        # the correlation header itself.
        headers={"X-Request-ID": request_id} if request_id else None,
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(NotFoundError, not_found_handler)
    app.add_exception_handler(InvalidRequestError, invalid_request_handler)
    app.add_exception_handler(ConflictError, conflict_handler)
    app.add_exception_handler(SessionInvalidError, session_invalid_handler)
    for exception_type in DATABASE_UNAVAILABLE_ERRORS:
        app.add_exception_handler(exception_type, database_unavailable_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
