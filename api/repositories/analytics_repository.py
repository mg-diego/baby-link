from datetime import date, timedelta
from typing import List
from supabase import Client

class AnalyticsRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def get_daily_events(self, baby_id: str, target_date: date) -> List[dict]:
        start_iso = f"{target_date}T00:00:00Z"
        end_iso = f"{target_date + timedelta(days=1)}T00:00:00Z"
        
        response = self.db.table("baby_events")\
            .select("*")\
            .eq("baby_id", baby_id)\
            .gte("start_time", start_iso)\
            .lt("start_time", end_iso)\
            .execute()
            
        return response.data