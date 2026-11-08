import threading

from cachetools import TTLCache

from core.errors import NotFoundError
from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository

# El dueño de un bebé no cambia: cachearlo ahorra una consulta en casi todas las peticiones.
_owner_cache: TTLCache = TTLCache(maxsize=4096, ttl=600)
_owner_lock = threading.Lock()


class AccessService:
    """Comprueba que el usuario autenticado es dueño del bebé (o del evento) que pide.

    `user_id=None` significa autenticación desactivada (AUTH_ENABLED=false) y deja pasar.
    Si no es dueño se responde 404 y no 403, para no revelar qué IDs existen.
    """

    def __init__(self, baby_repository: BabyRepository, event_repository: EventRepository):
        self.baby_repository = baby_repository
        self.event_repository = event_repository

    def ensure_baby(self, user_id: str | None, baby_id: str) -> None:
        if user_id is None:
            return
        if self._owner_of(baby_id) != user_id:
            raise NotFoundError("Bebé no encontrado")

    def ensure_event(self, user_id: str | None, event_id: str) -> dict:
        event = self.event_repository.get_by_id(event_id)
        if not event:
            raise NotFoundError("El evento no existe")
        if user_id is not None and self._owner_of(event["baby_id"]) != user_id:
            raise NotFoundError("El evento no existe")
        return event

    def _owner_of(self, baby_id: str) -> str | None:
        with _owner_lock:
            if baby_id in _owner_cache:
                return _owner_cache[baby_id]
        owner = self.baby_repository.get_owner_id(baby_id)
        if owner is not None:
            with _owner_lock:
                _owner_cache[baby_id] = owner
        return owner
