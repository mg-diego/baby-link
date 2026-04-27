from supabase import Client
    
class BabyRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def save(self, baby_data: dict) -> dict:
        response = self.db.table("babies").insert(baby_data).execute()
        return response.data[0]