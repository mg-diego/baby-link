from datetime import date

from fastapi import APIRouter, Depends, Query

from core.errors import InvalidInputError
from dependencies import authorized_baby, get_analytics_service, get_prediction_service
from models.analytics_models import DailySummary
from models.responses import ApiResponse, PredictionsResponse, StatsData
from services.access_service import BabyContext
from services.analytics import STAT_CODES, AnalyticsService
from services.prediction_service import PredictionService

router = APIRouter(tags=["Analytics"])

_CODES_DOC = "; ".join(f"{c}: {', '.join(s)}" for c, s in STAT_CODES.items())


@router.get("/babies/{baby_id}/summary", response_model=ApiResponse[DailySummary])
def daily_summary(
    day: date = Query(..., alias="date", description="Día local (YYYY-MM-DD)"),
    baby: BabyContext = Depends(authorized_baby),
    service: AnalyticsService = Depends(get_analytics_service),
):
    """Totales de un día: minutos de siesta, tomas y pañales sucios."""
    return ApiResponse(data=service.get_daily_summary(baby.id, day))


@router.get("/babies/{baby_id}/stats", response_model=ApiResponse[StatsData], description=f"Códigos: {_CODES_DOC}")
def stats(
    start_date: date,
    end_date: date,
    category: str = Query(..., description="sleep | feeding | diapers | growth"),
    subcategory: str = Query("all"),
    baby: BabyContext = Depends(authorized_baby),
    service: AnalyticsService = Depends(get_analytics_service),
):
    """Tarjetas resumen y gráficas de una categoría en un rango de fechas."""
    if end_date < start_date:
        raise InvalidInputError("end_date no puede ser anterior a start_date")
    data = service.generate_stats(baby.id, start_date, end_date, category, subcategory)
    if data is None:
        raise InvalidInputError(f"Estadística no soportada: {category}/{subcategory}. Códigos válidos: {_CODES_DOC}")
    return ApiResponse(data=data)


@router.get("/babies/{baby_id}/predictions", response_model=PredictionsResponse)
def predictions(baby: BabyContext = Depends(authorized_baby), service: PredictionService = Depends(get_prediction_service)):
    """Agenda de siestas y hora de dormir que quedan (o la de mañana, si ya es de noche)
    y la hora prevista del próximo despertar. Con pocos datos: status="insufficient_data"."""
    return service.calculate_predictions(baby.id)
