from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from prediction.config import PredictionConfig
from prediction.models import SleepDay, SleepProfile
from prediction.stats import robust_estimate, weighted_median

# Valores típicos (minutos) según el nº de siestas: (despertar->1ª, entre siestas, última->dormir, duración siesta).
# Son solo el punto de partida: el perfil se desplaza hacia los datos reales del bebé.
PRIORS = {
    0: (0, 0, 720, 0),
    1: (270, 300, 330, 120),
    2: (150, 180, 210, 90),
    3: (120, 150, 150, 60),
    4: (90, 120, 120, 45),
    5: (60, 90, 90, 45),
}
PRIOR_DAY_MINUTES = 735      # 12h15 despierto
PRIOR_NIGHT_MINUTES = 660    # 11h de noche
PRIOR_WAKE_CLOCK = 7 * 60 + 30

# Rangos plausibles (minutos): lo que cae fuera es un error de registro
WW_RANGE = (15, 480)
NAP_RANGE = (10, 300)
DAY_RANGE = (360, 960)
NIGHT_RANGE = (240, 960)


def naps_for_age(age_days: int) -> tuple[int, int, int]:
    """(típicas, mínimo, máximo) siestas para la edad. El nº real se aprende dentro del rango."""
    months = age_days / 30.44
    if months < 4:
        typical = 5
    elif months < 6:
        typical = 4
    elif months < 9:
        typical = 3
    elif months < 14:
        typical = 2
    elif months < 36:
        typical = 1
    else:
        typical = 0
    return typical, max(typical - 1, 0), min(typical + 1, 5)


def _minutes(a: datetime, b: datetime) -> float:
    return (b - a).total_seconds() / 60


def _in(value: float, bounds: tuple[float, float]) -> bool:
    return bounds[0] < value < bounds[1]


def learn_nap_count(days: list[SleepDay], age_days: int, now: datetime, cfg: PredictionConfig) -> int:
    typical, low, high = naps_for_age(age_days)
    horizon = timedelta(days=cfg.nap_count_days)
    complete = [d for d in days if d.complete and now - d.wake <= horizon]
    if len(complete) < cfg.min_complete_days:
        return typical
    counts = [len(d.naps) for d in complete]
    weights = [0.5 ** (_minutes(d.wake, now) / 1440 / cfg.half_life_days) for d in complete]
    return int(min(max(weighted_median(counts, weights), low), high))


def learn_profile(days: list[SleepDay], dob: date, now: datetime, tz: ZoneInfo, cfg: PredictionConfig) -> SleepProfile:
    age_days = (now.astimezone(tz).date() - dob).days
    nap_count = learn_nap_count(days, age_days, now, cfg)
    p_first, p_mid, p_evening, p_nap = PRIORS[min(nap_count, 5)]

    # Las ventanas dependen mucho del nº de siestas: en plena transición (3 -> 2) se
    # aprende solo de los días con el nº actual, si hay suficientes.
    matching = [d for d in days if d.complete and len(d.naps) == nap_count]
    source = matching if len(matching) >= cfg.min_complete_days else days

    def age(ts: datetime) -> float:
        return _minutes(ts, now) / 1440

    ww_first, ww_mid, ww_evening, naps_by_idx, all_naps = [], [], [], {}, []
    for d in source:
        for i, nap in enumerate(d.naps):
            prev_end = d.wake if i == 0 else d.naps[i - 1].end
            if prev_end is not None:
                ww = _minutes(prev_end, nap.start)
                if _in(ww, WW_RANGE):
                    (ww_first if i == 0 else ww_mid).append((ww, age(nap.start)))
            if nap.minutes is not None and _in(nap.minutes, NAP_RANGE):
                naps_by_idx.setdefault(nap.index, []).append((nap.minutes, age(nap.start)))
                all_naps.append((nap.minutes, age(nap.start)))
        if d.bed is not None:
            last_end = d.naps[-1].end if d.naps else d.wake
            if last_end is not None:
                ww = _minutes(last_end, d.bed)
                if _in(ww, (WW_RANGE[0], DAY_RANGE[1])):
                    ww_evening.append((ww, age(d.bed)))

    day_len, nights, wake_clocks = [], [], []
    for i, d in enumerate(days):
        if d.wake is not None and d.bed is not None and _in(_minutes(d.wake, d.bed), DAY_RANGE):
            day_len.append((_minutes(d.wake, d.bed), age(d.bed)))
        if d.wake is not None:
            local = d.wake.astimezone(tz)
            wake_clocks.append((local.hour * 60 + local.minute, age(d.wake)))
        if d.bed is not None and i + 1 < len(days) and days[i + 1].wake is not None:
            night = _minutes(d.bed, days[i + 1].wake)
            if _in(night, NIGHT_RANGE):
                nights.append((night, age(days[i + 1].wake)))

    def est(samples, prior, strength=cfg.prior_strength):
        return robust_estimate(samples, prior, strength, cfg.half_life_days, cfg.outlier_mads)

    first, n_first = est(ww_first, p_first)
    mid, n_mid = est(ww_mid, p_mid)
    evening, n_evening = est(ww_evening, p_evening)
    pooled_nap, n_naps = est(all_naps, p_nap or 30)
    # Cada siesta (1ª, 2ª...) dura distinto; con pocas muestras se tira hacia la media de todas
    nap_minutes = tuple(
        est(naps_by_idx.get(idx, []), pooled_nap)[0] for idx in range(1, max(nap_count, 1) + 2)
    )
    deficit_slope, n_slope = learn_deficit_slope(source, nap_minutes, evening, cfg)
    day_minutes, n_day = est(day_len, PRIOR_DAY_MINUTES)
    night_minutes, n_night = est(nights, PRIOR_NIGHT_MINUTES)
    wake_clock, n_wake = est(wake_clocks, PRIOR_WAKE_CLOCK, cfg.clock_prior_strength)

    return SleepProfile(
        nap_count=nap_count,
        ww_first=first,
        ww_mid=mid,
        ww_evening=evening,
        nap_minutes=nap_minutes,
        day_minutes=day_minutes,
        night_minutes=night_minutes,
        wake_clock=wake_clock,
        samples={
            "ww_first": n_first, "ww_mid": n_mid, "ww_evening": n_evening, "naps": n_naps,
            "day": n_day, "night": n_night, "wake_clock": n_wake, "deficit_slope": n_slope,
        },
        deficit_slope=deficit_slope,
    )


def learn_deficit_slope(
    days: list[SleepDay], nap_minutes: tuple[float, ...], evening: float, cfg: PredictionConfig
) -> tuple[float, int]:
    """Regresión (por el origen) de "ventana de tarde - habitual" frente al déficit de siesta
    del día. Pendiente acotada a [0, max] y encogida hacia 0 con pocos días informativos."""
    def nap_duration(index: int) -> float:
        return nap_minutes[min(max(index, 1), len(nap_minutes)) - 1]

    xs, ys = [], []
    for d in days:
        if not (d.complete and d.naps):
            continue
        deficit = sum(nap_duration(n.index) - n.minutes for n in d.naps)
        evening_window = _minutes(d.naps[-1].end, d.bed)
        if abs(deficit) >= 10 and _in(evening_window, WW_RANGE):
            xs.append(deficit)
            ys.append(evening_window - evening)
    n = len(xs)
    if n < cfg.min_deficit_days:
        return 0.0, n
    slope = -sum(x * y for x, y in zip(xs, ys)) / sum(x * x for x in xs)
    slope = min(max(slope, 0.0), cfg.max_deficit_slope)
    return slope * n / (n + cfg.deficit_prior_days), n
