import logging

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("app.errors")

_STATUS_CODES = {
    status.HTTP_401_UNAUTHORIZED: "unauthorized",
    status.HTTP_404_NOT_FOUND: "not_found",
    status.HTTP_422_UNPROCESSABLE_CONTENT: "validation_error",
    status.HTTP_503_SERVICE_UNAVAILABLE: "service_unavailable",
}


class NotFoundError(Exception):
    """Raised by a service when a requested catalog entity doesn't exist."""


def _envelope(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


async def http_exception_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
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


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    # Catches asyncpg/httpx and any other infrastructure failure. JWT
    # verification failures never reach this handler -- they're caught and
    # converted to 401 inside app.auth itself, and JWKS network failures are
    # raised there as an explicit 503 HTTPException. Raw driver/library
    # exceptions and stack traces never reach the client.
    logger.exception(
        "Unhandled error while processing %s %s", request.method, request.url.path
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=_envelope("internal_error", "An unexpected error occurred."),
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(NotFoundError, not_found_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
