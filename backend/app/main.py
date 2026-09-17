from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI

from app.auth.jwks import JWKSCache
from app.config import get_settings
from app.db import create_pool
from app.errors import register_exception_handlers
from app.routes import (
    achievements,
    beer_logs,
    beer_styles,
    beers,
    breweries,
    collection,
    countries,
    statistics,
)
from app.routes import map as map_routes


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    app.state.pool = await create_pool(settings)
    app.state.http_client = httpx.AsyncClient()
    app.state.jwks_cache = JWKSCache(settings.jwks_url, app.state.http_client)
    try:
        yield
    finally:
        await app.state.http_client.aclose()
        await app.state.pool.close()


app = FastAPI(
    title="BeerApp API",
    version="0.1.0",
    lifespan=lifespan,
)

register_exception_handlers(app)

app.include_router(countries.router)
app.include_router(beer_styles.router)
app.include_router(breweries.router)
app.include_router(beers.router)
app.include_router(beer_logs.router)
app.include_router(collection.router)
app.include_router(map_routes.router)
app.include_router(statistics.router)
app.include_router(achievements.router)


@app.get("/health", tags=["system"])
async def health_check() -> dict[str, str]:
    return {"status": "ok"}
