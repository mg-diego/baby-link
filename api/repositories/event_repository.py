from datetime import datetime
from typing import Iterable

from supabase import Client

from core.pagination import fetch_all
from core.rpc import call_rpc

TABLE = "baby_events"
DURATION_CATEGORIES = ("nap", "night_waking", "feed", "pumping")


class EventRepository:
    def __init__(self, db_client: Client):
        self.db = db_client

    def _table(self):
        return self.db.table(TABLE)

    # ─── Escritura ────────────────────────────────────────────────────────────

    def save(self, event_data: dict) -> dict:
        return self._table().insert(event_data).execute().data[0]

    def update(self, event_id: str, update_data: dict) -> dict | None:
        """Aplica exactamente los campos recibidos (un None borra el valor)."""
        rows = self._table().update(update_data).eq("id", event_id).execute().data
        return rows[0] if rows else None

    def delete(self, event_id: str) -> dict | None:
        rows = self._table().delete().eq("id", event_id).execute().data
        return rows[0] if rows else None

    # ─── Lectura ──────────────────────────────────────────────────────────────

    def get_by_id(self, event_id: str) -> dict | None:
        rows = self._table().select("*").eq("id", event_id).limit(1).execute().data
        return rows[0] if rows else None

    def get_open_duration_events(self, baby_id: str, category: str | None = None) -> list[dict]:
        query = (
            self._table().select("*")
            .eq("baby_id", baby_id)
            .is_("end_time", "null")
            .in_("category", list(DURATION_CATEGORIES))
        )
        if category:
            query = query.eq("category", category)
        return query.order("start_time", desc=True).execute().data

    def get_by_category(self, baby_id: str, category: str) -> list[dict]:
        return fetch_all(lambda: (
            self._table().select("id, start_time, metadata")
            .eq("baby_id", baby_id)
            .eq("category", category)
            .order("start_time").order("id")
        ))

    def get_all_start_times(self, baby_id: str) -> list[dict]:
        return fetch_all(lambda: (
            self._table().select("start_time")
            .eq("baby_id", baby_id)
            .order("start_time").order("id")
        ))

    def get_event_dates(self, baby_id: str, tz_name: str) -> list[str] | None:
        """Días locales con eventos (función SQL). None si la función no existe aún."""
        rows = call_rpc(self.db, "event_dates", {"p_baby_id": baby_id, "p_tz": tz_name})
        return None if rows is None else [str(r["day"]) for r in rows]

    def get_last_event_times(self, baby_id: str) -> dict[str, str] | None:
        """Último start_time por clave (función SQL). None si la función no existe aún."""
        rows = call_rpc(self.db, "last_event_times", {"p_baby_id": baby_id})
        return None if rows is None else {r["key"]: r["start_time"] for r in rows}

    def get_latest(self, baby_id: str, limit: int = 1000, categories: Iterable[str] | None = None) -> list[dict]:
        """Los `limit` eventos más recientes (desc), opcionalmente de ciertas categorías."""
        query = self._table().select("category, start_time, end_time, metadata").eq("baby_id", baby_id)
        if categories is not None:
            query = query.in_("category", list(categories))
        return query.order("start_time", desc=True).limit(limit).execute().data

    def get_events_since(self, baby_id: str, since: datetime, categories: Iterable[str] | None = None) -> list[dict]:
        """Todos los eventos con start_time >= since, en orden ascendente."""
        cats = list(categories) if categories is not None else None

        def build():
            query = (
                self._table().select("id, category, start_time, end_time, metadata")
                .eq("baby_id", baby_id)
                .gte("start_time", since.isoformat())
            )
            if cats is not None:
                query = query.in_("category", cats)
            return query.order("start_time").order("id")

        return fetch_all(build)
