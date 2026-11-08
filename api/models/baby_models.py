from datetime import date
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, field_validator


def _check_timezone(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise ValueError(f"Zona horaria desconocida: {value} (usa un nombre IANA, p. ej. 'Europe/Madrid')") from exc
    return value


class BabyCreate(BaseModel):
    name: str
    dob: date
    # Zona IANA del bebé; si no se indica se usa APP_TIMEZONE
    timezone: Optional[str] = None

    @field_validator("timezone")
    @classmethod
    def _valid_timezone(cls, value):
        return _check_timezone(value)


class BabyUpdate(BaseModel):
    name: Optional[str] = None
    dob: Optional[date] = None
    photo_url: Optional[str] = None
    timezone: Optional[str] = None

    @field_validator("timezone")
    @classmethod
    def _valid_timezone(cls, value):
        return _check_timezone(value)
