from datetime import datetime, date, timezone
from typing import Dict, Any

from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository
from models.event_models import EventCategory

class HomeAssistantService:
    def __init__(self, baby_repository: BabyRepository, event_repository: EventRepository):
        self.baby_repository = baby_repository
        self.event_repository = event_repository

    async def get_summary(self, baby_id: str) -> Dict[str, Any]:
        baby_name = "Ona"
        today = date.today()
        now_utc = datetime.now(timezone.utc)
        today_start = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
        today_end = datetime.combine(today, datetime.max.time(), tzinfo=timezone.utc)

        all_recent_events = self.event_repository.get_recent_events(baby_id) or []
        
        total_sleep_mins = 0
        total_feeds = 0
        total_diapers = 0

        for event in all_recent_events:
            category = event.get("category")
            start_str = event.get("start_time")
            if not start_str:
                continue

            start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
            end_str = event.get("end_time")

            if category in [EventCategory.NAP.value, EventCategory.BED_TIME.value]:
                end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00')) if end_str else now_utc
                
                if (now_utc - start_dt).total_seconds() < 172800:
                    if end_dt > today_start and start_dt <= today_end:
                        overlap_start = max(start_dt, today_start)
                        overlap_end = min(end_dt, today_end)
                        if overlap_end > overlap_start:
                            total_sleep_mins += int((overlap_end - overlap_start).total_seconds() / 60)
                            
            elif start_dt.date() == today:
                if category == EventCategory.FEED.value:
                    total_feeds += 1
                elif category == EventCategory.DIAPER.value:
                    condition = str(event.get("metadata", {}).get("condition", "")).lower()
                    if condition in ["dirty", "mixed", "wet", "caca", "pipi"]:
                        total_diapers += 1

        is_sleeping = False
        current_sleep_type = None
        sleeping_since = None

        active_naps = self.event_repository.get_active_events(baby_id, category=EventCategory.NAP.value) or []
        active_nap = next((e for e in active_naps if not e.get('end_time')), None)

        active_beds = self.event_repository.get_active_events(baby_id, category=EventCategory.BED_TIME.value) or []
        active_bed = next((e for e in active_beds if not e.get('end_time')), None)

        if active_nap:
            is_sleeping = True
            current_sleep_type = "Siesta"
            sleeping_since = active_nap.get('start_time')
        elif active_bed:
            is_sleeping = True
            current_sleep_type = "Noche"
            sleeping_since = active_bed.get('start_time')

        last_feed_event = None
        last_diaper_event = None

        recent_events = self.event_repository.get_by_baby(baby_id, limit=50) or []

        for event in recent_events:
            category = event.get('category')
            metadata = event.get('metadata', {})
            
            if category == EventCategory.FEED.value and not last_feed_event:
                last_feed_event = {
                    "time": event.get('start_time'),
                    "type": metadata.get('type', '-'),
                    "amount_ml": metadata.get('amount_ml', 0)
                }
            elif category == EventCategory.DIAPER.value and not last_diaper_event:
                last_diaper_event = {
                    "time": event.get('start_time'),
                    "condition": metadata.get('condition', 'clean')
                }
                
            if last_feed_event and last_diaper_event:
                break

        return {
            "baby_id": str(baby_id),
            "name": baby_name,
            "current_state": {
                "is_sleeping": is_sleeping,
                "current_sleep_type": current_sleep_type,
                "sleeping_since": sleeping_since
            },
            "today_summary": {
                "total_sleep_mins": total_sleep_mins,
                "total_feeds": total_feeds,
                "total_diapers": total_diapers
            },
            "last_events": {
                "last_feed": last_feed_event or {"time": None, "type": "-", "amount_ml": 0},
                "last_diaper": last_diaper_event or {"time": None, "condition": "clean"}
            }
        }