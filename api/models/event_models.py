from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field

class EventCategory(str, Enum):
    WOKE_UP = "woke_up"
    NAP = "nap"
    BED_TIME = "bed_time"
    NIGHT_WAKING = "night_waking"
    FEED = "feed"
    DIAPER = "diaper"
    MEDICINE = "medicine"
    BATH = "bath"
    TEMPERATURE = "temperature"
    GROWTH = "growth"
    PUMPING = "pumping"
    MILESTONE = "milestone"

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