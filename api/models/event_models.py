from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field

class EventCategory(str, Enum):
    WOKE_UP = "Woke up"
    NAP = "Nap"
    BED_TIME = "Bed time"
    NIGHT_WAKING = "Night waking"
    FEED = "Feed"
    DIAPER = "Diaper"
    MEDICINE = "Medicine"
    BATH = "Bath"
    TEMPERATURE = "Temperature"
    GROWTH = "Growth"
    PUMPING = "Pumping"
    MILESTONE = "Milestone"

class EventBase(BaseModel):
    baby_id: str
    category: EventCategory
    start_time: str
    end_time: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    notes: Optional[str] = None

class EventUpdate(BaseModel):
    end_time: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None