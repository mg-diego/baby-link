from fastapi import APIRouter, Depends

from dependencies import authorized_baby, get_baby_service, get_current_user_id
from models.baby_models import BabyCreate, BabyUpdate
from models.responses import ApiResponse, BabyOut
from services.access_service import BabyContext
from services.baby_service import BabyService

router = APIRouter(tags=["Babies"])


@router.get("/me/babies", response_model=ApiResponse[list[BabyOut]])
def list_my_babies(user_id: str = Depends(get_current_user_id), service: BabyService = Depends(get_baby_service)):
    """Bebés del usuario autenticado."""
    return ApiResponse(data=service.get_babies(user_id))


@router.post("/babies", response_model=ApiResponse[BabyOut])
def register_baby(
    baby: BabyCreate,
    user_id: str = Depends(get_current_user_id),
    service: BabyService = Depends(get_baby_service),
):
    """Registra un nuevo bebé; el dueño es el usuario del token."""
    return ApiResponse(data=service.register_baby(baby, user_id))


@router.patch("/babies/{baby_id}", response_model=ApiResponse[BabyOut])
def update_baby(
    update_data: BabyUpdate,
    baby: BabyContext = Depends(authorized_baby),
    service: BabyService = Depends(get_baby_service),
):
    """Actualiza nombre, fecha de nacimiento, foto o zona horaria."""
    return ApiResponse(data=service.update_baby(baby.id, update_data))
