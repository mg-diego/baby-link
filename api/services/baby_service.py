from typing import List
from repositories.baby_repository import BabyRepository
from models.baby_models import BabyCreate
        
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