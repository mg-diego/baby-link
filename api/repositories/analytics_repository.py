from datetime import date
from typing import List
from zoneinfo import ZoneInfo

from supabase import Client

from core.pagination import fetch_all
from core.timeutils import local_range_utc

TABLE = "baby_events"


class AnalyticsRepository:
    """Consultas por rangos de días *locales*. Todas paginan: un rango largo puede
    superar las 1000 filas que devuelve Supabase por petición."""

    def __init__(self, db_client: Client, tz: ZoneInfo):
        self.db = db_client
        self.tz = tz

    def get_events_by_date_range(self, baby_id: str, start_date: date, end_date: date) -> List[dict]:
        start_utc, end_utc = local_range_utc(start_date, end_date, self.tz)
        return fetch_all(lambda: (
            self.db.table(TABLE).select("*")
            .eq("baby_id", baby_id)
            .gte("start_time", start_utc.isoformat())
            .lt("start_time", end_utc.isoformat())
            .order("start_time").order("id")
        ))

    def get_events_by_categories(
        self,
        baby_id: str,
        categories: List[str],
        start_date: date,
        end_date: date,
        extra_hours_after: int = 0,
    ) -> List[dict]:
        """Eventos de varias categorías entre start_date 00:00 y end_date 24:00 (hora local),
        ampliando opcionalmente el final para cerrar noches que terminan al día siguiente."""
        start_utc, end_utc = local_range_utc(start_date, end_date, self.tz, extra_hours_after)
        return fetch_all(lambda: (
            self.db.table(TABLE).select("*")
            .eq("baby_id", baby_id)
            .in_("category", categories)
            .gte("start_time", start_utc.isoformat())
            .lt("start_time", end_utc.isoformat())
            .order("start_time").order("id")
        ))

    def get_events_until(self, baby_id: str, category: str, end_date: date) -> List[dict]:
        """Todos los eventos de una categoría hasta end_date (incluido), sin límite inferior."""
        _, end_utc = local_range_utc(end_date, end_date, self.tz)
        return fetch_all(lambda: (
            self.db.table(TABLE).select("*")
            .eq("baby_id", baby_id)
            .eq("category", category)
            .lt("start_time", end_utc.isoformat())
            .order("start_time").order("id")
        ))
