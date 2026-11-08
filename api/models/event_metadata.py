"""Esquema de `metadata` por categoría de evento.

Los modelos admiten campos extra (`extra="allow"`): la app guarda datos adicionales
(notas, predicciones `predicted_*`, campos de la migración del CSV...) que no deben
perderse. Solo se exige lo que necesita cada categoría.
"""
from typing import Any, Literal, Optional, Union

from pydantic import BaseModel, BeforeValidator, ConfigDict, ValidationError, model_validator
from typing_extensions import Annotated

from models.event_models import EventCategory

FeedType = Literal["bottle", "nursing", "solids"]
DiaperCondition = Literal["wet", "dirty", "mixed", "clean"]


def _decimal(value: Any) -> Any:
    # Acepta "37,5" además de 37.5 (formularios con coma decimal)
    if isinstance(value, str):
        return value.strip().replace(",", ".")
    return value


Number = Annotated[float, BeforeValidator(_decimal)]


class _Metadata(BaseModel):
    model_config = ConfigDict(extra="allow")


class FeedMetadata(_Metadata):
    type: FeedType
    amount_ml: Optional[Number] = None


class DiaperMetadata(_Metadata):
    condition: DiaperCondition


class TemperatureMetadata(_Metadata):
    celsius: Number


class GrowthMetadata(_Metadata):
    weight_kg: Optional[Number] = None
    height_cm: Optional[Number] = None
    head_cm: Optional[Number] = None

    @model_validator(mode="after")
    def _at_least_one(self):
        if not self.model_fields_set & {"weight_kg", "height_cm", "head_cm"}:
            raise ValueError("Growth requiere al menos un dato: 'weight_kg', 'height_cm' o 'head_cm'")
        return self


class MedicineMetadata(_Metadata):
    name: Optional[str] = None
    dose_amount: Optional[Union[Number, str]] = None
    dose_unit: Optional[str] = None
    notes: Optional[str] = None

    @model_validator(mode="after")
    def _strict_or_notes(self):
        strict = {"name", "dose_amount", "dose_unit"} <= self.model_fields_set
        if not (strict or "notes" in self.model_fields_set):
            raise ValueError("Medicine requiere: name, dose_amount y dose_unit (o al menos 'notes')")
        return self


class PumpingMetadata(_Metadata):
    total_ml: Optional[Number] = None
    notes: Optional[str] = None

    @model_validator(mode="after")
    def _total_or_notes(self):
        has_any = bool(self.model_fields_set or self.model_extra)
        if has_any and not self.model_fields_set & {"total_ml", "notes"}:
            raise ValueError("Si se incluyen metadatos en Pumping, debe contener 'total_ml' o 'notes'")
        return self


class MilestoneMetadata(_Metadata):
    title: str


METADATA_MODELS: dict[EventCategory, type[_Metadata]] = {
    EventCategory.FEED: FeedMetadata,
    EventCategory.DIAPER: DiaperMetadata,
    EventCategory.TEMPERATURE: TemperatureMetadata,
    EventCategory.GROWTH: GrowthMetadata,
    EventCategory.MEDICINE: MedicineMetadata,
    EventCategory.PUMPING: PumpingMetadata,
    EventCategory.MILESTONE: MilestoneMetadata,
}


def metadata_error(category: EventCategory, metadata: dict) -> Optional[str]:
    """Mensaje de error legible si la metadata no es válida para la categoría, o None."""
    model = METADATA_MODELS.get(category)
    if model is None:
        return None
    try:
        model.model_validate(metadata or {})
    except ValidationError as exc:
        first = exc.errors()[0]
        if first["type"] == "value_error":
            return first["msg"].removeprefix("Value error, ")
        field = ".".join(str(p) for p in first["loc"]) or "metadata"
        return f"{category.value}: '{field}' {first['msg']}"
    return None
