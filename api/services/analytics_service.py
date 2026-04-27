from datetime import datetime, date
from models.analytics_models import DailySummary
from models.event_models import EventCategory
from repositories.analytics_repository import AnalyticsRepository

class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository):
        self.repository = repository

    def get_daily_summary(self, baby_id: str, target_date: date) -> DailySummary:
        events = self.repository.get_daily_events(baby_id, target_date)
        
        total_nap = 0
        total_feeds = 0
        total_dirty = 0
        
        for event in events:
            category = event.get("category")
            metadata = event.get("metadata", {})
            
            if category == EventCategory.NAP:
                start_str = event.get("start_time")
                end_str = event.get("end_time")
                if start_str and end_str:
                    start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
                    end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00'))
                    total_nap += int((end_dt - start_dt).total_seconds() / 60)
                    
            elif category == EventCategory.FEED:
                total_feeds += 1
                
            elif category == EventCategory.DIAPER:
                condition = metadata.get("condition")
                if condition in ["dirty", "mixed"]:
                    total_dirty += 1

        return DailySummary(
            target_date=target_date,
            total_nap_minutes=total_nap,
            total_feeds=total_feeds,
            total_dirty_diapers=total_dirty
        )