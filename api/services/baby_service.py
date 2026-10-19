from typing import List
from repositories.baby_repository import BabyRepository
from fastapi import HTTPException
from models.baby_models import BabyCreate, BabyUpdate
        
class BabyService:
    def __init__(self, repository: BabyRepository):
        self.repository = repository

    def register_baby(self, baby: BabyCreate) -> dict:
        data = {
            "name": baby.name,
            "dob": baby.dob.isoformat(),
            "user_id": baby.user_id
        }
        return self.repository.save(data)
    
    def get_babies(self, user_id: str) -> List[dict]:
        return self.repository.get_by_user(user_id)

    def update_baby(self, baby_id: str, update_data: BabyUpdate) -> dict:
        # exclude_unset permite enviar photo_url: null para borrar la foto
        update_dict = update_data.model_dump(exclude_unset=True, mode='json')
        if not update_dict:
            raise HTTPException(status_code=400, detail="El payload de actualización está vacío.")
        try:
            return self.repository.update(baby_id, update_dict)
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))
