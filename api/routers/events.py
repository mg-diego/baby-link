from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends

from core.errors import InvalidInputError
from dependencies import authorized_baby, authorized_event, get_analytics_service, get_event_service
from models.event_models import EventCategory, EventCreate, EventUpdate
from models.responses import ApiResponse, EventOut, GrowthPoint
from services.access_service import BabyContext
from services.analytics import AnalyticsService
from services.event_service import EventService

router = APIRouter(tags=["Events"])


@router.post("/babies/{baby_id}/events", response_model=ApiResponse[EventOut])
def create_event(
    event: EventCreate,
    baby: BabyContext = Depends(authorized_baby),
    service: EventService = Depends(get_event_service),
):
    """Registra un evento (sueño, toma, pañal...)."""
    return ApiResponse(data=service.register_event(baby.id, event))


@router.get("/babies/{baby_id}/events", response_model=ApiResponse[list[EventOut]])
def list_events(
    start_date: date,
    end_date: date,
    baby: BabyContext = Depends(authorized_baby),
    service: AnalyticsService = Depends(get_analytics_service),
):
    """Eventos entre dos fechas (días locales del bebé, ambos incluidos)."""
    if end_date < start_date:
        raise InvalidInputError("end_date no puede ser anterior a start_date")
    return ApiResponse(data=service.get_events_by_date_range(baby.id, start_date, end_date))


@router.get("/babies/{baby_id}/events/active", response_model=ApiResponse[list[EventOut]])
def list_active_events(
    category: Optional[EventCategory] = None,
    baby: BabyContext = Depends(authorized_baby),
    service: EventService = Depends(get_event_service),
):
    """Eventos con cronómetro abierto (siesta, despertar nocturno, lactancia, extracción)."""
    return ApiResponse(data=service.get_active_events(baby.id, category))


@router.get("/babies/{baby_id}/events/dates", response_model=ApiResponse[list[str]])
def list_event_dates(baby: BabyContext = Depends(authorized_baby), service: EventService = Depends(get_event_service)):
    """Días (YYYY-MM-DD, hora local) con al menos un evento, para el calendario."""
    return ApiResponse(data=service.get_valid_event_dates(baby.id, baby.tz))


@router.get("/babies/{baby_id}/events/last", response_model=ApiResponse[dict[str, str]])
def last_events(baby: BabyContext = Depends(authorized_baby), service: EventService = Depends(get_event_service)):
    """Hora del último evento de cada categoría y subtipo (bottle, nursing, diaper_wet...)."""
    return ApiResponse(data=service.get_last_events_by_category(baby.id))


@router.get("/babies/{baby_id}/growth", response_model=ApiResponse[list[GrowthPoint]])
def growth_history(baby: BabyContext = Depends(authorized_baby), service: EventService = Depends(get_event_service)):
    """Mediciones de crecimiento, de la más antigua a la más reciente."""
    return ApiResponse(data=service.get_growth_history(baby.id))


@router.patch("/events/{event_id}", response_model=ApiResponse[EventOut])
def update_event(
    update_data: EventUpdate,
    event: dict = Depends(authorized_event),
    service: EventService = Depends(get_event_service),
):
    """Cierra un evento abierto o corrige horas / metadatos / notas."""
    return ApiResponse(data=service.update_event(event, update_data))


@router.delete("/events/{event_id}", response_model=ApiResponse[EventOut])
def delete_event(event: dict = Depends(authorized_event), service: EventService = Depends(get_event_service)):
    """Elimina permanentemente un evento."""
    return ApiResponse(data=service.delete_event(event["id"]))
