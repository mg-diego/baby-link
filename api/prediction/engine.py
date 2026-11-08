from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import local_midnight_utc
from prediction.config import DEFAULT_CONFIG, PredictionConfig
from prediction.feedback import compute_biases
from prediction.models import Biases, PredictionOutput, SleepEvent, SleepProfile, Sufficiency
from prediction.profile import learn_profile
from prediction.schedule import clock_on_or_after, plan_day, predict_wake, wake_item
from prediction.segmentation import current_state, parse_events, segment_days


def check_sufficiency(events: list[SleepEvent], tz: ZoneInfo, cfg: PredictionConfig) -> Sufficiency | None:
    if len(events) < cfg.min_sleep_events:
        return Sufficiency("insufficient_events", cfg.min_sleep_events, len(events))
    days = len({e.start.astimezone(tz).date() for e in events})
    if days < cfg.min_days:
        return Sufficiency("insufficient_days", cfg.min_days, days)
    return None


def predict(
    raw_events: list[dict],
    dob: date,
    now: datetime,
    tz: ZoneInfo,
    cfg: PredictionConfig = DEFAULT_CONFIG,
) -> PredictionOutput:
    """Agenda del resto del día + hora prevista de despertar.

    `raw_events`: filas de baby_events (se ignoran las que no son de sueño).
    `now`: datetime aware; se inyecta para poder testear y hacer backtesting.
    """
    horizon = now - timedelta(days=cfg.history_days)
    events = [e for e in parse_events(raw_events) if horizon <= e.start <= now]

    insufficient = check_sufficiency(events, tz, cfg)
    if insufficient:
        return PredictionOutput(insufficient=insufficient)

    days = segment_days(events, cfg)
    state = current_state(days, now, cfg)
    # El día en curso no entra en el perfil: está a medias
    history = days[:-1] if state.kind == "day" else days
    profile = learn_profile(history, dob, now, tz, cfg)
    biases = compute_biases(events, cfg)

    if state.kind == "day":
        schedule, bed = _plan_open_day(state.day, profile, biases, now, cfg)
        wake = predict_wake(bed, profile, biases, tz, cfg)
    elif state.kind == "night":
        # De noche, la agenda que interesa es la de mañana, partiendo del despertar previsto
        wake = predict_wake(state.bed, profile, biases, tz, cfg)
        schedule, _ = plan_day(wake, wake, 1, 0.0, profile, biases, now, cfg)
    else:
        schedule, wake = _plan_without_recent_data(profile, biases, now, tz, cfg)

    return PredictionOutput(
        schedule=schedule, wake=wake_item(wake, biases), state=state.kind, profile=profile,
    )


def _plan_open_day(day, profile: SleepProfile, biases: Biases, now: datetime, cfg: PredictionConfig):
    naps = day.naps
    wake = day.wake or (naps[0].start - timedelta(minutes=profile.ww_first))
    ongoing = naps[-1] if naps and naps[-1].end is None else None
    closed = [n for n in naps if n.end is not None]

    if ongoing is not None:
        expected_end = ongoing.start + timedelta(minutes=profile.nap_duration(ongoing.index) + biases.nap_duration)
        if now - ongoing.start > timedelta(hours=cfg.max_open_nap_hours):
            anchor = expected_end  # cronómetro olvidado: se supone que duró lo habitual
        else:
            anchor = max(expected_end, now)  # si ya dura más de lo previsto, se despertará a partir de ahora
    else:
        anchor = max([n.end for n in closed], default=wake)

    # Solo cuentan las siestas terminadas: la que está en curso aún no tiene déficit
    deficit = sum(profile.nap_duration(n.index) - n.minutes for n in closed)
    return plan_day(wake, anchor, len(naps) + 1, deficit, profile, biases, now, cfg)


def _plan_without_recent_data(profile: SleepProfile, biases: Biases, now: datetime, tz: ZoneInfo, cfg: PredictionConfig):
    """Sin eventos recientes (no se registró el despertar, o falta la noche): se parte del
    despertar habitual de hoy, o de mañana si el día ya habría terminado."""
    today_midnight = local_midnight_utc(now.astimezone(tz).date(), tz)
    wake = clock_on_or_after(today_midnight - timedelta(minutes=1), profile.wake_clock, tz)
    if now > wake + timedelta(minutes=profile.day_minutes + cfg.bed_late_tolerance_min):
        wake = clock_on_or_after(now, profile.wake_clock, tz)
    schedule, bed = plan_day(wake, wake, 1, 0.0, profile, biases, now, cfg)
    next_wake = wake if wake > now else predict_wake(bed, profile, biases, tz, cfg)
    return schedule, next_wake
