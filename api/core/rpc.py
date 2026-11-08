"""Llamadas a funciones SQL (RPC) de Supabase con degradación elegante.

Las funciones se crean con las migraciones de `supabase/migrations/`. Si aún no se han
aplicado, la llamada devuelve None y el repositorio usa su implementación en Python.
"""
import logging
import threading

from postgrest.exceptions import APIError

logger = logging.getLogger(__name__)

FUNCTION_NOT_FOUND = "PGRST202"
_missing: set[str] = set()
_lock = threading.Lock()


def call_rpc(db, name: str, params: dict) -> list | None:
    with _lock:
        if name in _missing:
            return None
    try:
        return db.rpc(name, params).execute().data
    except APIError as exc:
        if exc.code != FUNCTION_NOT_FOUND:
            raise
        with _lock:
            _missing.add(name)
        logger.warning("Función SQL '%s' no encontrada: aplica supabase/migrations. Usando la versión en Python.", name)
        return None
