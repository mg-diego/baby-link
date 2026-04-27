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