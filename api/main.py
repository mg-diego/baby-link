from datetime import date
from typing import Optional, List
import logging

from fastapi import FastAPI, Depends, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from services.sleep_service import SleepService
from models.analytics_models import DailySummary
from models.event_models import EventCategory, EventUpdate, EventBase
from models.baby_models import BabyCreate
from services.baby_service import BabyService
from services.event_service import EventService
from services.analytics_service import AnalyticsService
from dependencies import get_analytics_service, get_baby_service, get_event_service, get_sleep_service

# --- CONFIGURACIÓN ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="BabyLink API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MANEJADORES DE EXCEPCIONES ---
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error(f"❌ HTTP {exc.status_code} en {request.url.path}: {exc.detail}")
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"❌ Error de validación (422) en {request.url.path}: {exc.errors()}")
    return JSONResponse(status_code=422, content={"detail": exc.errors()})


# --- 1. RECURSO: BABIES ---
@app.post("/babies", tags=["Babies"])
def register_baby(baby: BabyCreate, service: BabyService = Depends(get_baby_service)):
    """Registra un nuevo bebé asociado a un user_id."""
    try:
        return {"status": "success", "data": service.register_baby(baby)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/babies/{user_id}", tags=["Babies"])
def get_user_babies(user_id: str, service: BabyService = Depends(get_baby_service)):
    """Obtiene la lista de bebés asociados a un usuario."""
    try:
        babies = service.get_babies(user_id)
        return {"status": "success", "data": babies}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# --- 2. RECURSO: EVENTS ---
@app.post("/events/register", tags=["Events"])
def register_event(event: EventBase, service: EventService = Depends(get_event_service)):
    """Registra un nuevo evento (comida, sueño, pañal, etc.)."""
    return {"status": "success", "data": service.register_event(event)}

@app.get("/events/active/{baby_id}", tags=["Events"])
def get_active_events(
    baby_id: str, 
    category: Optional[EventCategory] = None, 
    service: EventService = Depends(get_event_service)
):
    """Obtiene eventos que no han finalizado (ej. siesta en curso)."""
    active_events = service.repository.get_active_events(baby_id, category)
    return {"status": "success", "data": active_events}

@app.get("/events/valid-dates/{baby_id}", tags=["Events"])
def get_valid_event_dates(baby_id: str, service: EventService = Depends(get_event_service)):
    """Devuelve los días que contienen al menos un evento para el calendario."""
    try:
        dates = service.get_valid_event_dates(baby_id)
        return {"status": "success", "dates": dates}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/events/{event_id}", tags=["Events"])
def update_event(event_id: str, update_data: EventUpdate, service: EventService = Depends(get_event_service)):
    """Cierra un evento abierto o actualiza metadatos/notas."""
    return {"status": "success", "data": service.update_event(event_id, update_data)}

@app.delete("/events/{event_id}", tags=["Events"])
def delete_event(event_id: str, service: EventService = Depends(get_event_service)):
    """Elimina permanentemente un evento."""
    try:
        deleted_event = service.repository.delete_event(event_id)
        if not deleted_event:
            raise HTTPException(status_code=404, detail="El evento no existe.")
        return {"status": "success", "message": "Evento eliminado", "data": deleted_event}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# --- 3. RECURSO: ANALYTICS ---
@app.get("/analytics/{baby_id}/daily-summary", response_model=DailySummary, tags=["Analytics"])
def get_daily_summary(
    baby_id: str, 
    target_date: date, 
    service: AnalyticsService = Depends(get_analytics_service)
):
    """Obtiene el resumen de totales (ml totales, horas de sueño) de un día."""
    try:
        return service.get_daily_summary(baby_id, target_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/{baby_id}/events", tags=["Analytics"])
def get_events_by_date_range(
    baby_id: str, 
    start_date: date, 
    end_date: date, 
    service: AnalyticsService = Depends(get_analytics_service)
):
    """Obtiene todos los eventos detallados entre dos fechas."""
    try:
        events = service.get_events_by_date_range(baby_id, start_date, end_date)
        return {"status": "success", "data": events}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/analytics/{baby_id}/sleep-prediction", tags=["Analytics"])
def get_sleep_prediction(
    baby_id: str, 
    service: SleepService = Depends(get_sleep_service)
):
    """
    Calcula la agenda estimada de siestas y hora de dormir basada en 
    el histórico de los últimos 30 días y la edad biológica.
    """
    try:
        schedule = service.calculate_schedule(baby_id)
        
        if isinstance(schedule, dict) and "error" in schedule:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, 
                detail=schedule["error"]
            )
            
        return {
            "status": "success",
            "data": schedule
        }
    except Exception as e:
        logger.error(f"❌ Error calculando predicción para {baby_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"Error en el cálculo de siestas: {str(e)}"
        )
    
@app.get("/analytics/{baby_id}/wake-prediction", tags=["Analytics"])
def get_wake_prediction(
    baby_id: str, 
    service: SleepService = Depends(get_sleep_service)
):
    try:
        prediction = service.calculate_wake_prediction(baby_id)
        
        if not prediction:
            raise HTTPException(
                status_code=400, 
                detail="No hay datos suficientes para calcular el despertar."
            )
            
        return {
            "status": "success",
            "data": prediction
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail=f"Error en el cálculo de despertar: {str(e)}"
        )