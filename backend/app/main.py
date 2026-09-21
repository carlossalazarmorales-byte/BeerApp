from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI

from app.auth.jwks import JWKSCache
from app.config import get_runtime_settings, get_settings
from app.db import create_pool
from app.errors import register_exception_handlers
from app.logging_config import configure_logging
from app.middleware import BodySizeLimitMiddleware, RequestLogMiddleware
from app.routes import (
    account,
    achievements,
    beer_logs,
    beer_styles,
    beers,
    breweries,
    collection,
    contributions,
    countries,
    statistics,
)
from app.routes import map as map_routes

_DEFAULT_MAX_REQUEST_BODY_BYTES = 65_536


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(settings.log_level)
    app.state.pool = await create_pool(settings)
    app.state.http_client = httpx.AsyncClient()
    app.state.jwks_cache = JWKSCache(
        settings.jwks_url,
        app.state.http_client,
        ttl_seconds=settings.jwks_cache_ttl_seconds,
        refresh_cooldown_seconds=settings.jwks_refresh_cooldown_seconds,
    )
    try:
        yield
    finally:
        try:
            await app.state.http_client.aclose()
        finally:
            await app.state.pool.close()


def create_app(
    *,
    docs_enabled: bool = True,
    max_request_body_bytes: int = _DEFAULT_MAX_REQUEST_BODY_BYTES,
) -> FastAPI:
    """Build the application.

    `docs_enabled` controls the interactive API docs (/docs, /redoc,
    /openapi.json): on for local/dev only, off everywhere else, so a deployed
    API does not publish its own schema. See app/config.py.
    """
    docs_kwargs = {} if docs_enabled else {"docs_url": None, "redoc_url": None, "openapi_url": None}
    app = FastAPI(
        title="BeerApp API",
        version="0.1.0",
        lifespan=lifespan,
        **docs_kwargs,
    )

    register_exception_handlers(app)

    # Starlette runs the LAST-added middleware outermost: request logging wraps
    # the body limit, so an oversized request is logged (as 413) too.
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=max_request_body_bytes)
    app.add_middleware(RequestLogMiddleware)

    app.include_router(countries.router)
    app.include_router(beer_styles.router)
    app.include_router(breweries.router)
    app.include_router(beers.router)
    app.include_router(beer_logs.router)
    app.include_router(collection.router)
    app.include_router(map_routes.router)
    app.include_router(statistics.router)
    app.include_router(achievements.router)
    app.include_router(contributions.router)
    app.include_router(account.router)

    @app.get(
        "/health",
        tags=["system"],
        description=(
            "Liveness probe only: reports that the process is up and serving HTTP. "
            "It is unauthenticated and identical in every environment, and it "
            "deliberately does NOT check the database, Supabase or authentication "
            "-- a database outage must not make an orchestrator restart a healthy "
            "process. It is not a readiness check."
        ),
    )
    async def health_check() -> dict[str, str]:
        return {"status": "ok"}

    return app


# Built at import from settings that need no secrets, so importing `app.main`
# (tests, tooling) never requires a populated .env.
_runtime = get_runtime_settings()
app = create_app(
    docs_enabled=_runtime.docs_enabled,
    max_request_body_bytes=_runtime.max_request_body_bytes,
)
