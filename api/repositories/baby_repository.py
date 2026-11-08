from supabase import Client

TABLE = "babies"


class BabyRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def save(self, baby_data: dict) -> dict:
        return self.db.table(TABLE).insert(baby_data).execute().data[0]

    def get_by_user(self, user_id: str) -> list[dict]:
        return self.db.table(TABLE).select("*").eq("user_id", user_id).execute().data

    def get_by_id(self, baby_id: str) -> dict | None:
        rows = self.db.table(TABLE).select("*").eq("id", baby_id).limit(1).execute().data
        return rows[0] if rows else None

    def get_owner_id(self, baby_id: str) -> str | None:
        rows = self.db.table(TABLE).select("user_id").eq("id", baby_id).limit(1).execute().data
        return rows[0]["user_id"] if rows else None

    def update(self, baby_id: str, update_data: dict) -> dict | None:
        rows = self.db.table(TABLE).update(update_data).eq("id", baby_id).execute().data
        return rows[0] if rows else None
