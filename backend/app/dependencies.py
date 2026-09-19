import asyncpg
import httpx
from fastapi import Depends, Request

from app.config import Settings, get_settings
from app.repositories.achievements import AchievementsRepository
from app.repositories.beer_logs import BeerLogRepository
from app.repositories.beer_styles import BeerStyleRepository
from app.repositories.beers import BeerRepository
from app.repositories.breweries import BreweryRepository
from app.repositories.collection import CollectionRepository
from app.repositories.contributions import ContributionRepository
from app.repositories.countries import CountryRepository
from app.repositories.map import MapRepository
from app.repositories.statistics import StatisticsRepository
from app.services.account import AccountService
from app.services.achievement_evaluator import AchievementEvaluator
from app.services.achievements import AchievementsService
from app.services.beer_logs import BeerLogService
from app.services.beer_styles import BeerStyleService
from app.services.beers import BeerService
from app.services.breweries import BreweryService
from app.services.collection import CollectionService
from app.services.contributions import ContributionService
from app.services.countries import CountryService
from app.services.map import MapService
from app.services.statistics import StatisticsService
from app.services.supabase_admin_client import SupabaseAdminClient


def get_db_pool(request: Request) -> asyncpg.Pool:
    return request.app.state.pool


def get_http_client(request: Request) -> httpx.AsyncClient:
    return request.app.state.http_client


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


def get_contribution_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> ContributionService:
    # The catalog repositories are injected for READS only (duplicate
    # detection) -- see ContributionService.
    return ContributionService(
        ContributionRepository(pool), BeerRepository(pool), BreweryRepository(pool)
    )


def get_achievements_repository() -> AchievementsRepository:
    # No pool dependency -- every method takes an already-open connection
    # supplied by the caller (see docs/DECISIONS.md).
    return AchievementsRepository()


def get_achievement_evaluator(
    repository: AchievementsRepository = Depends(get_achievements_repository),
) -> AchievementEvaluator:
    return AchievementEvaluator(repository)


def get_collection_service(
    pool: asyncpg.Pool = Depends(get_db_pool),
    achievement_evaluator: AchievementEvaluator = Depends(get_achievement_evaluator),
) -> CollectionService:
    return CollectionService(CollectionRepository(pool), pool, achievement_evaluator)


def get_map_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> MapService:
    return MapService(MapRepository(pool))


def get_statistics_service(pool: asyncpg.Pool = Depends(get_db_pool)) -> StatisticsService:
    return StatisticsService(StatisticsRepository(pool))


def get_achievements_service(
    pool: asyncpg.Pool = Depends(get_db_pool),
    repository: AchievementsRepository = Depends(get_achievements_repository),
    evaluator: AchievementEvaluator = Depends(get_achievement_evaluator),
) -> AchievementsService:
    return AchievementsService(pool, repository, evaluator)


def get_supabase_admin_client(
    http_client: httpx.AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings),
) -> SupabaseAdminClient:
    return SupabaseAdminClient(
        http_client,
        supabase_url=settings.supabase_url,
        secret_key=settings.supabase_secret_key,
    )


def get_account_service(
    admin_client: SupabaseAdminClient = Depends(get_supabase_admin_client),
) -> AccountService:
    return AccountService(admin_client)
