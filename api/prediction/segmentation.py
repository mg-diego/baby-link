from datetime import datetime, timedelta

from core.timeutils import parse_ts
from prediction.config import PredictionConfig
from prediction.models import BED_TIME, NAP, NAP_SKIPPED, SLEEP_CATEGORIES, WOKE_UP, DayState, Nap, SleepDay, SleepEvent


def parse_events(raw: list[dict]) -> list[SleepEvent]:
    """Filas de BD -> eventos de sueño ordenados. Ignora categorías ajenas y filas corruptas."""
    events = []
    for row in raw:
        if row.get("category") not in SLEEP_CATEGORIES:
            continue
        try:
            start = parse_ts(row.get("start_time"))
            end = parse_ts(row.get("end_time"))
        except ValueError:
            continue
        if start is None:
            continue
        if end is not None and end <= start:
            continue  # registro incoherente (fin antes del inicio): no aporta información fiable
        meta = row.get("metadata")
        events.append(SleepEvent(row["category"], start, end, meta if isinstance(meta, dict) else {}))
    events.sort(key=lambda e: e.start)
    return events


def segment_days(events: list[SleepEvent], cfg: PredictionConfig) -> list[SleepDay]:
    """Agrupa los eventos en días de sueño. Un woke_up abre un día y un bed_time lo cierra.
    Si falta alguno (se olvidó registrar), el día se abre o cierra de forma implícita."""
    max_day = timedelta(hours=cfg.max_day_hours)
    days: list[SleepDay] = []
    current: SleepDay | None = None

    def close():
        nonlocal current
        if current is not None:
            days.append(current)
        current = None

    for ev in events:
        if current is not None and current.anchor and ev.start - current.anchor > max_day:
            close()  # p. ej. ayer no se registró el bed_time

        if ev.category == WOKE_UP:
            close()
            current = SleepDay(wake=ev.start)
        elif ev.category == NAP:
            if current is None:
                current = SleepDay(wake=None)
            previous = current.naps[-1] if current.naps else None
            if previous and previous.end is None and ev.start - previous.start < timedelta(hours=cfg.max_open_nap_hours):
                # Siesta anterior sin cerrar y otra encima: la anterior se descarta como dato
                current.naps.pop()
            current.naps.append(Nap(ev.start, ev.end, len(current.naps) + 1, ev.metadata))
        elif ev.category == NAP_SKIPPED:
            # Solo tiene sentido dentro de un día ya abierto (sin él no hay agenda que corregir)
            if current is not None:
                current.skipped.append(ev.start)
        elif ev.category == BED_TIME:
            if current is None:
                current = SleepDay(wake=None)
            current.bed = ev.start
            close()
    close()
    return days


def current_state(days: list[SleepDay], now: datetime, cfg: PredictionConfig) -> DayState:
    if not days:
        return DayState("unknown")
    last = days[-1]
    if last.bed is None and last.anchor and timedelta(0) <= now - last.anchor < timedelta(hours=cfg.max_day_hours):
        return DayState("day", day=last)
    if last.bed is not None and timedelta(0) <= now - last.bed < timedelta(hours=cfg.night_state_hours):
        return DayState("night", bed=last.bed)
    return DayState("unknown")
