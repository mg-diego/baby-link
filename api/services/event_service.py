from typing import Dict, Optional
from zoneinfo import ZoneInfo

from core.errors import InvalidInputError, NotFoundError
from core.timeutils import local_date, parse_ts
from models.event_models import EventCategory, EventCreate, EventUpdate
from repositories.event_repository import EventRepository
from services.event_validation import validate_metadata, validate_timing

RECENT_WINDOW = 1000
FEED_TYPES = ("solids", "bottle", "nursing")
# Categorías con clave propia en /events/last (pañales y tomas tienen claves por subtipo)
SIMPLE_CATEGORIES = tuple(
    c.value for c in EventCategory if c not in (EventCategory.FEED, EventCategory.DIAPER)
)


class EventService:
    def __init__(self, repository: EventRepository):
        self.repository = repository

    # ─── Escritura ────────────────────────────────────────────────────────────

    def register_event(self, baby_id: str, event: EventCreate) -> dict:
        validate_timing(event.category, event.start_time, event.end_time, event.metadata)
        validate_metadata(event.category, event.metadata)
        return self.repository.save({**event.model_dump(mode="json"), "baby_id": baby_id})

    def update_event(self, current: dict, update_data: EventUpdate) -> dict:
        """Actualiza un evento existente (cerrar cronómetros, corregir horas o metadatos).
        Se validan las mismas reglas que al crear, sobre el estado resultante."""
        update_dict = update_data.model_dump(exclude_unset=True, mode="json")
        if not update_dict:
            raise InvalidInputError("El payload de actualización está vacío.")
        if "start_time" in update_dict and update_dict["start_time"] is None:
            raise InvalidInputError("start_time no puede borrarse")
        if "metadata" in update_dict and update_dict["metadata"] is None:
            update_dict["metadata"] = {}

        category = EventCategory(current["category"])
        start = update_data.start_time if "start_time" in update_dict else parse_ts(current["start_time"])
        end = update_data.end_time if "end_time" in update_dict else parse_ts(current.get("end_time"))
        metadata = update_dict.get("metadata", current.get("metadata") or {})

        validate_timing(category, start, end, metadata)
        # Los metadatos solo se validan si se modifican: así se pueden seguir editando
        # eventos antiguos (p. ej. importados del CSV) con formatos previos.
        if "metadata" in update_dict:
            validate_metadata(category, metadata)

        updated = self.repository.update(current["id"], update_dict)
        if not updated:
            raise NotFoundError("El evento no existe")
        return updated

    def delete_event(self, event_id: str) -> dict:
        deleted = self.repository.delete(event_id)
        if not deleted:
            raise NotFoundError("El evento no existe")
        return deleted

    # ─── Lectura ──────────────────────────────────────────────────────────────

    def get_active_events(self, baby_id: str, category: Optional[EventCategory] = None) -> list[dict]:
        """Eventos con cronómetro abierto. De las tomas, solo la lactancia tiene duración."""
        events = self.repository.get_open_duration_events(baby_id, category.value if category else None)
        return [
            e for e in events
            if e["category"] != EventCategory.FEED.value or (e.get("metadata") or {}).get("type") == "nursing"
        ]

    def get_valid_event_dates(self, baby_id: str, tz: ZoneInfo) -> list[str]:
        """Días (en hora local del bebé) con al menos un evento, para el calendario."""
        from_sql = self.repository.get_event_dates(baby_id, tz.key)
        if from_sql is not None:
            return from_sql
        dates = {
            local_date(parse_ts(row["start_time"]), tz).isoformat()
            for row in self.repository.get_all_start_times(baby_id)
            if row.get("start_time")
        }
        return sorted(dates)

    def get_growth_history(self, baby_id: str) -> list[dict]:
        return self.repository.get_by_category(baby_id, EventCategory.GROWTH.value)

    def get_last_events_by_category(self, baby_id: str) -> Dict[str, Optional[str]]:
        from_sql = self.repository.get_last_event_times(baby_id)
        if from_sql is not None:
            return from_sql

        recent = self.repository.get_latest(baby_id, limit=RECENT_WINDOW)
        last = _collect_last(recent)

        # Las categorías poco frecuentes (medicina, temperatura, crecimiento...) pueden haber
        # quedado fuera de la ventana de eventos recientes: se buscan aparte, en una sola query.
        if len(recent) >= RECENT_WINDOW:
            missing = [c for c in SIMPLE_CATEGORIES if c not in last]
            if "diaper" not in last:
                missing.append(EventCategory.DIAPER.value)
            if not any(k in last for k in (*FEED_TYPES, "feed")):
                missing.append(EventCategory.FEED.value)
            if missing:
                older = self.repository.get_latest(baby_id, limit=RECENT_WINDOW, categories=missing)
                for key, value in _collect_last(older).items():
                    last.setdefault(key, value)
        return last


def _collect_last(events_desc: list[dict]) -> Dict[str, str]:
    """Primera aparición de cada clave en una lista ordenada de más reciente a más antigua."""
    last: Dict[str, str] = {}
    for event in events_desc:
        category = event["category"]
        start_time = event["start_time"]
        metadata = event.get("metadata") or {}

        if category == EventCategory.FEED.value:
            feed_type = metadata.get("type")
            last.setdefault(feed_type if feed_type in FEED_TYPES else "feed", start_time)
        elif category == EventCategory.DIAPER.value:
            last.setdefault("diaper", start_time)
            condition = metadata.get("condition")
            # Un pañal mixto es a la vez mojado y sucio
            if condition in ("wet", "mixed"):
                last.setdefault("diaper_wet", start_time)
            if condition in ("dirty", "mixed"):
                last.setdefault("diaper_dirty", start_time)
        else:
            last.setdefault(category, start_time)
    return last
