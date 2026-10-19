from datetime import date
from typing import Optional
from pydantic import BaseModel

class BabyCreate(BaseModel):
    name: str
    dob: date
    user_id: str

class BabyUpdate(BaseModel):
    name: Optional[str] = None
    dob: Optional[date] = None
    photo_url: Optional[str] = None
