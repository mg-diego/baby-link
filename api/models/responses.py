"""Contrato de respuesta de la API: siempre `{"status": ..., "data": ...}`.

Los modelos de filas de BD admiten campos extra para no perder columnas nuevas
(created_at, timezone...) sin tener que tocar la API.
"""
from typing import Any, Generic, Literal, Optional, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    status: Literal["success"] = "success"
    data: T


class _Row(BaseModel):
    model_config = ConfigDict(extra="allow")


class BabyOut(_Row):
    id: str
    name: str
    dob: str
    user_id: str
    photo_url: Optional[str] = None
    timezone: Optional[str] = None


class EventOut(_Row):
    id: str
    baby_id: str
    category: str
    start_time: str
    end_time: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    notes: Optional[str] = None


class GrowthPoint(_Row):
    id: str
    start_time: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class StatsData(BaseModel):
    summary_cards: list[dict[str, Any]]
    charts: list[dict[str, Any]]


class TimeRange(BaseModel):
    """Intervalo en el que es más probable que ocurra (aprox. 50 % de las veces)."""
    earliest: str
    latest: str


class PredictionItem(_Row):
    type: Literal["nap", "bedtime", "woke_up"]
    start: str
    end: Optional[str] = None
    start_range: Optional[TimeRange] = None
    index: Optional[int] = None
    note: Optional[str] = None
    overdue: Optional[bool] = None
    # Siesta cuyo hueco ya pasó sin registrarse: se supone hecha a su hora
    assumed: Optional[bool] = None
    is_catnap: Optional[bool] = None
    # Bloque opaco que la app guarda en el evento real (ver prediction/feedback.py)
    predicted_feedback: Optional[dict[str, Any]] = None
    # De dónde sale la hora (ventana habitual, hora de rutina...), para explicarla en la app
    basis: Optional[dict[str, Any]] = None


class Predictions(BaseModel):
    schedule: list[PredictionItem]
    wake: Optional[PredictionItem] = None


class Insufficiency(BaseModel):
    reason: Literal["insufficient_events", "insufficient_days"]
    required: int
    current: int


class PredictionsResponse(BaseModel):
    """Con pocos datos: status="insufficient_data", schedule vacío y `detail` explica qué falta."""
    status: Literal["success", "insufficient_data"]
    data: Predictions
    detail: Optional[Insufficiency] = None
