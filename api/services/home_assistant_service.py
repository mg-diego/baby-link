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

        all_recent_events = self.event_repository.get_recent_events(baby_id) or []
        
        today_events = []
        bed_time_today = None
        
        for event in all_recent_events:
            start_str = event.get('start_time')
            end_str = event.get('end_time')
            
            is_today = False
            if start_str:
                start_date = datetime.fromisoformat(start_str.replace('Z', '+00:00')).date()
                if start_date == today:
                    is_today = True
            
            if end_str and not is_today:
                end_date = datetime.fromisoformat(end_str.replace('Z', '+00:00')).date()
                if end_date == today:
                    is_today = True
            
            if start_str and not end_str:
                is_today = True

            if is_today:
                today_events.append(event)
                
            if event.get('category') == EventCategory.BED_TIME.value:
                if not end_str or (end_str and is_today):
                    if not bed_time_today or start_str > bed_time_today.get('start_time', ''):
                        bed_time_today = event

        is_sleeping = False
        current_sleep_type = None
        sleeping_since = None

        active_naps = self.event_repository.get_active_events(baby_id, category=EventCategory.NAP.value) or []
        
        active_nap = None
        for event in active_naps:
            if not event.get('end_time'):
                active_nap = event
                break

        if active_nap:
            is_sleeping = True
            current_sleep_type = "Siesta"
            sleeping_since = active_nap.get('start_time')
        elif bed_time_today and not bed_time_today.get('end_time'):
            is_sleeping = True
            current_sleep_type = "Noche"
            sleeping_since = bed_time_today.get('start_time')

        total_sleep_mins = 0
        total_feeds = 0
        total_diapers = 0

        for event in today_events:
            category = event.get("category")
            metadata = event.get("metadata", {})

            if category in [EventCategory.NAP.value, EventCategory.BED_TIME.value]:
                start_str = event.get("start_time")
                end_str = event.get("end_time")
                
                if start_str:
                    start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
                    end_dt = datetime.now(timezone.utc)
                    if end_str:
                        end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00'))
                    
                    total_sleep_mins += int((end_dt - start_dt).total_seconds() / 60)
            
            elif category == EventCategory.FEED.value:
                total_feeds += 1
            elif category == EventCategory.DIAPER.value:
                condition = str(metadata.get("condition", "")).lower()
                if condition in ["dirty", "mixed", "wet", "caca", "pipi"]:
                    total_diapers += 1

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