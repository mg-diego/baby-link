"""Backtesting del motor de predicciones sobre un historial real o sintético.

Para cada día del historial se "viaja en el tiempo" a varios momentos (al despertar, al
terminar cada siesta y al acostarse), se predice usando solo los eventos anteriores y se
compara con lo que pasó de verdad. Sirve para ajustar `PredictionConfig` con datos.

Uso (desde api/):
    python -m tools.backtest --baby-id <uuid>              # lee de Supabase (solo lectura)
    python -m tools.backtest --json eventos.json --dob 2025-08-15
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
from prediction.segmentation import parse_events, segment_days

# (filas anteriores al instante, dob, instante) -> (agenda, despertar previsto o None)
Predictor = Callable[[list[dict], date, datetime], tuple[list[dict], dict | None]]


@dataclass
class Metrics:
    errors: dict[str, list[float]] = field(default_factory=dict)

    def add(self, name: str, predicted: str | None, actual: datetime | None):
        if predicted is None or actual is None:
            return
        self.errors.setdefault(name, []).append((actual - parse_ts(predicted)).total_seconds() / 60)

    def summary(self) -> dict[str, dict]:
        out = {}
        for name, errs in sorted(self.errors.items()):
            abs_errs = sorted(abs(e) for e in errs)
            out[name] = {
                "n": len(errs),
                "mae": round(statistics.fmean(abs_errs), 1),
                "median_abs": round(statistics.median(abs_errs), 1),
                "p90_abs": round(abs_errs[int(0.9 * (len(abs_errs) - 1))], 1),
                "bias": round(statistics.fmean(errs), 1),  # >0: la realidad llega más tarde que lo predicho
            }
        return out


def engine_predictor(tz: ZoneInfo, cfg: PredictionConfig = DEFAULT_CONFIG, use_feedback: bool = False) -> Predictor:
    def run(rows, dob, now):
        if not use_feedback:
            rows = [{**r, "metadata": {}} for r in rows]
        out = predict(rows, dob, now, tz, cfg)
        return out.schedule, out.wake
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


def backtest(rows: list[dict], dob: date, predictor: Predictor, tz: ZoneInfo,
             warmup_days: int = 7, cfg: PredictionConfig = DEFAULT_CONFIG) -> dict:
    rows = sorted((r for r in rows if r.get("category") in SLEEP_CATEGORIES), key=lambda r: r["start_time"])
    days = segment_days(parse_events(rows), cfg)
    if not days:
        return {}
    first = days[0].anchor
    metrics = Metrics()
    step = timedelta(minutes=5)

    def next_nap(schedule, index):
        return next((i for i in schedule if i["type"] == "nap" and i.get("index") == index), None)

    def bed_of(schedule):
        return next((i["start"] for i in schedule if i["type"] == "bedtime"), None)

    for d_idx, day in enumerate(days):
        if day.wake is None or day.wake - first < timedelta(days=warmup_days):
            continue
        closed = [n for n in day.naps if n.end]

        # Al despertar: 1ª siesta, duración, hora de dormir
        schedule, _ = predictor(_rows_before(rows, day.wake + step), dob, day.wake + step)
        if day.naps:
            pred = next_nap(schedule, 1)
            metrics.add("nap1_start@wake", pred and pred["start"], day.naps[0].start)
        metrics.add("bedtime@wake", bed_of(schedule), day.bed)

        # Tras cada siesta: inicio de la siguiente y hora de dormir
        for nap in closed:
            instant = nap.end + step
            if day.bed and instant >= day.bed:
                break
            schedule, _ = predictor(_rows_before(rows, instant), dob, instant)
            following = next((n for n in day.naps if n.index == nap.index + 1), None)
            if following:
                pred = next_nap(schedule, following.index)
                metrics.add("next_nap_start@nap_end", pred and pred["start"], following.start)
                if pred and following.end:
                    pred_minutes = (parse_ts(pred["end"]) - parse_ts(pred["start"])).total_seconds() / 60
                    metrics.errors.setdefault("nap_duration", []).append(following.minutes - pred_minutes)
            metrics.add("bedtime@nap_end", bed_of(schedule), day.bed)

        # Al acostarse: despertar de mañana
        if day.bed and d_idx + 1 < len(days) and days[d_idx + 1].wake:
            instant = day.bed + step
            _, wake = predictor(_rows_before(rows, instant), dob, instant)
            metrics.add("wake@bedtime", wake and wake["start"], days[d_idx + 1].wake)

    return metrics.summary()


def print_report(title: str, summary: dict) -> None:
    print(f"\n{title}")
    print(f"  {'métrica':<24}{'n':>5}{'MAE':>8}{'mediana':>9}{'p90':>8}{'sesgo':>8}   (minutos)")
    for name, m in summary.items():
        print(f"  {name:<24}{m['n']:>5}{m['mae']:>8}{m['median_abs']:>9}{m['p90_abs']:>8}{m['bias']:>8}")


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


if __name__ == "__main__":
    main()
