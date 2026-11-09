"""Reglas de negocio de los eventos, compartidas por la creación y la edición.
El esquema de cada `metadata` está en `models/event_metadata.py`."""
from datetime import datetime

from core.errors import InvalidInputError
from models.event_metadata import metadata_error
from models.event_models import EventCategory

ATOMIC_CATEGORIES = {
    EventCategory.WOKE_UP, EventCategory.BED_TIME, EventCategory.NAP_SKIPPED, EventCategory.BATH,
    EventCategory.DIAPER, EventCategory.MEDICINE, EventCategory.TEMPERATURE,
    EventCategory.GROWTH, EventCategory.MILESTONE,
}


def validate_timing(category: EventCategory, start: datetime, end: datetime | None, metadata: dict) -> None:
    if end is not None and end < start:
        raise InvalidInputError("end_time no puede ser anterior a start_time")
    if category in ATOMIC_CATEGORIES and end is not None:
        raise InvalidInputError(f"El evento '{category.value}' es atómico y no admite 'end_time'.")
    if category == EventCategory.FEED and end is not None and (metadata or {}).get("type") != "nursing":
        raise InvalidInputError("Solo las tomas de tipo 'nursing' admiten 'end_time'.")


def validate_metadata(category: EventCategory, metadata: dict) -> None:
    error = metadata_error(category, metadata)
    if error:
        raise InvalidInputError(error)
