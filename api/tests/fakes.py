"""Repositorios en memoria con la misma interfaz que los de Supabase."""
import itertools
from datetime import datetime

from core.timeutils import parse_ts

_ids = itertools.count(1)


class FakeBabyRepository:
    def __init__(self, babies: list[dict] | None = None):
        self.babies = babies or []

    def save(self, data):
        row = {"id": f"baby-{next(_ids)}", "photo_url": None, **data}
        self.babies.append(row)
        return row

    def get_by_user(self, user_id):
        return [b for b in self.babies if b["user_id"] == user_id]

    def get_by_id(self, baby_id):
        return next((b for b in self.babies if b["id"] == baby_id), None)

    def update(self, baby_id, data):
        baby = self.get_by_id(baby_id)
        if baby:
            baby.update(data)
        return baby


class FakeEventRepository:
    def __init__(self, events: list[dict] | None = None):
        self.events = []
        for e in events or []:
            self.events.append({"id": f"ev-{next(_ids)}", "end_time": None, "metadata": {}, **e})

    def _asc(self, rows):
        return sorted(rows, key=lambda e: parse_ts(e["start_time"]))

    def save(self, data):
        row = {"id": f"ev-{next(_ids)}", **data}
        self.events.append(row)
        return row

    def update(self, event_id, data):
        row = self.get_by_id(event_id)
        if row:
            row.update(data)
        return row

    def delete(self, event_id):
        row = self.get_by_id(event_id)
        if row:
            self.events.remove(row)
        return row

    def get_by_id(self, event_id):
        return next((e for e in self.events if e["id"] == event_id), None)

    def get_open_duration_events(self, baby_id, category=None):
        return [
            e for e in reversed(self._asc(self.events))
            if e["baby_id"] == baby_id and e.get("end_time") is None
            and e["category"] in ("nap", "night_waking", "feed", "pumping")
            and (category is None or e["category"] == category)
        ]

    def get_by_category(self, baby_id, category):
        return [e for e in self._asc(self.events) if e["baby_id"] == baby_id and e["category"] == category]

    def get_all_start_times(self, baby_id):
        return [{"start_time": e["start_time"]} for e in self.events if e["baby_id"] == baby_id]

    def get_event_dates(self, baby_id, tz_name):
        return None  # simula que la migración SQL aún no está aplicada

    def get_last_event_times(self, baby_id):
        return None

    def get_latest(self, baby_id, limit=1000, categories=None):
        rows = [e for e in reversed(self._asc(self.events))
                if e["baby_id"] == baby_id and (categories is None or e["category"] in categories)]
        return rows[:limit]

    def get_events_since(self, baby_id, since: datetime, categories=None):
        return [e for e in self._asc(self.events)
                if e["baby_id"] == baby_id and parse_ts(e["start_time"]) >= since
                and (categories is None or e["category"] in categories)]
