"""Estadísticas de crecimiento (peso, altura, perímetro cefálico)."""
from datetime import date

import pandas as pd

from services.analytics.base import StatsBase
from services.analytics.formatting import (
    _empty, _card, _clean, _series, _has_data, _chart, _fmt_num, _fmt_hm, _fmt_clock, _fmt_day, _safe_float, _by_hour_chart,
    UNIT_HOURS, UNIT_MINUTES, UNIT_COUNT, UNIT_ML, UNIT_KG, UNIT_CM,
)
from services.analytics.frames import _date_axis, _events_df, _per_day


class GrowthStats(StatsBase):
    # ─── Crecimiento ──────────────────────────────────────────────────────────

    GROWTH_METRICS = {
        "Peso": ("weight_kg", UNIT_KG, "kg", 2, "Evolución del peso"),
        "Altura": ("height_cm", UNIT_CM, "cm", 1, "Evolución de la altura"),
        "Perímetro": ("head_cm", UNIT_CM, "cm", 1, "Evolución del perímetro cefálico"),
    }

    def generate_growth_stats(self, baby_id: str, end: date, metric: str) -> dict:
        """Las mediciones son esporádicas, así que se usa todo el histórico hasta end_date."""
        key, unit, suffix, decimals, title = self.GROWTH_METRICS[metric]
        df = _events_df(self.repository.get_events_until(baby_id, "growth", end), self.tz)
        if df.empty:
            return _empty()

        df['value'] = df['metadata'].apply(lambda m: _safe_float(m.get(key)))
        df = df[df['value'] > 0]
        if df.empty:
            return _empty()

        multi_year = df['start'].dt.year.nunique() > 1
        x_labels = [
            f"{_fmt_day(ts)} {str(ts.year)[2:]}" if multi_year else _fmt_day(ts)
            for ts in df['start']
        ]

        last, first = df.iloc[-1], df.iloc[0]
        trend = None
        if len(df) > 1:
            diff = last['value'] - df.iloc[-2]['value']
            trend = f"{'+' if diff >= 0 else '-'}{_fmt_num(abs(diff), decimals)}"

        summary_cards = [
            _card(f"{metric} actual", f"{_fmt_num(last['value'], decimals)} {suffix}", trend),
            _card("Última medición", f"{_fmt_day(last['start'])} {last['start'].year}"),
        ]
        days = (last['start'] - first['start']).days
        if len(df) > 1 and days > 0:
            total = last['value'] - first['value']
            per_month = total / days * 30.44
            summary_cards += [
                _card("Desde la 1ª medición", f"{'+' if total >= 0 else '-'}{_fmt_num(abs(total), decimals)} {suffix}"),
                _card("Ritmo mensual", f"{'+' if per_month >= 0 else '-'}{_fmt_num(abs(per_month), decimals)} {suffix}"),
            ]

        charts = [_chart(f"growth_{key}", title, "line", x_labels,
                         [_series(metric, df['value'], decimals)], unit)]
        return {"summary_cards": summary_cards, "charts": charts}
