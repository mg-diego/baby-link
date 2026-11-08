from datetime import date
from typing import Callable

from core.timeutils import parse_ts
from models.analytics_models import DailySummary
from models.event_models import EventCategory
from repositories.analytics_repository import AnalyticsRepository
from services.analytics.diapers import DiaperStats
from services.analytics.feeding import FeedingStats
from services.analytics.growth import GrowthStats
from services.analytics.sleep import SleepStats

# Códigos estables de la API (category -> subcategories). La app traduce sus etiquetas a esto.
STAT_CODES: dict[str, tuple[str, ...]] = {
    "sleep": ("all", "naps", "night", "wakings"),
    "feeding": ("all", "bottle", "nursing", "solids"),
    "diapers": ("all", "wet", "dirty"),
    "growth": ("all", "weight", "height", "head"),
}

class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository):
        self.repository = repository
        self.sleep = SleepStats(repository)
        self.feeding = FeedingStats(repository)
        self.diapers = DiaperStats(repository)
        self.growth = GrowthStats(repository)

    def get_events_by_date_range(self, baby_id: str, start_date: date, end_date: date) -> list:
        return self.repository.get_events_by_date_range(baby_id, start_date, end_date)

    def get_daily_summary(self, baby_id: str, target_date: date) -> DailySummary:
        events = self.repository.get_events_by_date_range(baby_id, target_date, target_date)
        total_nap = total_feeds = total_dirty = 0
        for event in events:
            category = event.get("category")
            if category == EventCategory.NAP.value:
                start, end = parse_ts(event.get("start_time")), parse_ts(event.get("end_time"))
                if start and end:
                    total_nap += int((end - start).total_seconds() / 60)
            elif category == EventCategory.FEED.value:
                total_feeds += 1
            elif category == EventCategory.DIAPER.value:
                if (event.get("metadata") or {}).get("condition") in ("dirty", "mixed"):
                    total_dirty += 1
        return DailySummary(
            target_date=target_date,
            total_nap_minutes=total_nap,
            total_feeds=total_feeds,
            total_dirty_diapers=total_dirty,
        )

    def generate_stats(self, baby_id: str, start: date, end: date, category: str, subcategory: str) -> dict | None:
        """`category`/`subcategory` son códigos de STAT_CODES. Devuelve None si no existen."""
        handlers: dict[tuple[str, str], Callable[[], dict]] = {
            ("sleep", "all"): lambda: self.sleep.generate_sleep_overview_stats(baby_id, start, end),
            ("sleep", "naps"): lambda: self.sleep.generate_nap_sleep_stats(baby_id, start, end),
            ("sleep", "night"): lambda: self.sleep.generate_night_sleep_stats(baby_id, start, end),
            ("sleep", "wakings"): lambda: self.sleep.generate_night_waking_stats(baby_id, start, end),
            ("feeding", "all"): lambda: self.feeding.generate_feed_analytics(baby_id, start, end),
            ("feeding", "bottle"): lambda: self.feeding.generate_bottle_stats(baby_id, start, end),
            ("feeding", "nursing"): lambda: self.feeding.generate_nursing_stats(baby_id, start, end),
            ("feeding", "solids"): lambda: self.feeding.generate_solids_stats(baby_id, start, end),
            ("diapers", "all"): lambda: self.diapers.generate_diaper_stats(baby_id, start, end),
            ("diapers", "wet"): lambda: self.diapers.generate_diaper_stats(baby_id, start, end, only="wet"),
            ("diapers", "dirty"): lambda: self.diapers.generate_diaper_stats(baby_id, start, end, only="dirty"),
            ("growth", "all"): lambda: self.growth.generate_growth_stats(baby_id, end, "Peso"),
            ("growth", "weight"): lambda: self.growth.generate_growth_stats(baby_id, end, "Peso"),
            ("growth", "height"): lambda: self.growth.generate_growth_stats(baby_id, end, "Altura"),
            ("growth", "head"): lambda: self.growth.generate_growth_stats(baby_id, end, "Perímetro"),
        }
        handler = handlers.get((category, subcategory))
        return handler() if handler else None
