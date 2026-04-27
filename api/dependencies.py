import os
from fastapi import Depends
from supabase import create_client, Client
from dotenv import load_dotenv

from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository
from repositories.analytics_repository import AnalyticsRepository

from services.baby_service import BabyService
from services.event_service import EventService
from services.analytics_service import AnalyticsService

load_dotenv()

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")
supabase_client: Client = create_client(url, key)

def get_supabase() -> Client:
    return supabase_client

def get_event_repository(db: Client = Depends(get_supabase)) -> EventRepository:
    return EventRepository(db)

def get_event_service(repository: EventRepository = Depends(get_event_repository)) -> EventService:
    return EventService(repository)

def get_baby_repository(db: Client = Depends(get_supabase)) -> BabyRepository:
    return BabyRepository(db)

def get_baby_service(repository: BabyRepository = Depends(get_baby_repository)) -> BabyService:
    return BabyService(repository)

def get_analytics_repository(db: Client = Depends(get_supabase)) -> AnalyticsRepository:
    return AnalyticsRepository(db)

def get_analytics_service(repository: AnalyticsRepository = Depends(get_analytics_repository)) -> AnalyticsService:
    return AnalyticsService(repository)