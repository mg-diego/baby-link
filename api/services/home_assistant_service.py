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

        active_sleep_events = self.event_repository.get_active_events(baby_id, category=EventCategory.NAP.value)
        if not active_sleep_events:
            active_sleep_events = self.event_repository.get_active_events(baby_id, category=EventCategory.NIGHT_WAKING.value)
            # If night_waking is active, it means the baby is awake during the night, so not sleeping in terms of "current_state"
            # We are looking for continuous sleep, so if night_waking is active, baby is not "sleeping" in the context of this state.

        if active_sleep_events:
            for event in active_sleep_events:
                # Check for actual sleep events (like NAP or BED_TIME that don't have end_time)
                if event['category'] in [EventCategory.NAP.value, EventCategory.BED_TIME.value] and not event.get('end_time'):
                    is_sleeping = True
                    current_sleep_type = "Siesta" if event['category'] == EventCategory.NAP.value else "Noche"
                    sleeping_since = event['start_time']
                    break # Assuming only one active sleep event at a time

        # 3. Today's Summary
        today = date.today()
        # Fetch all events for today
        # The get_events_by_date_range is in AnalyticsRepository, need to replicate logic or use get_recent_events
        # For simplicity, let's fetch all events for today and filter
        
        # Adjust get_recent_events to filter for a specific day
        # For now, let's fetch events for a small duration and filter them
        # This part might need a more efficient query if event_repository doesn't support date range easily.
        # Assuming get_recent_events can take a 'days' parameter as shown in event_repository.py (one of the methods has it)
        # However, the current get_recent_events doesn't take days as a filter parameter in the read file.
        # I will fetch all events and filter them in memory for now, or adapt if there's a better repo method.
        
        # Let's adjust event_repository.py's get_recent_events to allow date filtering for today
        # As I can't modify the file, I will fetch a larger window and filter here.
        # A better approach would be to add a get_events_for_date method to EventRepository.
        
        # For this prototype, let's fetch events from the last 2 days and filter for today.
        # This is not optimal but works given tool limitations.
        all_recent_events = self.event_repository.get_recent_events(baby_id) # This fetches all in the last 30 days based on previous inspection
        
        today_events = []
        for event in all_recent_events:
            event_date_str = datetime.fromisoformat(event['start_time'].replace('Z', '+00:00')).date()
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

        # Fetch recent events and find the latest feed and diaper
        # get_by_baby (limit=20) is good for this
        recent_events = self.event_repository.get_by_baby(baby_id, limit=50) # Increased limit to find recent of specific type

        for event in recent_events:
            if event['category'] == EventCategory.FEED.value and not last_feed_event:
                last_feed_event = {
                    "time": event['start_time'],
                    "type": event['metadata'].get('type'),
                    "amount_ml": event['metadata'].get('amount_ml')
                }
            elif event['category'] == EventCategory.DIAPER.value and not last_diaper_event:
                last_diaper_event = {
                    "time": event['start_time'],
                    "condition": event['metadata'].get('condition')
                }
            
            if last_feed_event and last_diaper_event:
                break # Found both, no need to continue

        # Construct the final JSON
        response_json = {
            "baby_id": baby_id,
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
                "last_feed": last_feed_event,
                "last_diaper": last_diaper_event
            }
        }
        return response_json