import asyncpg
from fastapi import Depends, Request

from app.repositories.beer_logs import BeerLogRepository
from app.repositories.beer_styles import BeerStyleRepository
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.countries import CountryRepository
from app.services.beer_logs import BeerLogService
from app.services.beer_styles import BeerStyleService
from app.services.beers import BeerService
from app.services.breweries import BreweryService
from app.services.countries import CountryService


def get_db_pool(request: Request) -> asyncpg.Pool:
    return request.app.state.pool


def get_country_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> CountryService:
    return CountryService(CountryRepository(pool))


def get_beer_style_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> BeerStyleService:
    return BeerStyleService(BeerStyleRepository(pool))


def get_brewery_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> BreweryService:
    return BreweryService(BreweryRepository(pool))


def get_beer_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> BeerService:
    return BeerService(BeerRepository(pool))


def get_beer_log_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> BeerLogService:
    return BeerLogService(BeerLogRepository(pool))
