"""Reglas de negocio de los eventos, compartidas por la creación y la edición."""
from datetime import datetime

from core.errors import InvalidInputError
from models.event_models import EventCategory

ATOMIC_CATEGORIES = {
    EventCategory.WOKE_UP, EventCategory.BED_TIME, EventCategory.BATH,
    EventCategory.DIAPER, EventCategory.MEDICINE, EventCategory.TEMPERATURE,
    EventCategory.GROWTH, EventCategory.MILESTONE,
}
FEED_TYPES = ("bottle", "nursing", "solids")
DIAPER_CONDITIONS = ("wet", "dirty", "mixed", "clean")


def validate_timing(category: EventCategory, start: datetime, end: datetime | None, metadata: dict) -> None:
    if end is not None and end < start:
        raise InvalidInputError("end_time no puede ser anterior a start_time")
    if category in ATOMIC_CATEGORIES and end is not None:
        raise InvalidInputError(f"El evento '{category.value}' es atómico y no admite 'end_time'.")
    if category == EventCategory.FEED and end is not None and (metadata or {}).get("type") != "nursing":
        raise InvalidInputError("Solo las tomas de tipo 'nursing' admiten 'end_time'.")


def validate_metadata(category: EventCategory, metadata: dict) -> None:
    validator = _METADATA_VALIDATORS.get(category)
    if validator:
        validator(metadata or {})


def _growth(metadata: dict) -> None:
    if not any(k in metadata for k in ("weight_kg", "height_cm", "head_cm")):
        raise InvalidInputError("Growth requiere al menos un dato: 'weight_kg', 'height_cm' o 'head_cm'")


def _pumping(metadata: dict) -> None:
    if metadata and "total_ml" not in metadata and "notes" not in metadata:
        raise InvalidInputError("Si se incluyen metadatos en Pumping, debe contener 'total_ml' o 'notes'")


def _milestone(metadata: dict) -> None:
    if "title" not in metadata:
        raise InvalidInputError("Milestone requiere un 'title' (ej: 'Primer diente')")


def _feed(metadata: dict) -> None:
    if metadata.get("type") not in FEED_TYPES:
        raise InvalidInputError(f"Feed debe tener type: {list(FEED_TYPES)}")


def _diaper(metadata: dict) -> None:
    if metadata.get("condition") not in DIAPER_CONDITIONS:
        raise InvalidInputError(f"Diaper debe tener condition: {list(DIAPER_CONDITIONS)}")


def _medicine(metadata: dict) -> None:
    has_strict_fields = all(k in metadata for k in ("name", "dose_amount", "dose_unit"))
    if not (has_strict_fields or "notes" in metadata):
        raise InvalidInputError("Medicine requiere: name, dose_amount y dose_unit (o al menos 'notes')")


def _temperature(metadata: dict) -> None:
    if "celsius" not in metadata:
        raise InvalidInputError("Temperature requiere el campo 'celsius'")


_METADATA_VALIDATORS = {
    EventCategory.FEED: _feed,
    EventCategory.DIAPER: _diaper,
    EventCategory.MEDICINE: _medicine,
    EventCategory.TEMPERATURE: _temperature,
    EventCategory.GROWTH: _growth,
    EventCategory.PUMPING: _pumping,
    EventCategory.MILESTONE: _milestone,
}
