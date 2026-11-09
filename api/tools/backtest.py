"""Backtesting del motor de predicciones sobre un historial real o sintético.

Para cada día del historial se "viaja en el tiempo" a varios momentos (al despertar, al
terminar cada siesta y al acostarse), se predice usando solo los eventos anteriores y se
compara con lo que pasó de verdad. Sirve para ajustar `PredictionConfig` con datos.

Cada error se etiqueta con la fase en la que se predijo: `cold` (primera semana de
historial, lo que vive un usuario nuevo) o `warm`. Si la predicción trae `start_range`,
también se mide qué fracción de las veces la realidad cayó dentro (cobertura).

Uso (desde api/):
    python -m tools.backtest --baby-id <uuid>              # lee de Supabase (solo lectura)
    python -m tools.backtest --json eventos.json --dob 2025-08-15
    python -m tools.cohort                                  # grupo de bebés sintéticos
"""
import argparse
import json
import statistics
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Callable
from zoneinfo import ZoneInfo

from core.timeutils import UTC, parse_ts, to_iso_z
from prediction import DEFAULT_CONFIG, PredictionConfig, predict
from prediction.models import SLEEP_CATEGORIES
from prediction.segmentation import current_state, parse_events, segment_days

# (filas anteriores al instante, dob, instante) -> (agenda, despertar previsto o None)
Predictor = Callable[[list[dict], date, datetime], tuple[list[dict], dict | None]]

COLD_DAYS = 7  # con menos días de historial que esto, la predicción cuenta como arranque en frío


@dataclass
class Record:
    metric: str
    phase: str
    error: float               # minutos; >0: la realidad llega más tarde que lo predicho
    hit: bool | None = None    # la realidad cayó dentro de `start_range`


@dataclass
class Metrics:
    records: list[Record] = field(default_factory=list)

    def add(self, name: str, item: dict | None, actual: datetime | None, phase: str = "warm"):
        if item is None or actual is None:
            return
        hit = None
        rng = item.get("start_range")
        if rng:
            hit = parse_ts(rng["earliest"]) <= actual <= parse_ts(rng["latest"])
        error = (actual - parse_ts(item["start"])).total_seconds() / 60
        self.records.append(Record(name, phase, error, hit))

    def add_error(self, name: str, error: float, phase: str = "warm"):
        self.records.append(Record(name, phase, error))

    def extend(self, other: "Metrics"):
        self.records += other.records

    def summary(self, by_phase: bool = False) -> dict[str, dict]:
        groups: dict[str, list[Record]] = {}
        for r in self.records:
            groups.setdefault(f"{r.metric}/{r.phase}" if by_phase else r.metric, []).append(r)
        return {name: summarize(recs) for name, recs in sorted(groups.items())}


def summarize(records: list[Record]) -> dict:
    errs = [r.error for r in records]
    abs_errs = sorted(abs(e) for e in errs)
    hits = [r.hit for r in records if r.hit is not None]
    return {
        "n": len(errs),
        "mae": round(statistics.fmean(abs_errs), 1),
        "median_abs": round(statistics.median(abs_errs), 1),
        "p90_abs": round(abs_errs[int(0.9 * (len(abs_errs) - 1))], 1),
        "bias": round(statistics.fmean(errs), 1),
        "coverage": round(sum(hits) / len(hits), 2) if hits else None,
    }


def engine_predictor(tz: ZoneInfo, cfg: PredictionConfig = DEFAULT_CONFIG, use_feedback: bool = False) -> Predictor:
    def run(rows, dob, now):
        if not use_feedback:
            rows = [{**r, "metadata": {}} for r in rows]
        out = predict(rows, dob, now, tz, cfg)
        return out.schedule, out.wake
    return run


def yesterday_predictor(tz: ZoneInfo, cfg: PredictionConfig = DEFAULT_CONFIG) -> Predictor:
    """Referencia ingenua: "hoy hará lo mismo que ayer" (mismas ventanas y duraciones,
    misma hora de dormir y de despertar). El motor tiene que ganarle con holgura."""
    def minutes(a, b):
        return (b - a).total_seconds() / 60

    def same_clock(ref: datetime, on: datetime) -> datetime:
        delta = (on.astimezone(tz).date() - ref.astimezone(tz).date()).days
        return (ref.astimezone(tz) + timedelta(days=delta)).astimezone(UTC)

    def next_clock(ref: datetime, after: datetime) -> datetime:
        candidate = same_clock(ref, after)
        while candidate <= after + timedelta(hours=3):
            candidate += timedelta(days=1)
        return candidate

    def run(rows, dob, now):
        days = segment_days(parse_events(rows), cfg)
        state = current_state(days, now, cfg)
        past = [d for d in (days[:-1] if state.kind == "day" else days) if d.complete]
        if not past:
            return [], None
        y = past[-1]
        windows = [minutes(y.wake if i == 0 else y.naps[i - 1].end, n.start) for i, n in enumerate(y.naps)]
        lengths = [n.minutes for n in y.naps]

        if state.kind == "night":
            wake = next_clock(y.wake, state.bed)
            today_naps, cursor = [], wake
        elif state.kind == "day":
            wake = state.day.wake or y.wake
            today_naps = state.day.naps
            cursor = wake
            if today_naps:
                last = today_naps[-1]
                expected = lengths[min(last.index, len(lengths)) - 1] if lengths else 60
                cursor = last.end or last.start + timedelta(minutes=expected)
        else:
            return [], None

        schedule = []
        for i in range(len(today_naps), len(y.naps)):
            start = max(cursor + timedelta(minutes=windows[i]), now)
            end = start + timedelta(minutes=lengths[i])
            schedule.append({"type": "nap", "index": i + 1, "start": to_iso_z(start), "end": to_iso_z(end)})
            cursor = end
        bed = max(same_clock(y.bed, wake), now)
        schedule.append({"type": "bedtime", "start": to_iso_z(bed)})
        next_wake = wake if state.kind == "night" else next_clock(y.wake, bed)
        return schedule, {"type": "woke_up", "start": to_iso_z(next_wake)}
    return run


def _rows_before(rows: list[dict], instant: datetime) -> list[dict]:
    """Lo que se sabía en `instant`: eventos ya empezados, sin el fin si aún no había llegado."""
    visible = []
    for r in rows:
        start = parse_ts(r["start_time"])
        if start >= instant:
            continue
        end = parse_ts(r.get("end_time"))
        visible.append({**r, "end_time": to_iso_z(end) if end and end <= instant else None})
    return visible


def collect(rows: list[dict], dob: date, predictor: Predictor, tz: ZoneInfo,
            warmup_days: int = 7, cfg: PredictionConfig = DEFAULT_CONFIG) -> Metrics:
    rows = sorted((r for r in rows if r.get("category") in SLEEP_CATEGORIES), key=lambda r: r["start_time"])
    metrics = Metrics()
    days = segment_days(parse_events(rows), cfg)
    if not days:
        return metrics
    first = days[0].anchor
    step = timedelta(minutes=5)

    def next_nap(schedule, index):
        return next((i for i in schedule if i["type"] == "nap" and i.get("index") == index), None)

    def bed_of(schedule):
        return next((i for i in schedule if i["type"] == "bedtime"), None)

    for d_idx, day in enumerate(days):
        if day.wake is None or day.wake - first < timedelta(days=warmup_days):
            continue
        phase = "cold" if day.wake - first < timedelta(days=COLD_DAYS) else "warm"
        closed = [n for n in day.naps if n.end]

        # Al despertar: 1ª siesta, duración, hora de dormir
        schedule, _ = predictor(_rows_before(rows, day.wake + step), dob, day.wake + step)
        if day.naps:
            metrics.add("nap1_start@wake", next_nap(schedule, 1), day.naps[0].start, phase)
        metrics.add("bedtime@wake", bed_of(schedule), day.bed, phase)

        # Tras cada siesta: inicio de la siguiente y hora de dormir
        for nap in closed:
            instant = nap.end + step
            if day.bed and instant >= day.bed:
                break
            schedule, _ = predictor(_rows_before(rows, instant), dob, instant)
            following = next((n for n in day.naps if n.index == nap.index + 1), None)
            if following:
                pred = next_nap(schedule, following.index)
                metrics.add("next_nap_start@nap_end", pred, following.start, phase)
                if pred and pred.get("end") and following.end:
                    pred_minutes = (parse_ts(pred["end"]) - parse_ts(pred["start"])).total_seconds() / 60
                    metrics.add_error("nap_duration", following.minutes - pred_minutes, phase)
            metrics.add("bedtime@nap_end", bed_of(schedule), day.bed, phase)

        # Al acostarse: despertar de mañana
        if day.bed and d_idx + 1 < len(days) and days[d_idx + 1].wake:
            instant = day.bed + step
            _, wake = predictor(_rows_before(rows, instant), dob, instant)
            metrics.add("wake@bedtime", wake, days[d_idx + 1].wake, phase)

    return metrics


def backtest(rows: list[dict], dob: date, predictor: Predictor, tz: ZoneInfo,
             warmup_days: int = 7, cfg: PredictionConfig = DEFAULT_CONFIG) -> dict:
    return collect(rows, dob, predictor, tz, warmup_days, cfg).summary()


def print_report(title: str, summary: dict) -> None:
    print(f"\n{title}")
    print(f"  {'métrica':<30}{'n':>5}{'MAE':>8}{'mediana':>9}{'p90':>8}{'sesgo':>8}{'cobert.':>9}   (minutos)")
    for name, m in summary.items():
        cov = "" if m.get("coverage") is None else f"{m['coverage']:.0%}"
        print(f"  {name:<30}{m['n']:>5}{m['mae']:>8}{m['median_abs']:>9}{m['p90_abs']:>8}{m['bias']:>8}{cov:>9}")


def _load_from_supabase(baby_id: str, days: int) -> tuple[list[dict], date]:
    from dependencies import get_supabase
    from repositories.baby_repository import BabyRepository
    from repositories.event_repository import EventRepository

    db = get_supabase()
    baby = BabyRepository(db).get_by_id(baby_id)
    if not baby:
        raise SystemExit(f"Bebé {baby_id} no encontrado")
    since = datetime.now(UTC) - timedelta(days=days + DEFAULT_CONFIG.history_days)
    rows = EventRepository(db).get_events_since(baby_id, since, SLEEP_CATEGORIES)
    return rows, date.fromisoformat(str(baby["dob"])[:10])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--baby-id")
    parser.add_argument("--json", help="fichero con una lista de eventos (category, start_time, end_time, metadata)")
    parser.add_argument("--dob", help="fecha de nacimiento (con --json)")
    parser.add_argument("--days", type=int, default=60, help="días a evaluar (con --baby-id)")
    parser.add_argument("--timezone", default="Europe/Madrid")
    parser.add_argument("--with-feedback", action="store_true", help="usar también la corrección por feedback")
    parser.add_argument("--baseline", action="store_true", help="comparar con la referencia 'como ayer'")
    args = parser.parse_args()

    tz = ZoneInfo(args.timezone)
    if args.baby_id:
        rows, dob = _load_from_supabase(args.baby_id, args.days)
    elif args.json and args.dob:
        with open(args.json, encoding="utf-8") as fh:
            rows = json.load(fh)
        dob = date.fromisoformat(args.dob)
    else:
        parser.error("indica --baby-id o --json + --dob")

    summary = backtest(rows, dob, engine_predictor(tz, use_feedback=args.with_feedback), tz)
    print_report(f"Backtest ({len(rows)} eventos de sueño)", summary)
    if args.baseline:
        print_report("Referencia 'como ayer'", backtest(rows, dob, yesterday_predictor(tz), tz))


if __name__ == "__main__":
    main()
