from datetime import datetime, date
from typing import Dict, Any

from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository
from models.event_models import EventCategory

class HomeAssistantService:
    def __init__(self, baby_repository: BabyRepository, event_repository: EventRepository):
        self.baby_repository = baby_repository
        self.event_repository = event_repository

    async def get_summary(self, baby_id: str) -> Dict[str, Any]:
        # 1. Fetch baby information
        baby_name = "Ona"

        # 2. Current State
        is_sleeping = False
        current_sleep_type = None
        sleeping_since = None

        # CORRECCIÓN: SIN 'await' porque el repositorio ya devuelve una lista normal (list)
        active_sleep_events = self.event_repository.get_active_events(baby_id, category=EventCategory.NAP.value)
        if not active_sleep_events:
            active_sleep_events = self.event_repository.get_active_events(baby_id, category=EventCategory.NIGHT_WAKING.value)

        if active_sleep_events:
            for event in active_sleep_events:
                if event['category'] in [EventCategory.NAP.value, EventCategory.BED_TIME.value] and not event.get('end_time'):
                    is_sleeping = True
                    current_sleep_type = "Siesta" if event['category'] == EventCategory.NAP.value else "Noche"
                    sleeping_since = event['start_time']
                    break

        # 3. Today's Summary
        today = date.today()
        
        # CORRECCIÓN: SIN 'await' porque devuelve una lista normal (list)
        all_recent_events = self.event_repository.get_recent_events(baby_id) or []
        
        today_events = []
        for event in all_recent_events:
            start_str = event.get('start_time')
            if start_str:
                event_date_str = datetime.fromisoformat(start_str.replace('Z', '+00:00')).date()
                if event_date_str == today:
                    today_events.append(event)

        total_sleep_mins = 0
        total_feeds = 0
        total_diapers = 0

        for event in today_events:
            category = event.get("category")
            metadata = event.get("metadata", {})

            if category == EventCategory.NAP.value:
                start_str = event.get("start_time")
                end_str = event.get("end_time")
                if start_str and end_str:
                    start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
                    end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00'))
                    total_sleep_mins += int((end_dt - start_dt).total_seconds() / 60)
            elif category == EventCategory.FEED.value:
                total_feeds += 1
            elif category == EventCategory.DIAPER.value:
                condition = metadata.get("condition")
                if condition in ["dirty", "mixed"]:
                    total_diapers += 1

        # 4. Last Events
        last_feed_event = None
        last_diaper_event = None

        # CORRECCIÓN: SIN 'await' porque devuelve una lista normal (list)
        recent_events = self.event_repository.get_by_baby(baby_id, limit=50) or []

        for event in recent_events:
            metadata = event.get('metadata', {})
            if event['category'] == EventCategory.FEED.value and not last_feed_event:
                last_feed_event = {
                    "time": event.get('start_time'),
                    "type": metadata.get('type', '-'),
                    "amount_ml": metadata.get('amount_ml', 0)
                }
            elif event['category'] == EventCategory.DIAPER.value and not last_diaper_event:
                last_diaper_event = {
                    "time": event.get('start_time'),
                    "condition": metadata.get('condition', 'clean')
                }
            
            if last_feed_event and last_diaper_event:
                break

        # Construct the final JSON (Protegido contra None para evitar fallos de serialización)
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