"""Corrección por el error de predicciones pasadas.

Cuando la app registra un evento guarda en su metadata la predicción que mostraba
(`predicted_start_time`, `predicted_end_time`) y el bloque `predicted_feedback` que
devolvió la API, con la corrección que ya llevaba aplicada (`start_bias_min`...).

El error se mide contra la predicción *base* (sin corrección):
    error_base = (real - predicho) + corrección_aplicada
Si se midiera contra la predicción ya corregida, la corrección se persigue a sí misma
y se queda en 1/3 del sesgo real (c = g·(D − c) -> c = D/3 con g = 0.5).

Los eventos antiguos sin `predicted_feedback` se ignoran: no sabemos qué corrección
llevaban y contaminarían la estimación.

`predicted_feedback.base_start` es la predicción sin recortar a "ahora". Sin ella, cuando
el bebé se dormía más tarde de lo previsto la app mostraba "ya" (`overdue`) y ese día no se
podía medir: solo se aprendía de los días en que se adelantaba y la corrección acababa
adelantando las predicciones. Con `base_start` se mide siempre; los eventos anteriores
a este campo que iban con retraso se siguen ignorando.
"""
from statistics import median

from core.timeutils import parse_ts
from prediction.config import PredictionConfig
from prediction.models import BED_TIME, NAP, WOKE_UP, Biases, SleepEvent

FEEDBACK_KEY = "predicted_feedback"


def compute_biases(events: list[SleepEvent], cfg: PredictionConfig) -> Biases:
    buckets: dict[str, list[float]] = {"ww_first": [], "ww_mid": [], "nap_duration": [], "bedtime": [], "wake": []}

    for ev in events:  # orden cronológico
        meta = ev.metadata or {}
        fb = meta.get(FEEDBACK_KEY)
        if not isinstance(fb, dict):
            continue  # sin datos de corrección
        try:
            shown = parse_ts(meta.get("predicted_start_time"))
            predicted_end = parse_ts(meta.get("predicted_end_time"))
            base = parse_ts(fb.get("base_start"))
        except ValueError:
            continue
        if shown is None:
            continue
        # Hora de inicio prevista: la base sin recortar; en eventos antiguos, la mostrada,
        # que solo vale si no iba con retraso (entonces era "ahora", no una predicción)
        predicted = base if base is not None else (None if fb.get("overdue") else shown)

        error = None
        if predicted is not None:
            error = (ev.start - predicted).total_seconds() / 60 + float(fb.get("start_bias_min") or 0)
        if error is not None and abs(error) <= cfg.feedback_outlier_min:
            if ev.category == NAP:
                index = meta.get("nap_index") or fb.get("nap_index") or 1
                buckets["ww_first" if int(index) == 1 else "ww_mid"].append(error)
            elif ev.category == BED_TIME:
                buckets["bedtime"].append(error)
            elif ev.category == WOKE_UP:
                buckets["wake"].append(error)

        if ev.category == NAP and ev.end and predicted_end and not fb.get("catnap"):
            predicted_minutes = (predicted_end - shown).total_seconds() / 60
            actual_minutes = (ev.end - ev.start).total_seconds() / 60
            duration_error = actual_minutes - predicted_minutes + float(fb.get("duration_bias_min") or 0)
            if abs(duration_error) <= cfg.feedback_outlier_min:
                buckets["nap_duration"].append(duration_error)

    def bias(errors: list[float]) -> float:
        recent = errors[-cfg.feedback_window:]
        if len(recent) < cfg.feedback_min_samples:
            return 0.0
        value = cfg.feedback_gain * median(recent)
        return max(-cfg.feedback_max_abs_min, min(cfg.feedback_max_abs_min, value))

    return Biases(**{name: bias(errors) for name, errors in buckets.items()})
