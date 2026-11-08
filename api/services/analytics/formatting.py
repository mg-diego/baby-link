"""Construcción de tarjetas y gráficas y formato de valores para la pantalla de estadísticas."""
from datetime import date

import pandas as pd

MESES = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']

# Unidades que entiende la app para formatear ejes y tooltips
UNIT_HOURS = "hours"
UNIT_MINUTES = "minutes"
UNIT_COUNT = "count"
UNIT_ML = "ml"
UNIT_KG = "kg"
UNIT_CM = "cm"


# ─── Helpers de formato ───────────────────────────────────────────────────────

def _empty() -> dict:
    return {"summary_cards": [], "charts": []}


def _card(label: str, value: str, trend: str | None = None) -> dict:
    return {"label": label, "value": value, "trend": trend}


def _clean(values, decimals: int = 2) -> list:
    out = []
    for v in values:
        if v is None or pd.isna(v):
            out.append(None)
        elif decimals == 0:
            out.append(int(round(float(v))))
        else:
            out.append(round(float(v), decimals))
    return out


def _series(name: str, values, decimals: int = 2) -> dict:
    return {"name": name, "data": _clean(values, decimals)}


def _has_data(series: list) -> bool:
    return any(v not in (None, 0) for s in series for v in s["data"])


def _chart(chart_id: str, title: str, chart_type: str, x_labels: list, series: list, unit: str) -> dict:
    return {
        "id": chart_id,
        "title": title,
        "type": chart_type,
        "data": {"x_labels": x_labels, "series": series, "unit": unit},
    }


def _fmt_num(value: float, decimals: int = 1) -> str:
    if value is None or pd.isna(value):
        return "—"
    if decimals == 0:
        return str(int(round(value)))
    text = f"{value:.{decimals}f}".rstrip('0').rstrip('.')
    return text.replace('.', ',')


def _fmt_hm(hours: float) -> str:
    if hours is None or pd.isna(hours):
        return "—"
    total = int(round(hours * 60))
    h, m = divmod(total, 60)
    if h and m:
        return f"{h}h {m}m"
    if h:
        return f"{h}h"
    return f"{m}m"


def _fmt_clock(minutes: float) -> str:
    if minutes is None or pd.isna(minutes):
        return "—"
    total = int(round(minutes)) % 1440
    return f"{total // 60:02d}:{total % 60:02d}"


def _fmt_day(ts) -> str:
    return f"{ts.day} {MESES[ts.month - 1]}"


def _safe_float(val) -> float:
    if val in (None, ""):
        return 0.0
    try:
        return float(str(val).replace(',', '.'))
    except (ValueError, TypeError):
        return 0.0



def _by_hour_chart(chart_id: str, title: str, series_name: str, df: pd.DataFrame, order_from: int = 0) -> dict | None:
    """Barra con el número de eventos por hora del día (sólo el tramo de horas con datos)."""
    if df.empty:
        return None
    counts = df['start'].dt.hour.value_counts()
    ordered = [(h + order_from) % 24 for h in range(24)]
    present = [h for h in ordered if h in counts.index]
    first, last = ordered.index(present[0]), ordered.index(present[-1])
    hours = ordered[first:last + 1]
    return _chart(chart_id, title, "stacked_bar", [f"{h}h" for h in hours],
                  [_series(series_name, [counts.get(h, 0) for h in hours], 0)], UNIT_COUNT)
