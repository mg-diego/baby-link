from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import UTC, to_iso_z
from prediction.config import PredictionConfig
from prediction.feedback import FEEDBACK_KEY
from prediction.models import Biases, SleepProfile


def _td(minutes: float) -> timedelta:
    return timedelta(minutes=minutes)


def _bed_blend_factor(nap_count: int) -> float:
    """Cuánto se tira de la hora de dormir hacia la habitual (frente a "última siesta +
    ventana"). Con muchas siestas manda la ventana; con pocas, el reloj."""
    return {0: 0.60, 1: 0.40, 2: 0.25, 3: 0.10}.get(nap_count, 0.0)


def _nap_item(index, start, minutes, start_bias, duration_bias, catnap, overdue) -> dict:
    return {
        "type": "nap",
        "index": index,
        "nap_index": index,
        "start": to_iso_z(start),
        "end": to_iso_z(start + _td(minutes)),
        "is_catnap": catnap,
        "overdue": overdue,
        FEEDBACK_KEY: {
            "start_bias_min": round(start_bias, 1),
            "duration_bias_min": round(duration_bias, 1),
            "catnap": catnap,
            "overdue": overdue,
            "nap_index": index,
        },
    }


def plan_day(
    wake: datetime,
    anchor: datetime,
    next_index: int,
    deficit_min: float,
    profile: SleepProfile,
    biases: Biases,
    now: datetime,
    cfg: PredictionConfig,
) -> tuple[list[dict], datetime]:
    """Agenda desde `anchor` (último despertar real o previsto) hasta la hora de dormir.

    - `wake`: despertar de la mañana; fija la hora de dormir objetivo (wake + duración del día).
    - `next_index`: índice de la próxima siesta (1 si aún no ha dormido ninguna).
    - `deficit_min`: minutos de siesta que faltan respecto a lo esperado en las siestas ya
      hechas; si es relevante, se acortan las ventanas que quedan.
    Devuelve los items y la hora de dormir prevista.
    """
    target_bed = wake + _td(profile.day_minutes)
    late_limit = target_bed + _td(cfg.bed_late_tolerance_min)

    ww_first = profile.ww_first + biases.ww_first
    ww_mid = profile.ww_mid + biases.ww_mid
    ww_evening = profile.ww_evening
    if deficit_min > cfg.deficit_threshold_min and profile.deficit_slope > 0:
        compensation = deficit_min * profile.deficit_slope
        ww_mid = max(ww_mid * cfg.min_window_factor, ww_mid - compensation)
        ww_evening = max(ww_evening * cfg.min_window_factor, ww_evening - compensation)

    items: list[dict] = []
    cursor, index, nap_count = anchor, next_index, profile.nap_count

    while index <= nap_count and len(items) < cfg.max_items - 1:
        first = index == 1
        start_bias = biases.ww_first if first else biases.ww_mid
        start = cursor + _td(ww_first if first else ww_mid)
        overdue = start < now
        start = max(start, now)

        duration = max(profile.nap_duration(index) + biases.nap_duration, 10.0)
        duration_bias, catnap = biases.nap_duration, False
        if start + _td(duration + ww_evening) > late_limit:
            # No cabe una siesta normal sin retrasar demasiado la noche: siesta corta o nada
            if not first and start + _td(cfg.catnap_min + ww_evening) <= late_limit:
                duration, duration_bias, catnap = cfg.catnap_min, 0.0, True
            else:
                break

        items.append(_nap_item(index, start, duration, start_bias, duration_bias, catnap, overdue))
        cursor = start + _td(duration)
        index += 1

    pure_bed = cursor + _td(ww_evening)

    # Siestas muy cortas hoy: la noche llegaría demasiado pronto -> una siesta extra corta
    rescue_margin = 150 if nap_count <= 2 else 80
    if nap_count >= 1 and index > nap_count and pure_bed < target_bed - _td(rescue_margin) \
            and len(items) < cfg.max_items - 1:
        start = cursor + _td(ww_mid * 0.85)
        overdue = start < now
        start = max(start, now)
        items.append(_nap_item(index, start, cfg.catnap_min, biases.ww_mid * 0.85, 0.0, True, overdue))
        cursor = start + _td(cfg.catnap_min)
        pure_bed = cursor + _td(ww_evening)

    diff_min = (target_bed - pure_bed).total_seconds() / 60
    factor = _bed_blend_factor(nap_count)
    if abs(diff_min) > 30:
        factor *= 0.15  # día atípico: se respeta la ventana, no se fuerza el reloj
    bed = pure_bed + _td(diff_min * factor + biases.bedtime)
    bed = min(max(bed, target_bed - _td(cfg.bed_early_tolerance_min)), late_limit)
    bed = max(bed, cursor + _td(ww_evening * cfg.min_window_factor))
    overdue = bed < now
    bed = max(bed, now)

    items.append({
        "type": "bedtime",
        "start": to_iso_z(bed),
        "note": "Hora de dormir",
        "overdue": overdue,
        FEEDBACK_KEY: {"start_bias_min": round(biases.bedtime, 1), "overdue": overdue},
    })
    return items, bed


def clock_on_or_after(reference: datetime, clock_minutes: float, tz: ZoneInfo) -> datetime:
    """Primera vez, a partir de `reference`, que el reloj local marca `clock_minutes`.
    Se calcula en hora local para que el cambio de hora no desplace el resultado."""
    local = reference.astimezone(tz)
    h, m = divmod(int(round(clock_minutes)) % 1440, 60)
    candidate = datetime.combine(local.date(), time(h, m), tzinfo=tz)
    if candidate <= local:
        candidate = datetime.combine(local.date() + timedelta(days=1), time(h, m), tzinfo=tz)
    return candidate.astimezone(UTC)


def predict_wake(bed: datetime, profile: SleepProfile, biases: Biases, tz: ZoneInfo, cfg: PredictionConfig) -> datetime:
    """Combina "acostarse + duración habitual de la noche" con la hora habitual de despertar."""
    by_duration = bed + _td(profile.night_minutes)
    target = clock_on_or_after(bed, profile.wake_clock, tz)
    if target - bed > timedelta(hours=18):
        target = by_duration  # se acostó a una hora atípica (p. ej. de madrugada): manda la duración
    wake = by_duration + (target - by_duration) * cfg.wake_clock_blend + _td(biases.wake)
    clamp = _td(cfg.wake_clamp_min)
    return min(max(wake, target - clamp), target + clamp)


def wake_item(wake: datetime, biases: Biases) -> dict:
    return {
        "type": "woke_up",
        "start": to_iso_z(wake),
        "note": "Despertar previsto",
        FEEDBACK_KEY: {"start_bias_min": round(biases.wake, 1)},
    }
