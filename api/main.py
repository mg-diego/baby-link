from datetime import date
from typing import Optional
import logging

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import get_settings
from core.errors import DomainError, ForbiddenError, InvalidInputError
from dependencies import (
    authorized_baby_id, authorized_event, get_access_service, get_analytics_service, get_baby_service,
    get_current_user_id, get_event_service, get_home_assistant_service, get_prediction_service,
    require_home_assistant_key,
)
from models.analytics_models import DailySummary
from models.baby_models import BabyCreate, BabyUpdate
from models.event_models import EventBase, EventCategory, EventUpdate
from services.access_service import AccessService
from services.analytics_service import AnalyticsService
from services.baby_service import BabyService
from services.event_service import EventService
from services.home_assistant_service import HomeAssistantService
from services.prediction_service import PredictionService

# --- CONFIGURACIÓN ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

settings = get_settings()  # falla al arrancar si falta configuración
if not settings.auth_enabled:
    logger.warning("⚠️ AUTH_ENABLED=false: la API no comprueba quién hace las peticiones")

app = FastAPI(title="BabyLink API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    # La autenticación va por cabecera Bearer, no por cookies
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- MANEJADORES DE EXCEPCIONES ---
@app.exception_handler(DomainError)
async def domain_exception_handler(request: Request, exc: DomainError):
    logger.info("HTTP %s en %s: %s", exc.status_code, request.url.path, exc.message)
    headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message}, headers=headers)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error("HTTP %s en %s: %s", exc.status_code, request.url.path, exc.detail)
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail}, headers=exc.headers)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # jsonable_encoder: los errores pueden incluir excepciones (ctx.error) que no son JSON
    errors = jsonable_encoder(exc.errors())
    logger.warning("Error de validación (422) en %s: %s", request.url.path, errors)
    return JSONResponse(status_code=422, content={"detail": errors})


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # El detalle va al log, nunca al cliente (puede contener datos internos de la BD)
    logger.exception("Error no controlado en %s", request.url.path)
    return JSONResponse(status_code=500, content={"detail": "Error interno del servidor"})


# --- 1. RECURSO: BABIES ---
@app.post("/babies", tags=["Babies"])
def register_baby(
    baby: BabyCreate,
    user_id: Optional[str] = Depends(get_current_user_id),
    service: BabyService = Depends(get_baby_service),
):
    """Registra un nuevo bebé para el usuario autenticado."""
    owner_id = user_id or baby.user_id
    if not owner_id:
        raise InvalidInputError("Falta user_id")
    return {"status": "success", "data": service.register_baby(baby, owner_id)}


@app.get("/babies/{user_id}", tags=["Babies"])
def get_user_babies(
    user_id: str,
    current_user_id: Optional[str] = Depends(get_current_user_id),
    service: BabyService = Depends(get_baby_service),
):
    """Obtiene la lista de bebés del usuario (solo los propios)."""
    if current_user_id is not None and user_id != current_user_id:
        raise ForbiddenError("No puedes consultar los bebés de otro usuario")
    return {"status": "success", "data": service.get_babies(user_id)}


@app.patch("/babies/{baby_id}", tags=["Babies"])
def update_baby(
    update_data: BabyUpdate,
    baby_id: str = Depends(authorized_baby_id),
    service: BabyService = Depends(get_baby_service),
):
    """Actualiza los datos del bebé (nombre, fecha de nacimiento o foto)."""
    return {"status": "success", "data": service.update_baby(baby_id, update_data)}


# --- 2. RECURSO: EVENTS ---
@app.post("/events/register", tags=["Events"])
def register_event(
    event: EventBase,
    user_id: Optional[str] = Depends(get_current_user_id),
    access: AccessService = Depends(get_access_service),
    service: EventService = Depends(get_event_service),
):
    """Registra un nuevo evento (comida, sueño, pañal, etc.)."""
    access.ensure_baby(user_id, event.baby_id)
    return {"status": "success", "data": service.register_event(event)}


@app.get("/events/active/{baby_id}", tags=["Events"])
def get_active_events(
    category: Optional[EventCategory] = None,
    baby_id: str = Depends(authorized_baby_id),
    service: EventService = Depends(get_event_service),
):
    """Obtiene eventos que no han finalizado (ej. siesta en curso)."""
    return {"status": "success", "data": service.get_active_events(baby_id, category)}


@app.get("/events/valid-dates/{baby_id}", tags=["Events"])
def get_valid_event_dates(baby_id: str = Depends(authorized_baby_id), service: EventService = Depends(get_event_service)):
    """Devuelve los días (hora local) que contienen al menos un evento, para el calendario."""
    return {"status": "success", "dates": service.get_valid_event_dates(baby_id)}


@app.get("/events/last/{baby_id}", tags=["Events"])
def get_last_events_by_category(baby_id: str = Depends(authorized_baby_id), service: EventService = Depends(get_event_service)):
    """Hora del último evento de cada categoría (y subtipo de toma / pañal)."""
    return service.get_last_events_by_category(baby_id)


@app.get("/events/growth/{baby_id}", tags=["Events"])
def get_growth_history(baby_id: str = Depends(authorized_baby_id), service: EventService = Depends(get_event_service)):
    """Devuelve todas las mediciones de crecimiento ordenadas de más antigua a más reciente."""
    return {"status": "success", "data": service.get_growth_history(baby_id)}


@app.patch("/events/{event_id}", tags=["Events"])
def update_event(
    update_data: EventUpdate,
    event: dict = Depends(authorized_event),
    service: EventService = Depends(get_event_service),
):
    """Cierra un evento abierto o actualiza horas / metadatos / notas."""
    return {"status": "success", "data": service.update_event(event, update_data)}


@app.delete("/events/{event_id}", tags=["Events"])
def delete_event(event: dict = Depends(authorized_event), service: EventService = Depends(get_event_service)):
    """Elimina permanentemente un evento."""
    deleted = service.delete_event(event["id"])
    return {"status": "success", "message": "Evento eliminado", "data": deleted}


# --- 3. RECURSO: ANALYTICS ---
@app.get("/analytics/{baby_id}/daily-summary", response_model=DailySummary, tags=["Analytics"])
def get_daily_summary(
    target_date: date,
    baby_id: str = Depends(authorized_baby_id),
    service: AnalyticsService = Depends(get_analytics_service),
):
    """Obtiene el resumen de totales (minutos de siesta, tomas, pañales sucios) de un día."""
    return service.get_daily_summary(baby_id, target_date)


@app.get("/analytics/{baby_id}/events", tags=["Analytics"])
def get_events_by_date_range(
    start_date: date,
    end_date: date,
    baby_id: str = Depends(authorized_baby_id),
    service: AnalyticsService = Depends(get_analytics_service),
):
    """Obtiene todos los eventos detallados entre dos fechas (días locales)."""
    if end_date < start_date:
        raise InvalidInputError("end_date no puede ser anterior a start_date")
    return {"status": "success", "data": service.get_events_by_date_range(baby_id, start_date, end_date)}


@app.get("/analytics/{baby_id}/sleep-prediction", tags=["Analytics"])
def get_sleep_prediction(baby_id: str = Depends(authorized_baby_id), service: PredictionService = Depends(get_prediction_service)):
    """Agenda estimada de siestas y hora de dormir para lo que queda del día (o para
    mañana, si ya es de noche). Con pocos datos: status="insufficient_data" y data=[]."""
    return service.calculate_schedule(baby_id)


@app.get("/analytics/{baby_id}/wake-prediction", tags=["Analytics"])
def get_wake_prediction(baby_id: str = Depends(authorized_baby_id), service: PredictionService = Depends(get_prediction_service)):
    """Hora prevista del próximo despertar de la mañana. Con pocos datos: data=null."""
    return service.calculate_wake_prediction(baby_id)


@app.get("/analytics/{baby_id}/stats", tags=["Analytics"])
def get_stats(
    start_date: date = Query(..., description="Formato YYYY-MM-DD"),
    end_date: date = Query(..., description="Formato YYYY-MM-DD"),
    category: str = Query(..., description="Categoría principal (ej: Sueño)"),
    subcategory: str = Query("Todo", description="Subcategoría (ej: Siestas)"),
    baby_id: str = Depends(authorized_baby_id),
    service: AnalyticsService = Depends(get_analytics_service),
):
    if end_date < start_date:
        raise InvalidInputError("end_date no puede ser anterior a start_date")
    data = service.generate_stats(baby_id, start_date, end_date, category, subcategory)
    if data is None:
        raise InvalidInputError(f"Categoría no soportada: {category} / {subcategory}")
    return {"status": "success", "data": data}


# --- 4. HOME ASSISTANT ---
@app.get("/homeassistant/{baby_id}/summary", tags=["Home Assistant"], dependencies=[Depends(require_home_assistant_key)])
def get_home_assistant_data(baby_id: str, service: HomeAssistantService = Depends(get_home_assistant_service)):
    """Estado actual y resumen de hoy para Home Assistant. Requiere la cabecera X-API-Key."""
    return {"status": "success", "data": service.get_summary(baby_id)}
