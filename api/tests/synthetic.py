"""Generador de historiales de sueño 100 % sintéticos (nunca datos reales)."""
import random
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import UTC

MADRID = ZoneInfo("Europe/Madrid")


def iso(dt: datetime) -> str:
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S+00:00")


def event(category: str, start: datetime, end: datetime | None = None, metadata: dict | None = None) -> dict:
    return {
        "category": category,
        "start_time": iso(start),
        "end_time": iso(end) if end else None,
        "metadata": metadata or {},
    }


def local(day: date, hour: int, minute: int = 0, tz: ZoneInfo = MADRID) -> datetime:
    return datetime.combine(day, time(hour, minute), tzinfo=tz).astimezone(UTC)


def make_day(
    day: date,
    wake: tuple[int, int] = (7, 0),
    windows: tuple[float, ...] = (150, 180),
    naps: tuple[float, ...] = (90, 90),
    evening: float = 210,
    noise: float = 0.0,
    rng: random.Random | None = None,
    tz: ZoneInfo = MADRID,
) -> list[dict]:
    """Un día: despertar, len(windows) siestas y bed_time. `noise` = desviación típica en minutos."""
    rng = rng or random.Random(0)
    jitter = (lambda: rng.gauss(0, noise)) if noise else (lambda: 0.0)
    t = local(day, *wake, tz=tz) + timedelta(minutes=jitter())
    rows = [event("woke_up", t)]
    for ww, length in zip(windows, naps):
        start = t + timedelta(minutes=ww + jitter())
        end = start + timedelta(minutes=max(length + jitter(), 15))
        rows.append(event("nap", start, end))
        t = end
    rows.append(event("bed_time", t + timedelta(minutes=evening + jitter())))
    return rows


def make_history(first_day: date, days: int, **kwargs) -> list[dict]:
    rng = random.Random(kwargs.pop("seed", 0))
    rows = []
    for i in range(days):
        rows += make_day(first_day + timedelta(days=i), rng=rng, **kwargs)
    return rows
