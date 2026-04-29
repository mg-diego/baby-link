from typing import List
from supabase import Client
from datetime import datetime, timedelta

class EventRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def save(self, event_data: dict) -> dict:
        response = self.db.table("baby_events").insert(event_data).execute()
        return response.data[0]

    def get_by_baby(self, baby_id: str, limit: int = 20) -> List[dict]:
        response = self.db.table("baby_events").select("*").eq("baby_id", baby_id).order("start_time", desc=True).limit(limit).execute()
        return response.data
    
    def update(self, event_id: str, update_data: dict) -> dict:
        clean_data = {k: v for k, v in update_data.items() if v is not None}
        response = self.db.table("baby_events").update(clean_data).eq("id", event_id).execute()
        
        if not response.data:
            raise ValueError("Evento no encontrado o no se pudo actualizar")
        return response.data[0]
    
    def get_active_events(self, baby_id: str, category: str = None) -> list:
        duration_categories = ['nap', 'night_waking', 'feed', 'pumping']
        
        query = self.db.table('baby_events') \
            .select('*') \
            .eq('baby_id', baby_id) \
            .is_('end_time', 'null') \
            .in_('category', duration_categories)
            
        if category:
            query = query.eq('category', category)
            
        response = query.execute()
        raw_active_events = response.data
        
        valid_active_events = []
        for event in raw_active_events:
            if event['category'] == 'feed':
                metadata_type = event.get('metadata', {}).get('type')
                if metadata_type != 'breast':
                    continue
                    
            valid_active_events.append(event)
            
        return valid_active_events
    
    def delete_event(self, event_id: str) -> list:
        response = self.db.table('baby_events').delete().eq('id', event_id).execute()
        return response.data
    
    def get_all_start_times(self, baby_id: str) -> list[dict]:
        all_data = []
        offset = 0
        limit = 1000
        
        while True:
            response = (
                self.db.table("baby_events")
                .select("start_time")
                .eq("baby_id", baby_id)
                .range(offset, offset + limit - 1)
                .execute()
            )
            
            if response.data:
                all_data.extend(response.data)
                
            if not response.data or len(response.data) < limit:
                break
                
            offset += limit
            
        return all_data
    
    def get_recent_events(self, baby_id: str, days: int = 30):        
        cutoff = (datetime.now() - timedelta(days=days)).isoformat()
        
        response = self.db.table("baby_events")\
            .select("*")\
            .eq("baby_id", baby_id)\
            .gte("start_time", cutoff)\
            .order("start_time", desc=False)\
            .execute()
            
        return response.data

    def get_baby_info(self, baby_id: str):
        response = self.db.table("babies")\
            .select("dob, name")\
            .eq("id", baby_id)\
            .single()\
            .execute()
        return response.data
    