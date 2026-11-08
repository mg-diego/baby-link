from datetime import date
from typing import Optional

from pydantic import BaseModel


class BabyCreate(BaseModel):
    name: str
    dob: date
    # Se ignora cuando la autenticación está activa: el dueño es siempre el usuario del token.
    user_id: Optional[str] = None


class BabyUpdate(BaseModel):
    name: Optional[str] = None
    dob: Optional[date] = None
    photo_url: Optional[str] = None
