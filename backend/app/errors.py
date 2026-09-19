import logging

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("app.errors")

_STATUS_CODES = {
    status.HTTP_400_BAD_REQUEST: "invalid_request",
    status.HTTP_401_UNAUTHORIZED: "unauthorized",
    status.HTTP_404_NOT_FOUND: "not_found",
    status.HTTP_409_CONFLICT: "conflict",
    status.HTTP_422_UNPROCESSABLE_CONTENT: "validation_error",
    status.HTTP_503_SERVICE_UNAVAILABLE: "service_unavailable",
}


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


def _envelope(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    code = _STATUS_CODES.get(exc.status_code, "error")
    return JSONResponse(
        status_code=exc.status_code,
        content=_envelope(code, str(exc.detail)),
        headers=getattr(exc, "headers", None),
    )


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    # Malformed UUIDs, out-of-range page/page_size, and other typed
    # request-shape errors FastAPI/Pydantic owns all land here as 422.
    # There is deliberately no custom validation that turns these into 400 --
    # 400 is reserved for a semantic-but-structurally-valid error, of which
    # Phase 3's six read endpoints have none.
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content=_envelope("validation_error", "Request validation failed."),
    )


async def not_found_handler(request: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content=_envelope("not_found", str(exc)),
    )


async def invalid_request_handler(request: Request, exc: InvalidRequestError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=_envelope("invalid_request", str(exc)),
    )


async def conflict_handler(request: Request, exc: ConflictError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content=_envelope(exc.code, str(exc)),
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    # Catches asyncpg/httpx and any other infrastructure failure. JWT
    # verification failures never reach this handler -- they're caught and
    # converted to 401 inside app.auth itself, and JWKS network failures are
    # raised there as an explicit 503 HTTPException. Raw driver/library
    # exceptions and stack traces never reach the client.
    logger.exception("Unhandled error while processing %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=_envelope("internal_error", "An unexpected error occurred."),
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(NotFoundError, not_found_handler)
    app.add_exception_handler(InvalidRequestError, invalid_request_handler)
    app.add_exception_handler(ConflictError, conflict_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
