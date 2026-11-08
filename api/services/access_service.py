import threading
from dataclasses import dataclass
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from cachetools import TTLCache

from core.errors import NotFoundError
from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository

# Dueño y zona horaria de cada bebé: cambian rara vez y se necesitan en casi todas las
# peticiones. Al editar un bebé se invalida su entrada (`forget`).
_baby_cache: TTLCache = TTLCache(maxsize=4096, ttl=600)
_cache_lock = threading.Lock()


@dataclass(frozen=True)
class BabyContext:
    id: str
    user_id: str
    tz: ZoneInfo


def resolve_timezone(name: str | None, default: ZoneInfo) -> ZoneInfo:
    if not name:
        return default
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        return default


class AccessService:
    """Comprueba que el usuario autenticado es dueño del bebé (o del evento) que pide.
    Si no es dueño se responde 404 y no 403, para no revelar qué IDs existen."""

    def __init__(self, baby_repository: BabyRepository, event_repository: EventRepository, default_tz: ZoneInfo):
        self.baby_repository = baby_repository
        self.event_repository = event_repository
        self.default_tz = default_tz

    def get_baby(self, user_id: str, baby_id: str) -> BabyContext:
        baby = self._lookup(baby_id)
        if baby is None or baby.user_id != user_id:
            raise NotFoundError("Bebé no encontrado")
        return baby

    def ensure_event(self, user_id: str, event_id: str) -> dict:
        event = self.event_repository.get_by_id(event_id)
        if not event:
            raise NotFoundError("El evento no existe")
        baby = self._lookup(event["baby_id"])
        if baby is None or baby.user_id != user_id:
            raise NotFoundError("El evento no existe")
        return event

    @staticmethod
    def forget(baby_id: str) -> None:
        with _cache_lock:
            _baby_cache.pop(baby_id, None)

    def _lookup(self, baby_id: str) -> BabyContext | None:
        with _cache_lock:
            if baby_id in _baby_cache:
                return _baby_cache[baby_id]
        row = self.baby_repository.get_by_id(baby_id)
        if row is None:
            return None
        baby = BabyContext(row["id"], row["user_id"], resolve_timezone(row.get("timezone"), self.default_tz))
        with _cache_lock:
            _baby_cache[baby_id] = baby
        return baby
