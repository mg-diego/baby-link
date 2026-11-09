from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

from core.timeutils import UTC


class EventCategory(str, Enum):
    WOKE_UP = "woke_up"
    NAP = "nap"
    # Siesta prevista que no hizo (marcada a mano). Borrarla deshace la marca.
    NAP_SKIPPED = "nap_skipped"
    BED_TIME = "bed_time"
    NIGHT_WAKING = "night_waking"
    FEED = "feed"
    DIAPER = "diaper"
    MEDICINE = "medicine"
    BATH = "bath"
    TEMPERATURE = "temperature"
    GROWTH = "growth"
    PUMPING = "pumping"
    MILESTONE = "milestone"


def _to_utc(value: Optional[datetime]) -> Optional[datetime]:
    # Sin zona -> se asume UTC (es lo que envía la app con toUtc())
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


class EventCreate(BaseModel):
    """Evento nuevo; el bebé va en la URL (POST /babies/{baby_id}/events)."""
    category: EventCategory
    start_time: datetime
    end_time: Optional[datetime] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    notes: Optional[str] = None

    @field_validator("start_time", "end_time")
    @classmethod
    def _normalize_times(cls, value):
        return _to_utc(value)

    @model_validator(mode="after")
    def _check_order(self):
        if self.end_time is not None and self.end_time < self.start_time:
            raise ValueError("end_time no puede ser anterior a start_time")
        return self


class EventUpdate(BaseModel):
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    metadata: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None

    @field_validator("start_time", "end_time")
    @classmethod
    def _normalize_times(cls, value):
        return _to_utc(value)
