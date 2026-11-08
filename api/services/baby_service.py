from typing import List

from core.errors import InvalidInputError, NotFoundError
from models.baby_models import BabyCreate, BabyUpdate
from repositories.baby_repository import BabyRepository
from services.access_service import AccessService


class BabyService:
    def __init__(self, repository: BabyRepository):
        self.repository = repository

    def register_baby(self, baby: BabyCreate, owner_id: str) -> dict:
        data = {"name": baby.name, "dob": baby.dob.isoformat(), "user_id": owner_id}
        if baby.timezone:  # columna opcional (migración 001): solo se envía si se indica
            data["timezone"] = baby.timezone
        return self.repository.save(data)

    def get_babies(self, user_id: str) -> List[dict]:
        return self.repository.get_by_user(user_id)

    def update_baby(self, baby_id: str, update_data: BabyUpdate) -> dict:
        # exclude_unset permite enviar photo_url: null para borrar la foto
        update_dict = update_data.model_dump(exclude_unset=True, mode="json")
        if not update_dict:
            raise InvalidInputError("El payload de actualización está vacío.")
        updated = self.repository.update(baby_id, update_dict)
        if not updated:
            raise NotFoundError("Bebé no encontrado")
        AccessService.forget(baby_id)  # puede haber cambiado la zona horaria
        return updated
