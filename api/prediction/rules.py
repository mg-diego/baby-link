"""Reglas que comparten el aprendizaje del perfil y la generación de la agenda.

Tienen que ser las mismas en los dos sitios: los pesos se aprenden comparando la realidad
con lo que habrían dado estas reglas.
"""
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import UTC, local_midnight_utc
from prediction.config import PredictionConfig


def clock_on_or_after(reference: datetime, clock_minutes: float, tz: ZoneInfo) -> datetime:
    """Primera vez, a partir de `reference`, que el reloj local marca `clock_minutes`.
    Se calcula en hora local para que el cambio de hora no desplace el resultado."""
    local = reference.astimezone(tz)
    h, m = divmod(int(round(clock_minutes)) % 1440, 60)
    candidate = datetime.combine(local.date(), time(h, m), tzinfo=tz)
    if candidate <= local:
        candidate = datetime.combine(local.date() + timedelta(days=1), time(h, m), tzinfo=tz)
    return candidate.astimezone(UTC)


def day_clock(day_start: datetime, clock_minutes: float, tz: ZoneInfo) -> datetime:
    """Medianoche local del día de `day_start` + `clock_minutes` (puede pasar de 24 h)."""
    return local_midnight_utc(day_start.astimezone(tz).date(), tz) + timedelta(minutes=clock_minutes)


def wake_targets(bed: datetime, wake_clock: float, night_minutes: float, tz: ZoneInfo) -> tuple[datetime, datetime]:
    """(hora habitual de despertar tras `bed`, acostarse + duración habitual de la noche)."""
    by_duration = bed + timedelta(minutes=night_minutes)
    target = clock_on_or_after(bed, wake_clock, tz)
    if target - bed > timedelta(hours=18):
        target = by_duration  # se acostó a una hora atípica (p. ej. de madrugada): manda la duración
    return target, by_duration


def compensate(window: float, deficit_min: float, slope: float, cfg: PredictionConfig) -> float:
    """Acorta una ventana tras siestas más cortas de lo esperado (si el bebé lo hace)."""
    if deficit_min > cfg.deficit_threshold_min and slope > 0:
        return max(window * cfg.min_window_factor, window - deficit_min * slope)
    return window
