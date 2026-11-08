from fastapi import APIRouter, Depends

from dependencies import get_home_assistant_service, require_home_assistant_key
from models.responses import ApiResponse
from services.home_assistant_service import HomeAssistantService

router = APIRouter(tags=["Home Assistant"], dependencies=[Depends(require_home_assistant_key)])


@router.get("/homeassistant/{baby_id}/summary", response_model=ApiResponse[dict])
def summary(baby_id: str, service: HomeAssistantService = Depends(get_home_assistant_service)):
    """Estado actual y resumen de hoy para Home Assistant. Requiere la cabecera X-API-Key."""
    return ApiResponse(data=service.get_summary(baby_id))
