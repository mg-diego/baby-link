import hmac
from functools import lru_cache
from typing import Optional

from fastapi import Depends, Header
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client, create_client

from core.auth import TokenVerifier
from core.config import Settings, get_settings
from core.errors import UnauthorizedError
from repositories.analytics_repository import AnalyticsRepository
from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository
from services.access_service import AccessService, BabyContext
from services.analytics import AnalyticsService
from services.baby_service import BabyService
from services.event_service import EventService
from services.home_assistant_service import HomeAssistantService
from services.prediction_service import PredictionService


# ─── Infraestructura ──────────────────────────────────────────────────────────

@lru_cache
def get_supabase() -> Client:
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)


@lru_cache
def get_token_verifier() -> TokenVerifier:
    settings = get_settings()

    def remote_lookup(token: str) -> str | None:
        response = get_supabase().auth.get_user(token)
        return response.user.id if response and response.user else None

    return TokenVerifier(settings.supabase_url, settings.supabase_jwt_secret, remote_lookup)


# ─── Autenticación ────────────────────────────────────────────────────────────

_bearer = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
    verifier: TokenVerifier = Depends(get_token_verifier),
) -> str:
    """user_id del token de Supabase. Sin token válido -> 401."""
    if credentials is None:
        raise UnauthorizedError("Falta el token de autenticación")
    return verifier.verify(credentials.credentials)


def require_home_assistant_key(
    x_api_key: Optional[str] = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    expected = settings.home_assistant_api_key
    if not expected or not x_api_key or not hmac.compare_digest(x_api_key, expected):
        raise UnauthorizedError("API key de Home Assistant no válida")


# ─── Repositorios ─────────────────────────────────────────────────────────────

def get_event_repository(db: Client = Depends(get_supabase)) -> EventRepository:
    return EventRepository(db)


def get_baby_repository(db: Client = Depends(get_supabase)) -> BabyRepository:
    return BabyRepository(db)


# ─── Autorización ─────────────────────────────────────────────────────────────

def get_access_service(
    baby_repository: BabyRepository = Depends(get_baby_repository),
    event_repository: EventRepository = Depends(get_event_repository),
    settings: Settings = Depends(get_settings),
) -> AccessService:
    return AccessService(baby_repository, event_repository, settings.tz)


def authorized_baby(
    baby_id: str,
    user_id: str = Depends(get_current_user_id),
    access: AccessService = Depends(get_access_service),
) -> BabyContext:
    """Bebé de la URL, comprobando que es del usuario. Incluye su zona horaria."""
    return access.get_baby(user_id, baby_id)


def authorized_event(
    event_id: str,
    user_id: str = Depends(get_current_user_id),
    access: AccessService = Depends(get_access_service),
) -> dict:
    return access.ensure_event(user_id, event_id)


# ─── Servicios ────────────────────────────────────────────────────────────────

def get_event_service(repository: EventRepository = Depends(get_event_repository)) -> EventService:
    return EventService(repository)


def get_baby_service(repository: BabyRepository = Depends(get_baby_repository)) -> BabyService:
    return BabyService(repository)


def get_analytics_service(
    baby: BabyContext = Depends(authorized_baby), db: Client = Depends(get_supabase)
) -> AnalyticsService:
    # Las estadísticas se calculan en la zona horaria del bebé
    return AnalyticsService(AnalyticsRepository(db, baby.tz))


def get_prediction_service(
    event_repository: EventRepository = Depends(get_event_repository),
    baby_repository: BabyRepository = Depends(get_baby_repository),
    settings: Settings = Depends(get_settings),
) -> PredictionService:
    return PredictionService(event_repository, baby_repository, settings.tz)


def get_home_assistant_service(
    baby_repository: BabyRepository = Depends(get_baby_repository),
    event_repository: EventRepository = Depends(get_event_repository),
    settings: Settings = Depends(get_settings),
) -> HomeAssistantService:
    return HomeAssistantService(baby_repository, event_repository, settings.tz)
