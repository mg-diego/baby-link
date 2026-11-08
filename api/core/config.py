"""Configuración de la API leída de variables de entorno (o de `api/.env`).

Se valida al arrancar: si falta algo obligatorio la API no levanta, en lugar de
fallar con un error críptico en la primera petición.
"""
import os
from dataclasses import dataclass
from functools import lru_cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from dotenv import load_dotenv


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_key: str
    # Solo para proyectos con la clave JWT "legacy" (HS256). Con claves asimétricas
    # (ES256/RS256) los tokens se validan contra el JWKS público de Supabase.
    supabase_jwt_secret: str | None
    home_assistant_api_key: str | None
    timezone: str
    cors_origins: tuple[str, ...]

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)


@lru_cache
def get_settings() -> Settings:
    load_dotenv()

    missing = [name for name in ("SUPABASE_URL", "SUPABASE_KEY") if not os.environ.get(name)]
    if missing:
        raise RuntimeError(f"Faltan variables de entorno obligatorias: {', '.join(missing)}")

    timezone = os.environ.get("APP_TIMEZONE", "Europe/Madrid")
    try:
        ZoneInfo(timezone)
    except ZoneInfoNotFoundError as exc:
        raise RuntimeError(f"APP_TIMEZONE no válida: {timezone}") from exc

    origins = tuple(o.strip() for o in os.environ.get("CORS_ORIGINS", "*").split(",") if o.strip())

    return Settings(
        supabase_url=os.environ["SUPABASE_URL"].rstrip("/"),
        supabase_key=os.environ["SUPABASE_KEY"],
        supabase_jwt_secret=os.environ.get("SUPABASE_JWT_SECRET") or None,
        home_assistant_api_key=os.environ.get("HOME_ASSISTANT_API_KEY") or None,
        timezone=timezone,
        cors_origins=origins or ("*",),
    )
