from datetime import date
from typing import Optional
from fastapi import FastAPI, Depends, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from models.analytics_models import DailySummary
from models.event_models import EventCategory, EventUpdate
from models.baby_models import BabyCreate
from models.event_models import EventBase

from services.baby_service import BabyService
from services.event_service import EventService
from services.analytics_service import AnalyticsService

from dependencies import get_analytics_service, get_baby_service, get_event_service
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="BabyLink API")

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error(f"❌ HTTP {exc.status_code} en {request.url.path}: {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )

from fastapi.exceptions import RequestValidationError

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"❌ Error de validación (422) en {request.url.path}: {exc.errors()}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite peticiones desde cualquier origen (ideal para desarrollo)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos los métodos (GET, POST, OPTIONS, PATCH, etc.)
    allow_headers=["*"],  # Permite todas las cabeceras
)

@app.post("/babies")
def register_baby(
    baby: BabyCreate,
    service: BabyService = Depends(get_baby_service)
):
    """
    Registra un nuevo bebé asociado a un user_id.
    """
    try:
        return {"status": "success", "data": service.register_baby(baby)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/babies/{user_id}")
def get_user_babies(
    user_id: str,
    service: BabyService = Depends(get_baby_service)
):
    """
    Obtiene la lista de bebés asociados a un usuario.
    """
    try:
        babies = service.get_babies(user_id)
        return {"status": "success", "data": babies}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/events/register")
def register_event(
    event: EventBase, 
    service: EventService = Depends(get_event_service)
):
    return {"status": "success", "data": service.register_event(event)}
    

@app.get("/analytics/{baby_id}/daily-summary", response_model=DailySummary)
def get_daily_summary(
    baby_id: str, 
    target_date: date,
    service: AnalyticsService = Depends(get_analytics_service)
):
    try:
        return service.get_daily_summary(baby_id, target_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/{baby_id}/events")
def get_events_by_date_range(
    baby_id: str,
    start_date: date,
    end_date: date,
    service: AnalyticsService = Depends(get_analytics_service)
):
    try:
        events = service.get_events_by_date_range(baby_id, start_date, end_date)
        return {"status": "success", "data": events}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/events/{event_id}")
def close_or_update_event(
    event_id: str, 
    update_data: EventUpdate,
    service: EventService = Depends(get_event_service)
):
    """
    Cierra un evento abierto (Start-Stop) o añade notas a posteriori.
    """
    return {
        "status": "success", 
        "data": service.update_event(event_id, update_data)
    }

@app.get("/babies/{baby_id}/events/active")
def get_active_events(
    baby_id: str, 
    category: Optional[EventCategory] = None,
    service: EventService = Depends(get_event_service)
):
    active_events = service.repository.get_active_events(baby_id, category)
    
    return {
        "status": "success", 
        "data": active_events
    }

@app.delete("/events/{event_id}", status_code=status.HTTP_200_OK)
def delete_event(
    event_id: str, 
    service: EventService = Depends(get_event_service)
):
    """
    Elimina un evento permanentemente de la base de datos mediante su ID.
    """
    try:
        deleted_event = service.repository.delete_event(event_id)
        
        if not deleted_event:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, 
                detail="El evento no existe o ya fue eliminado."
            )
            
        return {
            "status": "success", 
            "message": "Evento eliminado correctamente",
            "data": deleted_event
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail=f"Error al eliminar el evento: {str(e)}"
        )
    
@app.get("/events/valid-dates/{baby_id}")
def get_valid_event_dates(baby_id: str, service: EventService = Depends(get_event_service)):
    try:
        dates = service.get_valid_event_dates(baby_id)
        return {"status": "success", "dates": dates}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))