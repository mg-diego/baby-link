from datetime import date
from pydantic import BaseModel

class BabyCreate(BaseModel):
    name: str
    dob: date
    user_id: str