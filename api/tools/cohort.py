"""Backtest sobre un grupo de bebés sintéticos con patrones muy distintos.

Un motor ajustado con un solo bebé aprende sus manías. Este grupo cubre los patrones que
cambian entre familias: edades y nº de siestas, ventanas que crecen a lo largo del día,
despertar por reloj o por duración de la noche, rutina de dormir a hora fija, guardería
entre semana, transición de 3 a 2 siestas, desarrollo rápido, horarios tardíos, días
desordenados y registros olvidados. Todo es 100 % sintético (nunca datos reales).

Uso (desde api/):
    python -m tools.cohort                       # informe del motor frente a "como ayer"
    python -m tools.cohort --save antes.json     # guarda el resultado
    python -m tools.cohort --compare antes.json  # muestra la diferencia con uno guardado
"""
import argparse
import json
import random
import statistics
from dataclasses import dataclass, fields, replace
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from core.timeutils import local_midnight_utc, to_iso_z
from prediction import DEFAULT_CONFIG, PredictionConfig
from tools.backtest import Metrics, collect, engine_predictor, print_report, yesterday_predictor

MADRID = ZoneInfo("Europe/Madrid")
FIRST_DAY = date(2026, 3, 2)  # lunes; el periodo cruza el cambio de hora del 29-mar


@dataclass(frozen=True)
class Routine:
    wake_clock: float               # minutos desde medianoche local
    windows: tuple[float, ...]      # ventana de vigilia antes de cada siesta
    naps: tuple[float, ...]         # duración de cada siesta
    evening: float                  # última siesta -> dormir


@dataclass(frozen=True)
class BabySpec:
    name: str
    age_months: float
    home: Routine
    daycare: Routine | None = None        # de lunes a viernes (despertador, horario de la guarde)
    wake_duration_weight: float = 0.0     # 0: despierta a su hora; 1: tras X horas de noche
    night: float = 660.0                  # con peso > 0, día + noche deben sumar ~24 h o el reloj deriva
    bed_clock: float | None = None        # rutina de dormir a hora fija...
    bed_clock_weight: float = 0.0         # ...y cuánto manda frente a la ventana
    deficit_slope: float = 0.0            # minutos que se adelanta la noche por minuto de siesta perdido
    noise: float = 15.0                   # desviación típica de ventanas y siestas (minutos)
    drift_per_week: float = 0.0           # las ventanas crecen tantos minutos por semana
    transition: tuple[int, Routine] | None = None  # (día, rutina nueva)
    missing: float = 0.0                  # probabilidad de olvidar registrar un evento
    days: int = 42


def _clock(hour: int, minute: int = 0) -> float:
    return hour * 60 + minute


COHORT: tuple[BabySpec, ...] = (
    BabySpec("regular_2naps_10m", 10, Routine(_clock(7), (150, 180), (90, 90), 210), noise=12),
    BabySpec("progressive_3naps_7m", 7, Routine(_clock(6, 45), (105, 135, 170), (60, 80, 35), 180)),
    BabySpec("newborn_5naps_2m", 2.2, Routine(_clock(7, 30), (55, 65, 70, 75, 80), (40, 70, 50, 40, 30), 120),
             wake_duration_weight=0.5, night=745, drift_per_week=4),
    BabySpec("young_3naps_3m", 3.3, Routine(_clock(7), (90, 105, 120), (75, 90, 50), 120), drift_per_week=3),
    BabySpec("duration_waker_12m", 12, Routine(_clock(7), (180, 210), (75, 75), 240),
             wake_duration_weight=0.75, night=660, noise=25),
    BabySpec("routine_bed_9m", 9, Routine(_clock(7), (150, 180), (75, 75), 210),
             bed_clock=_clock(20, 30), bed_clock_weight=0.85, noise=20),
    BabySpec("daycare_13m", 13, Routine(_clock(8), (180, 210), (90, 80), 240),
             daycare=Routine(_clock(6, 45), (165, 195), (60, 60), 240), wake_duration_weight=0.4),
    BabySpec("daycare_1nap_15m", 15, Routine(_clock(7, 45), (180, 210), (75, 45), 240),
             daycare=Routine(_clock(6, 45), (300,), (120,), 285)),
    BabySpec("toddler_1nap_20m", 20, Routine(_clock(7, 15), (300,), (120,), 330), noise=20),
    BabySpec("transition_3to2_8m", 8, Routine(_clock(7), (120, 150, 165), (60, 70, 35), 165),
             transition=(18, Routine(_clock(7), (165, 195), (85, 85), 210))),
    BabySpec("late_spanish_11m", 11, Routine(_clock(8, 30), (180, 210), (80, 70), 240), noise=20),
    BabySpec("messy_logger_10m", 10, Routine(_clock(7), (150, 180), (85, 85), 210), noise=30, missing=0.08),
    BabySpec("deficit_comp_10m", 10, Routine(_clock(7), (150, 180), (90, 90), 210), deficit_slope=0.7, noise=25),
    BabySpec("no_naps_40m", 40, Routine(_clock(7, 30), (), (), 750), noise=20),
)


def simulate(spec: BabySpec, seed: int = 0, first_day: date = FIRST_DAY, tz: ZoneInfo = MADRID) -> tuple[list[dict], date]:
    rng = random.Random(f"{spec.name}:{seed}")

    def g(sigma: float) -> float:
        return rng.gauss(0, sigma)

    def mins(m: float) -> timedelta:
        return timedelta(minutes=m)

    def ev(category: str, start: datetime, end: datetime | None = None) -> dict:
        return {"category": category, "start_time": to_iso_z(start), "end_time": to_iso_z(end) if end else None,
                "metadata": {}}

    dob = first_day - timedelta(days=round(spec.age_months * 30.44))
    rows: list[dict] = []
    prev_bed: datetime | None = None
    for i in range(spec.days):
        day = first_day + timedelta(days=i)
        routine = spec.home
        if spec.transition and i >= spec.transition[0]:
            routine = spec.transition[1]
        at_daycare = spec.daycare is not None and day.weekday() < 5
        if at_daycare:
            routine = spec.daycare
        drift = spec.drift_per_week * i / 7
        midnight = local_midnight_utc(day, tz)

        wake = midnight + mins(routine.wake_clock + g(5 if at_daycare else 12))
        if prev_bed is not None and not at_daycare and spec.wake_duration_weight:
            by_duration = prev_bed + mins(spec.night + g(15))
            wake += (by_duration - wake) * spec.wake_duration_weight
        day_rows = [ev("woke_up", wake)]

        cursor, deficit = wake, 0.0
        for ww, length in zip(routine.windows, routine.naps):
            start = cursor + mins(max(ww + drift + g(spec.noise), 20))
            minutes = max(length + g(spec.noise), 15)
            deficit += length - minutes
            day_rows.append(ev("nap", start, start + mins(minutes)))
            cursor = start + mins(minutes)

        evening = routine.evening + drift - spec.deficit_slope * deficit + g(spec.noise)
        bed = cursor + mins(max(evening, 30))
        if spec.bed_clock is not None:
            bed += (midnight + mins(spec.bed_clock + g(10)) - bed) * spec.bed_clock_weight
        day_rows.append(ev("bed_time", bed))
        prev_bed = bed

        if spec.missing and i >= 3:
            day_rows = [r for r in day_rows if rng.random() >= spec.missing]
        rows += day_rows
    return rows, dob


def evaluate(specs=COHORT, seeds=(0,), cfg: PredictionConfig = DEFAULT_CONFIG, tz: ZoneInfo = MADRID,
             with_baseline: bool = True) -> dict:
    """Resultados por métrica (todo el grupo junto) y por bebé, del motor y de la referencia."""
    predictors = {"engine": engine_predictor(tz, cfg)}
    if with_baseline:
        predictors["baseline"] = yesterday_predictor(tz, cfg)
    result: dict = {name: {"metrics": Metrics(), "babies": {}} for name in predictors}
    for spec in specs:
        for seed in seeds:
            rows, dob = simulate(spec, seed, tz=tz)
            for name, predictor in predictors.items():
                m = collect(rows, dob, predictor, tz, warmup_days=cfg.min_days, cfg=cfg)
                result[name]["metrics"].extend(m)
                result[name]["babies"].setdefault(spec.name, Metrics()).extend(m)
    out = {}
    for name, r in result.items():
        out[name] = {
            "metrics": r["metrics"].summary(),
            "phases": r["metrics"].summary(by_phase=True),
            "babies": {b: _baby_score(m) for b, m in r["babies"].items()},
            "score": _score(r["metrics"]),
        }
    return out


def _score(m: Metrics) -> float:
    """Una sola cifra: media de los MAE de cada métrica (todas pesan igual)."""
    s = m.summary()
    return round(statistics.fmean(v["mae"] for v in s.values()), 1) if s else float("nan")


def _baby_score(m: Metrics) -> dict:
    return {"score": _score(m), **{k: v["mae"] for k, v in m.summary().items()}}


def print_cohort(res: dict, compare: dict | None = None) -> None:
    eng = res["engine"]
    print_report("Motor: todo el grupo", eng["metrics"])
    print_report("Motor: por fase (cold = primera semana)", eng["phases"])
    if "baseline" in res:
        print_report("Referencia 'como ayer'", res["baseline"]["metrics"])

    print(f"\n  {'bebé':<26}{'motor':>8}{'como ayer':>11}" + (f"{'antes':>8}{'Δ':>7}" if compare else ""))
    for baby, s in eng["babies"].items():
        base = res.get("baseline", {}).get("babies", {}).get(baby, {}).get("score", "")
        line = f"  {baby:<26}{s['score']:>8}{base:>11}"
        if compare and baby in compare["engine"]["babies"]:
            before = compare["engine"]["babies"][baby]["score"]
            line += f"{before:>8}{s['score'] - before:>+7.1f}"
        print(line)
    total = f"\n  {'PUNTUACIÓN (MAE medio)':<26}{eng['score']:>8}{res.get('baseline', {}).get('score', ''):>11}"
    if compare:
        total += f"{compare['engine']['score']:>8}{eng['score'] - compare['engine']['score']:>+7.1f}"
    print(total)
    if compare:
        print("\n  Δ MAE por métrica (negativo = mejor):")
        for name, m in eng["metrics"].items():
            before = compare["engine"]["metrics"].get(name)
            if before:
                print(f"    {name:<28}{before['mae']:>7} -> {m['mae']:<7}({m['mae'] - before['mae']:+.1f})")


def _config(overrides: list[str]) -> PredictionConfig:
    types = {f.name: f.type for f in fields(PredictionConfig)}
    changes = {}
    for item in overrides:
        key, _, value = item.partition("=")
        if key not in types:
            raise SystemExit(f"Parámetro desconocido: {key}")
        kind = types[key] if isinstance(types[key], type) else eval(types[key])  # anotaciones como texto
        changes[key] = value.lower() in ("1", "true", "sí", "si") if kind is bool else kind(value)
    return replace(DEFAULT_CONFIG, **changes)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seeds", type=int, default=2, help="historiales distintos por bebé")
    parser.add_argument("--only", help="nombre (o parte) de los bebés a evaluar")
    parser.add_argument("--set", action="append", default=[], metavar="CLAVE=VALOR",
                        help="cambia un parámetro de PredictionConfig (se puede repetir)")
    parser.add_argument("--save")
    parser.add_argument("--compare")
    args = parser.parse_args()

    specs = [s for s in COHORT if not args.only or args.only in s.name]
    res = evaluate(specs, seeds=tuple(range(args.seeds)), cfg=_config(args.set))
    compare = None
    if args.compare:
        with open(args.compare, encoding="utf-8") as fh:
            compare = json.load(fh)
    print_cohort(res, compare)
    if args.save:
        with open(args.save, "w", encoding="utf-8") as fh:
            json.dump(res, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
