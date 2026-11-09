import math
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import to_iso_z
from prediction.config import PredictionConfig
from prediction.feedback import FEEDBACK_KEY
from prediction.models import Biases, SleepProfile
from prediction.rules import clock_on_or_after, compensate, day_clock, wake_targets

__all__ = ["plan_day", "predict_wake", "wake_basis", "wake_item", "clock_on_or_after"]


def _td(minutes: float) -> timedelta:
    return timedelta(minutes=minutes)


def _range(raw: datetime, variance: float, floor: datetime | None, cfg: PredictionConfig) -> dict:
    """Intervalo "lo más probable" alrededor de `raw` (sin recortar a ahora). Nunca empieza
    antes de `floor`: si ya debería haber pasado, el margen empieza ahora."""
    half = min(max(cfg.range_z * math.sqrt(max(variance, 0.0)), cfg.range_min_min), cfg.range_max_min)
    earliest, latest = raw - _td(half), raw + _td(half)
    if floor is not None:
        earliest = max(earliest, floor)
        latest = max(latest, floor + _td(cfg.range_min_min))
    return {"earliest": to_iso_z(earliest), "latest": to_iso_z(latest)}


def _profile_basis(profile: SleepProfile) -> dict:
    day_type = None if profile.weekend is None else ("weekend" if profile.weekend else "weekday")
    return {"days": profile.days_learned, "day_type": day_type}


def _nap_item(index, start, raw_start, minutes, start_bias, duration_bias, catnap, overdue, start_range,
              basis) -> dict:
    return {
        "type": "nap",
        "index": index,
        "nap_index": index,
        "start": to_iso_z(start),
        "end": to_iso_z(start + _td(minutes)),
        "start_range": start_range,
        "is_catnap": catnap,
        "overdue": overdue,
        "basis": basis,
        FEEDBACK_KEY: {
            # Predicción sin recortar a "ahora": el error se mide contra ella aunque vaya con
            # retraso (si no, solo se aprendería de los días en que se durmió antes).
            "base_start": to_iso_z(raw_start),
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
    tz: ZoneInfo,
    cfg: PredictionConfig,
    anchor_var: float = 0.0,
) -> tuple[list[dict], datetime, float]:
    """Agenda desde `anchor` (último despertar real o previsto) hasta la hora de dormir.

    - `wake`: despertar de la mañana; fija la hora de dormir objetivo (wake + duración del día).
    - `next_index`: índice de la próxima siesta (1 si aún no ha dormido ninguna).
    - `deficit_min`: minutos de siesta que faltan respecto a lo esperado en las siestas ya
      hechas; si el bebé lo compensa, se acortan las ventanas que quedan.
    - `anchor_var`: incertidumbre (min²) de `anchor` si es previsto y no real.
    Devuelve los items, la hora de dormir prevista y su varianza (min²).
    """
    target_bed = wake + _td(profile.day_minutes)
    clock_bed = day_clock(wake, profile.bed_clock, tz)
    late_limit = target_bed + _td(cfg.bed_late_tolerance_min)
    sd_first, sd_mid, sd_nap = profile.sd("ww_first"), profile.sd("ww_mid"), profile.sd("nap")

    def window(index: int) -> float:
        if index == 1:
            return profile.window_before(1) + biases.ww_first
        return compensate(profile.window_before(index) + biases.ww_mid, deficit_min, profile.deficit_slope, cfg)

    ww_evening = compensate(profile.ww_evening, deficit_min, profile.deficit_slope, cfg)

    items: list[dict] = []
    cursor, index, nap_count, var = anchor, next_index, profile.nap_count, anchor_var
    common = _profile_basis(profile)

    def from_basis() -> dict:
        """Desde qué se cuenta: el despertar o el fin de la siesta anterior, real o previsto."""
        return {"from": "wake" if index == 1 else "nap", "from_time": to_iso_z(cursor),
                "from_predicted": bool(items) or anchor_var > 0}

    while index <= nap_count and len(items) < cfg.max_items - 1:
        first = index == 1
        start_bias = biases.ww_first if first else biases.ww_mid
        raw_start = cursor + _td(window(index))
        start_var = var + (sd_first if first else sd_mid) ** 2
        overdue = raw_start < now
        start = max(raw_start, now)

        duration = max(profile.nap_duration(index) + biases.nap_duration, 10.0)
        duration_bias, catnap = biases.nap_duration, False
        if start + _td(duration + ww_evening) > late_limit:
            # No cabe una siesta normal sin retrasar demasiado la noche: siesta corta o nada
            if not first and start + _td(cfg.catnap_min + ww_evening) <= late_limit:
                duration, duration_bias, catnap = cfg.catnap_min, 0.0, True
            else:
                break

        usual = profile.window_before(index)
        basis = {**common, **from_basis(),
                 "window_min": round(window(index)), "usual_window_min": round(usual),
                 "shortened_min": round(usual + start_bias - window(index)),
                 "duration_min": round(duration), "usual_duration_min": round(profile.nap_duration(index)),
                 "nap_count": nap_count, "rescue": False, "correction_min": round(start_bias)}
        items.append(_nap_item(index, start, raw_start, duration, start_bias, duration_bias, catnap, overdue,
                               _range(raw_start, start_var, now, cfg), basis))
        cursor = start + _td(duration)
        var = start_var + (sd_nap * (0.5 if catnap else 1.0)) ** 2
        index += 1

    pure_bed = cursor + _td(ww_evening)
    evening_from = from_basis()  # si hay siesta de rescate, se recalcula abajo

    # Siestas muy cortas hoy: la noche llegaría demasiado pronto -> una siesta extra corta
    rescue_margin = 150 if nap_count <= 2 else 80
    if nap_count >= 1 and index > nap_count and pure_bed < target_bed - _td(rescue_margin) \
            and len(items) < cfg.max_items - 1:
        rescue_window = window(index) * 0.85
        raw_start = cursor + _td(rescue_window)
        start_var = var + sd_mid ** 2
        overdue = raw_start < now
        start = max(raw_start, now)
        basis = {**common, **from_basis(),
                 "window_min": round(rescue_window), "usual_window_min": round(profile.window_before(index)),
                 "shortened_min": 0, "duration_min": round(cfg.catnap_min), "usual_duration_min": 0,
                 "nap_count": nap_count, "rescue": True, "correction_min": round(biases.ww_mid * 0.85)}
        items.append(_nap_item(index, start, raw_start, cfg.catnap_min, biases.ww_mid * 0.85, 0.0, True, overdue,
                               _range(raw_start, start_var, now, cfg), basis))
        cursor = start + _td(cfg.catnap_min)
        var = start_var + (sd_nap * 0.5) ** 2
        pure_bed = cursor + _td(ww_evening)
        index += 1
        evening_from = from_basis()

    # Cada bebé mezcla a su manera la ventana, la duración del día y la hora de la rutina
    a, b = profile.bed_day_weight, profile.bed_clock_weight
    bed = pure_bed + (target_bed - pure_bed) * a + (clock_bed - pure_bed) * b + _td(biases.bedtime)
    bed = min(max(bed, target_bed - _td(cfg.bed_early_tolerance_min)), late_limit)
    bed = max(bed, cursor + _td(ww_evening * cfg.min_window_factor))
    bed_var = (1 - a - b) ** 2 * var + profile.sd("bed") ** 2
    raw_bed = bed
    overdue = bed < now
    bed = max(bed, now)

    items.append({
        "type": "bedtime",
        "start": to_iso_z(bed),
        "start_range": _range(raw_bed, bed_var, now, cfg),
        "note": "Hora de dormir",
        "overdue": overdue,
        "basis": {
            **common, **evening_from,  # "from" = "wake" si el día no tiene ninguna siesta
            "window_min": round(ww_evening), "usual_window_min": round(profile.ww_evening),
            "by_window": to_iso_z(pure_bed),
            "routine_time": to_iso_z(clock_bed), "routine_weight": round(b, 2),
            "by_day_length": to_iso_z(target_bed), "day_length_min": round(profile.day_minutes),
            "day_length_weight": round(a, 2),
            "correction_min": round(biases.bedtime),
        },
        FEEDBACK_KEY: {"base_start": to_iso_z(raw_bed), "start_bias_min": round(biases.bedtime, 1), "overdue": overdue},
    })
    return items, bed, bed_var


def predict_wake(bed: datetime, profile: SleepProfile, biases: Biases, tz: ZoneInfo, cfg: PredictionConfig,
                 bed_var: float = 0.0) -> tuple[datetime, float]:
    """Mezcla "acostarse + duración habitual de la noche" con la hora habitual de despertar,
    con el peso aprendido del bebé. Devuelve (despertar, varianza en min²)."""
    target, by_duration = wake_targets(bed, profile.wake_clock, profile.night_minutes, tz)
    s = profile.wake_duration_weight
    wake = target + (by_duration - target) * s + _td(biases.wake)
    clamp = _td(max(cfg.wake_clamp_min, s * cfg.wake_duration_clamp_min))
    wake = min(max(wake, target - clamp), target + clamp)
    return wake, profile.sd("wake") ** 2 + s * s * bed_var


def wake_basis(bed: datetime | None, bed_predicted: bool, profile: SleepProfile, biases: Biases,
               tz: ZoneInfo) -> dict:
    """De dónde sale el despertar: hora habitual y/o horas de noche desde que se acostó.
    Sin `bed` (no hay noche registrada) solo cuenta la hora habitual."""
    basis = {**_profile_basis(profile), "night_weight": round(profile.wake_duration_weight, 2),
             "night_min": round(profile.night_minutes), "correction_min": round(biases.wake)}
    if bed is None:
        return {**basis, "night_weight": 0.0}
    usual, by_night = wake_targets(bed, profile.wake_clock, profile.night_minutes, tz)
    return {**basis, "bed": to_iso_z(bed), "bed_predicted": bed_predicted,
            "usual_time": to_iso_z(usual), "by_night": to_iso_z(by_night)}


def wake_item(wake: datetime, biases: Biases, variance: float, cfg: PredictionConfig,
              basis: dict | None = None) -> dict:
    return {
        "type": "woke_up",
        "start": to_iso_z(wake),
        "start_range": _range(wake, variance, None, cfg),
        "note": "Despertar previsto",
        "basis": basis,
        FEEDBACK_KEY: {"base_start": to_iso_z(wake), "start_bias_min": round(biases.wake, 1)},
    }
