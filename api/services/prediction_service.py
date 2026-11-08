from datetime import date, datetime, timedelta
from typing import Callable
from zoneinfo import ZoneInfo

from core.errors import NotFoundError
from core.timeutils import utc_now
from prediction import DEFAULT_CONFIG, PredictionConfig, predict
from prediction.models import SLEEP_CATEGORIES, PredictionOutput
from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository


class PredictionService:
    """Carga los datos y delega en el motor puro (`prediction/`)."""

    def __init__(
        self,
        event_repository: EventRepository,
        baby_repository: BabyRepository,
        tz: ZoneInfo,
        clock: Callable[[], datetime] = utc_now,
        config: PredictionConfig = DEFAULT_CONFIG,
    ):
        self.event_repository = event_repository
        self.baby_repository = baby_repository
        self.tz = tz
        self.clock = clock
        self.config = config

    def calculate_schedule(self, baby_id: str) -> dict:
        out = self._run(baby_id)
        if out.insufficient:
            return _insufficient(out, data=[])
        return {"status": "success", "data": out.schedule}

    def calculate_wake_prediction(self, baby_id: str) -> dict:
        out = self._run(baby_id)
        if out.insufficient:
            return _insufficient(out, data=None)
        return {"status": "success", "data": out.wake}

    def _run(self, baby_id: str) -> PredictionOutput:
        baby = self.baby_repository.get_by_id(baby_id)
        if not baby:
            raise NotFoundError("Bebé no encontrado")
        now = self.clock()
        since = now - timedelta(days=self.config.history_days + 1)
        events = self.event_repository.get_events_since(baby_id, since, SLEEP_CATEGORIES)
        return predict(events, date.fromisoformat(str(baby["dob"])[:10]), now, self.tz, self.config)


def _insufficient(out: PredictionOutput, data) -> dict:
    # Mismo formato que el caso de éxito (data vacío) para que la app no tenga que distinguir
    return {
        "status": "insufficient_data",
        "data": data,
        "detail": {
            "reason": out.insufficient.reason,
            "required": out.insufficient.required,
            "current": out.insufficient.current,
        },
    }
