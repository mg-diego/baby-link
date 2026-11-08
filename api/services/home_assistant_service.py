from datetime import datetime, timedelta
from typing import Any, Callable, Dict
from zoneinfo import ZoneInfo

from core.errors import NotFoundError
from core.timeutils import local_midnight_utc, parse_ts, utc_now
from models.event_models import EventCategory
from repositories.baby_repository import BabyRepository
from repositories.event_repository import EventRepository
from services.access_service import resolve_timezone

NAP = EventCategory.NAP.value
BED = EventCategory.BED_TIME.value
WOKE = EventCategory.WOKE_UP.value
WAKING = EventCategory.NIGHT_WAKING.value
FEED = EventCategory.FEED.value
DIAPER = EventCategory.DIAPER.value

COUNTED_DIAPERS = ("dirty", "mixed", "wet")
# Para saber si duerme desde anoche hay que mirar antes de medianoche
LOOKBACK = timedelta(hours=18)
# Una siesta abierta durante más de esto es un cronómetro olvidado, no una siesta
MAX_OPEN_NAP = timedelta(hours=6)


class HomeAssistantService:
    def __init__(
        self,
        baby_repository: BabyRepository,
        event_repository: EventRepository,
        default_tz: ZoneInfo,
        clock: Callable[[], datetime] = utc_now,
    ):
        self.baby_repository = baby_repository
        self.event_repository = event_repository
        self.default_tz = default_tz
        self.clock = clock

    def get_summary(self, baby_id: str) -> Dict[str, Any]:
        baby = self.baby_repository.get_by_id(baby_id)
        if not baby:
            raise NotFoundError("Bebé no encontrado")

        tz = resolve_timezone(baby.get("timezone"), self.default_tz)
        now = self.clock()
        day_start = local_midnight_utc(now.astimezone(tz).date(), tz)
        events = [
            {**e, "_start": parse_ts(e["start_time"]), "_end": parse_ts(e.get("end_time"))}
            for e in self.event_repository.get_events_since(baby_id, day_start - LOOKBACK)
        ]
        today = [e for e in events if e["_start"] >= day_start]

        return {
            "baby_id": str(baby_id),
            "name": baby.get("name") or "",
            "current_state": self._current_state(events, now),
            "today_summary": {
                "total_sleep_mins": self._sleep_minutes(events, day_start, now),
                "total_feeds": sum(1 for e in today if e["category"] == FEED),
                "total_diapers": sum(
                    1 for e in today
                    if e["category"] == DIAPER
                    and (e.get("metadata") or {}).get("condition") in COUNTED_DIAPERS
                ),
            },
            "last_events": self._last_events(baby_id, events),
        }

    def _current_state(self, events: list[dict], now: datetime) -> dict:
        state = {"is_sleeping": False, "current_sleep_type": None, "sleeping_since": None}
        open_nap = next(
            (e for e in reversed(events)
             if e["category"] == NAP and e["_end"] is None and now - e["_start"] < MAX_OPEN_NAP),
            None,
        )
        if open_nap:
            return {"is_sleeping": True, "current_sleep_type": "Siesta", "sleeping_since": open_nap["start_time"]}

        last_marker = next((e for e in reversed(events) if e["category"] in (BED, WOKE)), None)
        if last_marker and last_marker["category"] == BED:
            awake_now = any(e["category"] == WAKING and e["_end"] is None and e["_start"] >= last_marker["_start"]
                            for e in events)
            if not awake_now:
                state = {"is_sleeping": True, "current_sleep_type": "Noche",
                         "sleeping_since": last_marker["start_time"]}
        return state

    @staticmethod
    def _sleep_minutes(events: list[dict], day_start: datetime, now: datetime) -> int:
        """Minutos dormidos desde la medianoche local hasta ahora: siestas más noches
        (de bed_time al siguiente woke_up) menos los despertares nocturnos."""
        def clipped(start: datetime, end: datetime) -> float:
            return max(0.0, (min(end, now) - max(start, day_start)).total_seconds() / 60)

        total = 0.0
        for i, e in enumerate(events):
            if e["category"] == NAP:
                end = e["_end"] or (now if now - e["_start"] < MAX_OPEN_NAP else e["_start"])
                total += clipped(e["_start"], end)
            elif e["category"] == BED:
                closing = next((x for x in events[i + 1:] if x["category"] in (WOKE, BED)), None)
                if closing is None:
                    night_end = now  # sigue durmiendo
                elif closing["category"] == WOKE:
                    night_end = closing["_start"]
                else:
                    continue  # dos bed_time seguidos: esa noche no se cerró y no se cuenta
                total += clipped(e["_start"], night_end)
                for w in events[i + 1:]:
                    if w["_start"] >= night_end:
                        break
                    if w["category"] == WAKING:
                        total -= clipped(w["_start"], w["_end"] or now)
        return int(round(max(total, 0)))

    def _last_events(self, baby_id: str, events: list[dict]) -> dict:
        last_feed = next((e for e in reversed(events) if e["category"] == FEED), None)
        last_diaper = next((e for e in reversed(events) if e["category"] == DIAPER), None)
        if last_feed is None or last_diaper is None:
            older = self.event_repository.get_latest(baby_id, limit=200, categories=[FEED, DIAPER])
            last_feed = last_feed or next((e for e in older if e["category"] == FEED), None)
            last_diaper = last_diaper or next((e for e in older if e["category"] == DIAPER), None)

        feed_meta = (last_feed or {}).get("metadata") or {}
        diaper_meta = (last_diaper or {}).get("metadata") or {}
        return {
            "last_feed": {
                "time": last_feed["start_time"] if last_feed else None,
                "type": feed_meta.get("type", "-"),
                "amount_ml": feed_meta.get("amount_ml", 0),
            },
            "last_diaper": {
                "time": last_diaper["start_time"] if last_diaper else None,
                "condition": diaper_meta.get("condition", "clean"),
            },
        }
