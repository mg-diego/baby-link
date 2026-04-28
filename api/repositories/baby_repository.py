from typing import List
from supabase import Client
    
class BabyRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def save(self, baby_data: dict) -> dict:
        response = self.db.table("babies").insert(baby_data).execute()
        return response.data[0]
    
    def get_by_user(self, user_id: str) -> List[dict]:
        response = self.db.table("babies").select("*").eq("user_id", user_id).execute()
        return response.data