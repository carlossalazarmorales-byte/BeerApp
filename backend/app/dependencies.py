import asyncpg
from fastapi import Depends, Request

from app.repositories.beer_logs import BeerLogRepository
from app.repositories.beer_styles import BeerStyleRepository
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.collection import CollectionRepository
from app.repositories.countries import CountryRepository
from app.repositories.map import MapRepository
from app.repositories.statistics import StatisticsRepository
from app.services.beer_logs import BeerLogService
from app.services.beer_styles import BeerStyleService
from app.services.beers import BeerService
from app.services.breweries import BreweryService
from app.services.collection import CollectionService
from app.services.countries import CountryService
from app.services.map import MapService
from app.services.statistics import StatisticsService


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


def get_collection_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> CollectionService:
    return CollectionService(CollectionRepository(pool))


def get_map_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> MapService:
    return MapService(MapRepository(pool))


def get_statistics_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> StatisticsService:
    return StatisticsService(StatisticsRepository(pool))
