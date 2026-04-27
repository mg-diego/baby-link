from datetime import date
from pydantic import BaseModel

class DailySummary(BaseModel):
    target_date: date
    total_nap_minutes: int
    total_feeds: int
    total_dirty_diapers: int