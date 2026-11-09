from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import local_midnight_utc
from prediction.config import DEFAULT_CONFIG, PredictionConfig
from prediction.feedback import compute_biases
from prediction.models import Biases, PredictionOutput, SleepDay, SleepEvent, SleepProfile, Sufficiency
from prediction.profile import is_weekend, learn_profile
from prediction.schedule import clock_on_or_after, plan_day, predict_wake, wake_basis, wake_item
from prediction.segmentation import current_state, parse_events, segment_days


def check_sufficiency(events: list[SleepEvent], tz: ZoneInfo, cfg: PredictionConfig) -> Sufficiency | None:
    if len(events) < cfg.min_sleep_events:
        return Sufficiency("insufficient_events", cfg.min_sleep_events, len(events))
    days = len({e.start.astimezone(tz).date() for e in events})
    if days < cfg.min_days:
        return Sufficiency("insufficient_days", cfg.min_days, days)
    return None


def _morning_after(bed: datetime, tz: ZoneInfo) -> date:
    """Fecha de la mañana siguiente a acostarse (si se acuesta de madrugada, ese mismo día)."""
    return (bed + timedelta(hours=10)).astimezone(tz).date()


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
    biases = compute_biases(events, cfg)

    # Perfil del tipo de día que se predice (entre semana / fin de semana), aprendido una vez por tipo
    cache: dict[bool, SleepProfile] = {}

    def profile_for(day: date) -> SleepProfile:
        key = is_weekend(day)
        if key not in cache:
            cache[key] = learn_profile(history, dob, now, tz, cfg, target_day=day)
        return cache[key]

    if state.kind == "day":
        profile = profile_for(state.day.anchor.astimezone(tz).date())
        schedule, bed, bed_var = _plan_open_day(state.day, profile, biases, now, tz, cfg)
        wake_profile = profile_for(_morning_after(bed, tz))
        wake, wake_var = predict_wake(bed, wake_profile, biases, tz, cfg, bed_var)
        basis = wake_basis(bed, True, wake_profile, biases, tz)
    elif state.kind == "night":
        # De noche, la agenda que interesa es la de mañana, partiendo del despertar previsto
        profile = profile_for(_morning_after(state.bed, tz))
        wake, wake_var = predict_wake(state.bed, profile, biases, tz, cfg)
        schedule, _, _ = plan_day(wake, wake, 1, 0.0, profile, biases, now, tz, cfg, anchor_var=wake_var)
        basis = wake_basis(state.bed, False, profile, biases, tz)
    else:
        profile, schedule, wake, wake_var, basis = _plan_without_recent_data(profile_for, biases, now, tz, cfg)

    return PredictionOutput(
        schedule=schedule, wake=wake_item(wake, biases, wake_var, cfg, basis), state=state.kind, profile=profile,
    )


def _plan_open_day(day: SleepDay, profile: SleepProfile, biases: Biases, now: datetime, tz: ZoneInfo,
                   cfg: PredictionConfig):
    naps = day.naps
    wake = day.wake or (naps[0].start - timedelta(minutes=profile.ww_first))
    ongoing = naps[-1] if naps and naps[-1].end is None else None
    closed = [n for n in naps if n.end is not None]

    anchor_var = 0.0
    if ongoing is not None:
        expected_end = ongoing.start + timedelta(minutes=profile.nap_duration(ongoing.index) + biases.nap_duration)
        if now - ongoing.start > timedelta(hours=cfg.max_open_nap_hours):
            anchor = expected_end  # cronómetro olvidado: se supone que duró lo habitual
        else:
            anchor = max(expected_end, now)  # si ya dura más de lo previsto, se despertará a partir de ahora
        anchor_var = profile.sd("nap") ** 2 if anchor == expected_end else (profile.sd("nap") / 2) ** 2
    else:
        # Una siesta marcada como no hecha cuenta como terminada a su hora prevista: la
        # siguiente se cuenta desde ahí (no desde el despertar, que la pondría en el pasado)
        anchor = max([n.end for n in closed] + day.skipped, default=wake)
    anchor_skipped = ongoing is None and bool(day.skipped) and anchor in day.skipped

    # Solo cuentan las siestas terminadas: la que está en curso aún no tiene déficit.
    # Una siesta extra (de rescate) no se esperaba: suma sueño, no déficit.
    deficit = sum(profile.expected_nap(n.index) - n.minutes for n in closed)
    # Las marcadas como no hechas ocupan su turno (la siguiente prevista es la de después) y
    # su sueño esperado entero es déficit.
    skipped = len(day.skipped)
    deficit += sum(profile.expected_nap(len(naps) + k) for k in range(1, skipped + 1))
    return plan_day(wake, anchor, len(naps) + skipped + 1, deficit, profile, biases, now, tz, cfg,
                    anchor_var=anchor_var, anchor_skipped=anchor_skipped)


def _plan_without_recent_data(profile_for, biases: Biases, now: datetime, tz: ZoneInfo, cfg: PredictionConfig):
    """Sin eventos recientes (no se registró el despertar, o falta la noche): se parte del
    despertar habitual de hoy, o de mañana si el día ya habría terminado."""
    today = now.astimezone(tz).date()
    profile = profile_for(today)
    today_midnight = local_midnight_utc(today, tz)
    wake = clock_on_or_after(today_midnight - timedelta(minutes=1), profile.wake_clock, tz)
    if now > wake + timedelta(minutes=profile.day_minutes + cfg.bed_late_tolerance_min):
        profile = profile_for(today + timedelta(days=1))
        wake = clock_on_or_after(now, profile.wake_clock, tz)
    wake_var = profile.sd("wake_clock") ** 2
    schedule, bed, bed_var = plan_day(wake, wake, 1, 0.0, profile, biases, now, tz, cfg, anchor_var=wake_var)
    if wake > now:
        return profile, schedule, wake, wake_var, wake_basis(None, False, profile, biases, tz)
    wake_profile = profile_for(_morning_after(bed, tz))
    next_wake, next_var = predict_wake(bed, wake_profile, biases, tz, cfg, bed_var)
    return profile, schedule, next_wake, next_var, wake_basis(bed, True, wake_profile, biases, tz)
