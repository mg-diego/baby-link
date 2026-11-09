"""Aprende el perfil de sueño del bebé a partir de su historial.

Cada métrica parte de un valor típico por edad (o por nº de siestas) y se desplaza hacia
los datos del bebé. Nada de lo que depende de cada familia es fijo:
- ventanas (una por siesta), duraciones, nº de siestas, horas de despertar y dormir;
- cómo de "reloj" es el bebé: si se despierta a su hora o tras X horas de noche, y si se
  acuesta según la ventana, la duración del día o la hora de la rutina;
- si compensa las siestas cortas acostándose antes;
- si entre semana y el fin de semana hace horarios distintos (guardería);
- cuánto varía cada cosa (de ahí el margen de las predicciones).
"""
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from prediction.config import PredictionConfig
from prediction.models import SleepDay, SleepProfile
from prediction.rules import compensate, day_clock, wake_targets
from prediction.stats import (
    recency_weight, robust_estimate, shrunk_regression, shrunk_spread, split_by_group, weighted_median,
)

# Valores típicos (minutos) según el nº de siestas: (despertar->1ª, entre siestas, última->dormir, duración siesta).
# Son solo el punto de partida: el perfil se desplaza hacia los datos reales del bebé.
PRIORS = {
    0: (0, 0, 720, 0),
    1: (270, 300, 330, 120),
    2: (150, 180, 210, 90),
    3: (120, 150, 150, 60),
    4: (90, 120, 120, 45),
    5: (60, 90, 90, 45),
    6: (50, 60, 75, 35),
}
# (despierto, noche) según el nº de siestas; suman 24 h
PRIOR_DAY_NIGHT = {0: (810, 630), 1: (780, 660), 2: (750, 690), 3: (750, 690), 4: (780, 660), 5: (840, 600), 6: (840, 600)}
PRIOR_WAKE_CLOCK = 7 * 60 + 30
# Peso por defecto de "despertar + duración del día" en la hora de dormir: con muchas
# siestas manda la ventana; con pocas, el reloj. Es solo el punto de partida.
PRIOR_BED_DAY_WEIGHT = {0: 0.60, 1: 0.40, 2: 0.25, 3: 0.10}

# Rangos plausibles (minutos): lo que cae fuera es un error de registro
WW_RANGE = (15, 480)
NAP_RANGE = (10, 300)
DAY_RANGE = (360, 960)
NIGHT_RANGE = (240, 960)
BED_CLOCK_RANGE = (12 * 60, 30 * 60)   # de 12:00 a 6:00 del día siguiente
MAX_BLEND_GAP = 300                    # en las regresiones, días con diferencias mayores son raros


def naps_for_age(age_days: int, max_naps: int = 6) -> tuple[int, int, int]:
    """(típicas, mínimo, máximo) siestas para la edad: punto de partida y límite mientras
    hay pocos días. Con suficientes días se usa lo que haga el bebé."""
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
    return typical, max(typical - 1, 0), min(typical + 1, max_naps)


def half_life_for_age(age_days: int, cfg: PredictionConfig) -> float:
    """Los bebés pequeños cambian cada semana: se olvida antes lo de hace días."""
    months = age_days / 30.44
    if months <= cfg.young_months:
        return cfg.half_life_young_days
    if months >= cfg.adult_months:
        return cfg.half_life_days
    t = (months - cfg.young_months) / (cfg.adult_months - cfg.young_months)
    return cfg.half_life_young_days + t * (cfg.half_life_days - cfg.half_life_young_days)


def is_weekend(day: date) -> bool:
    return day.weekday() >= 5


def _minutes(a: datetime, b: datetime) -> float:
    return (b - a).total_seconds() / 60


def _in(value: float, bounds: tuple[float, float]) -> bool:
    return bounds[0] < value < bounds[1]


@dataclass(frozen=True)
class _Ctx:
    now: datetime
    tz: ZoneInfo
    cfg: PredictionConfig
    half_life: float

    def age(self, ts: datetime) -> float:
        return _minutes(ts, self.now) / 1440

    def weekend(self, d: SleepDay) -> bool:
        return is_weekend(d.anchor.astimezone(self.tz).date())


def learn_nap_count(days: list[SleepDay], age_days: int, ctx: _Ctx, default: int | None = None,
                    trusted: bool | None = None) -> int:
    cfg = ctx.cfg
    typical, low, high = naps_for_age(age_days, cfg.max_naps)
    horizon = timedelta(days=cfg.nap_count_days)
    complete = [d for d in days if d.complete and ctx.now - d.wake <= horizon]
    if len(complete) < cfg.min_complete_days:
        return typical if default is None else default
    if trusted if trusted is not None else len(complete) >= cfg.nap_count_trust_days:
        low, high = 0, cfg.max_naps  # hay datos de sobra: manda lo que haga el bebé, sea típico o no
    counts = [len(d.naps) for d in complete]
    weights = [recency_weight(ctx.age(d.wake), ctx.half_life) for d in complete]
    return int(min(max(weighted_median(counts, weights), low), high))


# ─── Observaciones ──────────────────────────────────────────────────────────────
# Cada una: (valor, antigüedad en días, ¿fin de semana?)

@dataclass
class _Obs:
    ww_first: list = field(default_factory=list)
    ww_idx: dict = field(default_factory=dict)        # índice de siesta (≥ 2) -> ventana previa
    ww_evening: list = field(default_factory=list)
    nap_idx: dict = field(default_factory=dict)
    day: list = field(default_factory=list)
    night: list = field(default_factory=list)
    wake_clock: list = field(default_factory=list)
    bed_clock: list = field(default_factory=list)

    @property
    def ww_mid(self) -> list:
        return [o for idx in sorted(self.ww_idx) for o in self.ww_idx[idx]]

    @property
    def naps(self) -> list:
        return [o for idx in sorted(self.nap_idx) for o in self.nap_idx[idx]]


def _observe(days: list[SleepDay], source: list[SleepDay], ctx: _Ctx) -> _Obs:
    obs = _Obs()
    for d in source:
        wk = ctx.weekend(d)
        for i, nap in enumerate(d.naps):
            prev_end = d.wake if i == 0 else d.naps[i - 1].end
            if prev_end is not None:
                ww = _minutes(prev_end, nap.start)
                if _in(ww, WW_RANGE):
                    target = obs.ww_first if i == 0 else obs.ww_idx.setdefault(nap.index, [])
                    target.append((ww, ctx.age(nap.start), wk))
            if nap.minutes is not None and _in(nap.minutes, NAP_RANGE):
                obs.nap_idx.setdefault(nap.index, []).append((nap.minutes, ctx.age(nap.start), wk))
        if d.bed is not None:
            last_end = d.naps[-1].end if d.naps else d.wake
            if last_end is not None:
                ww = _minutes(last_end, d.bed)
                if _in(ww, (WW_RANGE[0], DAY_RANGE[1])):
                    obs.ww_evening.append((ww, ctx.age(d.bed), wk))

    for i, d in enumerate(days):
        wk = ctx.weekend(d)
        if d.wake is not None and d.bed is not None and _in(_minutes(d.wake, d.bed), DAY_RANGE):
            obs.day.append((_minutes(d.wake, d.bed), ctx.age(d.bed), wk))
        if d.wake is not None:
            local = d.wake.astimezone(ctx.tz)
            obs.wake_clock.append((local.hour * 60 + local.minute, ctx.age(d.wake), wk))
        if d.bed is not None and d.anchor is not None:
            bed_clock = _minutes(day_clock(d.anchor, 0, ctx.tz), d.bed)
            if _in(bed_clock, BED_CLOCK_RANGE):
                obs.bed_clock.append((bed_clock, ctx.age(d.bed), wk))
        if d.bed is not None and i + 1 < len(days) and days[i + 1].wake is not None:
            night = _minutes(d.bed, days[i + 1].wake)
            if _in(night, NIGHT_RANGE):
                obs.night.append((night, ctx.age(days[i + 1].wake), ctx.weekend(days[i + 1])))
    return obs


def _xy(samples: list) -> list[tuple[float, float]]:
    return [(v, a) for v, a, _ in samples]


# ─── Valores (por métrica) ─────────────────────────────────────────────────────

SCALARS = ("ww_first", "ww_mid", "ww_evening", "day", "night", "wake_clock", "bed_clock")


def _estimate(obs: _Obs, nap_count: int, ctx: _Ctx) -> tuple[dict, dict]:
    """Valores comunes a todos los días, partiendo de los típicos para su nº de siestas."""
    cfg = ctx.cfg
    p_first, p_mid, p_evening, p_nap = PRIORS[min(nap_count, max(PRIORS))]
    p_day, p_night = PRIOR_DAY_NIGHT[min(nap_count, max(PRIOR_DAY_NIGHT))]

    def est(samples, prior, strength=cfg.prior_strength):
        return robust_estimate(_xy(samples), prior, strength, ctx.half_life, cfg.outlier_mads)

    v, n = {}, {}
    v["ww_first"], n["ww_first"] = est(obs.ww_first, p_first)
    v["ww_mid"], n["ww_mid"] = est(obs.ww_mid, p_mid)
    v["ww_evening"], n["ww_evening"] = est(obs.ww_evening, p_evening)
    v["day"], n["day"] = est(obs.day, p_day)
    v["night"], n["night"] = est(obs.night, p_night)
    v["wake_clock"], n["wake_clock"] = est(obs.wake_clock, PRIOR_WAKE_CLOCK, cfg.clock_prior_strength)
    v["bed_clock"], n["bed_clock"] = est(obs.bed_clock, PRIOR_WAKE_CLOCK + p_day, cfg.clock_prior_strength)
    pooled_nap, n["naps"] = est(obs.naps, p_nap or 30)
    # Cada ventana y cada siesta (1ª, 2ª...) es distinta; con pocas muestras se tira hacia el conjunto
    v["ww_idx"] = {idx: est(obs.ww_idx.get(idx, []), v["ww_mid"])[0] for idx in range(2, nap_count + 1)}
    v["nap_idx"] = {idx: est(obs.nap_idx.get(idx, []), pooled_nap)[0] for idx in range(1, max(nap_count, 1) + 2)}
    return v, n


def _specialize(base: dict, obs: _Obs, weekend: bool, ctx: _Ctx) -> dict:
    """Valores para entre semana o para el fin de semana: cada métrica se separa de la
    común solo si la diferencia entre ambos grupos de días supera el ruido."""
    cfg = ctx.cfg

    def split(samples, value):
        group = [(v, a) for v, a, w in samples if w == weekend]
        other = [(v, a) for v, a, w in samples if w != weekend]
        return split_by_group(value, group, other, ctx.half_life, cfg.outlier_mads, cfg.day_type_strictness)

    out = dict(base)
    for name in SCALARS:
        out[name] = split(getattr(obs, name) if name != "ww_mid" else obs.ww_mid, base[name])
    out["ww_idx"] = {i: split(obs.ww_idx.get(i, []), x) for i, x in base["ww_idx"].items()}
    out["nap_idx"] = {i: split(obs.nap_idx.get(i, []), x) for i, x in base["nap_idx"].items()}
    return out


def _expected_nap(values: dict, nap_count: int, index: int) -> float:
    if index > nap_count:
        return 0.0  # siesta extra (de rescate): no se esperaba, así que no hay déficit
    naps = values["nap_idx"]
    return naps.get(index, naps[max(naps)])


# ─── Pesos aprendidos ───────────────────────────────────────────────────────────

def learn_deficit_slope(days: list[SleepDay], values_for, nap_count: int, cfg: PredictionConfig) -> tuple[float, int]:
    """Regresión (por el origen) de "ventana de tarde - habitual" frente al déficit de siesta
    del día. Pendiente acotada a [0, max] y encogida hacia 0 con pocos días informativos."""
    xs, ys = [], []
    for d in days:
        if not (d.complete and d.naps):
            continue
        v = values_for(d)
        deficit = sum(_expected_nap(v, nap_count, n.index) - n.minutes for n in d.naps)
        evening_window = _minutes(d.naps[-1].end, d.bed)
        if abs(deficit) >= 10 and _in(evening_window, WW_RANGE):
            xs.append(deficit)
            ys.append(evening_window - v["ww_evening"])
    n = len(xs)
    if n < cfg.min_deficit_days:
        return 0.0, n
    slope = -sum(x * y for x, y in zip(xs, ys)) / sum(x * x for x in xs)
    slope = min(max(slope, 0.0), cfg.max_deficit_slope)
    return slope * n / (n + cfg.deficit_prior_days), n


def _learn_bed_weights(days, values_for, nap_count, slope, ctx: _Ctx) -> tuple[list[float], int, float]:
    """Hora de dormir = ventana + a·(despertar + duración del día − ventana) + b·(hora
    habitual − ventana). Devuelve ([a, b], nº de días, dispersión del residuo)."""
    cfg = ctx.cfg
    xs, ys = [], []
    for d in days:
        if not d.complete:
            continue
        v = values_for(d)
        last_end = d.naps[-1].end if d.naps else d.wake
        deficit = sum(_expected_nap(v, nap_count, n.index) - n.minutes for n in d.naps)
        pure = last_end + timedelta(minutes=compensate(v["ww_evening"], deficit, slope, cfg))
        x_day = _minutes(pure, d.wake + timedelta(minutes=v["day"]))
        x_clock = _minutes(pure, day_clock(d.wake, v["bed_clock"], ctx.tz))
        y = _minutes(pure, d.bed)
        if max(abs(x_day), abs(x_clock), abs(y)) <= MAX_BLEND_GAP:
            xs.append((x_day, x_clock))
            ys.append(y)
    prior = [PRIOR_BED_DAY_WEIGHT.get(nap_count, 0.0), 0.0]
    coef, n = shrunk_regression(xs, ys, prior, cfg.blend_prior_days, cfg.outlier_mads, cfg.min_blend_days)
    residuals = [y - coef[0] * x[0] - coef[1] * x[1] for x, y in zip(xs, ys)]
    return coef, n, shrunk_spread(residuals, cfg.spread_prior_min, cfg.spread_prior_strength)


def _learn_wake_weight(days, values_for, ctx: _Ctx) -> tuple[float, int, float]:
    """Despertar = hora habitual + s·(acostarse + duración de la noche − hora habitual)."""
    cfg = ctx.cfg
    xs, ys = [], []
    for i, d in enumerate(days[:-1]):
        nxt = days[i + 1]
        if d.bed is None or nxt.wake is None:
            continue
        v = values_for(nxt)
        target, by_duration = wake_targets(d.bed, v["wake_clock"], v["night"], ctx.tz)
        x, y = _minutes(target, by_duration), _minutes(target, nxt.wake)
        if max(abs(x), abs(y)) <= MAX_BLEND_GAP:
            xs.append((x,))
            ys.append(y)
    coef, n = shrunk_regression(xs, ys, [cfg.wake_duration_prior], cfg.blend_prior_days,
                                cfg.outlier_mads, cfg.min_blend_days)
    residuals = [y - coef[0] * x[0] for x, y in zip(xs, ys)]
    return coef[0], n, shrunk_spread(residuals, cfg.spread_prior_min, cfg.spread_prior_strength)


def _spreads(obs: _Obs, values_for_flag, cfg: PredictionConfig) -> dict:
    """Dispersión de cada métrica respecto a su valor (del tipo de día de cada muestra)."""
    def spread(samples, key, idx=None):
        res = []
        for value, _, wk in samples:
            ref = values_for_flag(wk)[key]
            if idx is not None:
                ref = ref.get(idx) if isinstance(ref, dict) else ref
            if ref is not None:
                res.append(value - ref)
        return res

    mid = [r for idx, s in obs.ww_idx.items() for r in spread(s, "ww_idx", idx)]
    naps = [r for idx, s in obs.nap_idx.items() for r in spread(s, "nap_idx", idx)]
    raw = {
        "ww_first": spread(obs.ww_first, "ww_first"),
        "ww_mid": mid,
        "ww_evening": spread(obs.ww_evening, "ww_evening"),
        "nap": naps,
        "wake_clock": spread(obs.wake_clock, "wake_clock"),
        "night": spread(obs.night, "night"),
    }
    return {k: shrunk_spread(r, cfg.spread_prior_min, cfg.spread_prior_strength) for k, r in raw.items()}


def learn_profile(days: list[SleepDay], dob: date, now: datetime, tz: ZoneInfo, cfg: PredictionConfig,
                  target_day: date | None = None) -> SleepProfile:
    """Perfil del bebé. Con `target_day`, el de ese tipo de día (entre semana / fin de semana)."""
    age_days = (now.astimezone(tz).date() - dob).days
    ctx = _Ctx(now, tz, cfg, half_life_for_age(age_days, cfg))
    split = cfg.day_type_split and target_day is not None
    weekend = is_weekend(target_day) if split else None

    nap_count = learn_nap_count(days, age_days, ctx)
    if split and cfg.day_type_nap_count:
        horizon = timedelta(days=cfg.nap_count_days)
        trusted = sum(1 for d in days if d.complete and now - d.wake <= horizon) >= cfg.nap_count_trust_days
        same_type = [d for d in days if d.anchor and ctx.weekend(d) == weekend]
        nap_count = learn_nap_count(same_type, age_days, ctx, default=nap_count, trusted=trusted)

    # Las ventanas dependen mucho del nº de siestas: en plena transición (3 -> 2) se
    # aprende solo de los días con el nº actual, si hay suficientes.
    matching = [d for d in days if d.complete and len(d.naps) == nap_count]
    source = matching if len(matching) >= cfg.min_complete_days else days

    obs = _observe(days, source, ctx)
    base, samples = _estimate(obs, nap_count, ctx)
    if cfg.day_type_split:
        by_type = {flag: _specialize(base, obs, flag, ctx) for flag in (False, True)}
    else:
        by_type = {False: base, True: base}

    def values_for(d: SleepDay) -> dict:
        return by_type[ctx.weekend(d)]

    deficit_slope, samples["deficit_slope"] = learn_deficit_slope(source, values_for, nap_count, cfg)
    (bed_day, bed_clock_w), samples["bed_weights"], bed_sd = _learn_bed_weights(
        source, values_for, nap_count, deficit_slope, ctx)
    wake_w, samples["wake_weight"], wake_sd = _learn_wake_weight(days, values_for, ctx)
    spread = _spreads(obs, lambda flag: by_type[flag], cfg)
    spread.update(bed=bed_sd, wake=wake_sd)

    v = by_type[weekend] if split else base
    ww_idx = tuple(v["ww_idx"][i] for i in sorted(v["ww_idx"]))
    nap_minutes = tuple(v["nap_idx"][i] for i in sorted(v["nap_idx"]))
    return SleepProfile(
        nap_count=nap_count,
        ww_first=v["ww_first"],
        ww_mid=v["ww_mid"],
        ww_evening=v["ww_evening"],
        nap_minutes=nap_minutes,
        day_minutes=v["day"],
        night_minutes=v["night"],
        wake_clock=v["wake_clock"],
        samples=samples,
        deficit_slope=deficit_slope,
        ww_by_index=ww_idx,
        bed_clock=v["bed_clock"],
        bed_day_weight=bed_day,
        bed_clock_weight=bed_clock_w,
        wake_duration_weight=wake_w,
        spread=spread,
        weekend=weekend,
        days_learned=sum(1 for d in days if d.anchor),
    )
