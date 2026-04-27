from typing import List
from supabase import Client

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