from datetime import date
from fastapi import FastAPI, Depends, HTTPException

from models.analytics_models import DailySummary
from models.event_models import EventUpdate
from models.baby_models import BabyCreate
from models.event_models import EventBase

from services.baby_service import BabyService
from services.event_service import EventService
from services.analytics_service import AnalyticsService

from dependencies import get_analytics_service, get_baby_service, get_event_service

app = FastAPI(title="BabyLink API")

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

@app.post("/events/register")
def register_event(
    event: EventBase, 
    service: EventService = Depends(get_event_service)
):
    return {"status": "success", "data": service.register_event(event)}

@app.get("/events/{baby_id}")
def get_recent_events(
    baby_id: str, 
    limit: int = 20,
    service: EventService = Depends(get_event_service)
):
    return {"status": "success", "data": service.get_recent_events(baby_id, limit)}

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