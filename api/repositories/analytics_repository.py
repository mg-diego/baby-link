from datetime import date, datetime, timedelta
from typing import List
from supabase import Client
import pytz

class AnalyticsRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def get_events_by_date_range(self, baby_id: str, start_date: date, end_date: date, timezone: str = "Europe/Madrid") -> List[dict]:
        try:
            user_tz = pytz.timezone(timezone)
        except pytz.UnknownTimeZoneError:
            user_tz = pytz.UTC

        start_naive = datetime.combine(start_date, datetime.min.time())
        end_naive = datetime.combine(end_date + timedelta(days=1), datetime.min.time())

        start_utc = user_tz.localize(start_naive).astimezone(pytz.UTC)
        end_utc = user_tz.localize(end_naive).astimezone(pytz.UTC)

        start_iso = start_utc.isoformat()
        end_iso = end_utc.isoformat()
        
        response = self.db.table("baby_events")\
            .select("*")\
            .eq("baby_id", baby_id)\
            .gte("start_time", start_iso)\
            .lt("start_time", end_iso)\
            .execute()
            
        return response.data
    
    def get_events_by_category(self, baby_id: str, category: str, start_date: str, end_date: str):        
        end_datetime = f"{end_date}T23:59:59"
        
        response = self.db.table('baby_events')\
            .select("*")\
            .eq("baby_id", baby_id)\
            .eq("category", category)\
            .gte("start_time", start_date)\
            .lte("start_time", end_datetime)\
            .order("start_time", desc=False)\
            .execute()
            
        return response.data