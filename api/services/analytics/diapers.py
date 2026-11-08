"""Estadísticas de pañales."""
from datetime import date

import pandas as pd

from services.analytics.base import StatsBase
from services.analytics.formatting import (
    _empty, _card, _clean, _series, _has_data, _chart, _fmt_num, _fmt_hm, _fmt_clock, _fmt_day, _safe_float, _by_hour_chart,
    UNIT_HOURS, UNIT_MINUTES, UNIT_COUNT, UNIT_ML, UNIT_KG, UNIT_CM,
)
from services.analytics.frames import _date_axis, _events_df, _per_day


class DiaperStats(StatsBase):
    # ─── Pañales ──────────────────────────────────────────────────────────────

    @staticmethod
    def _diaper_kind(meta: dict) -> str:
        # Valores de la app (wet/dirty/mixed/clean) y de la migración CSV (pee, poo, "Both, pee:medium"...)
        raw = f"{meta.get('condition') or ''} {meta.get('ui_condition') or ''}".lower()
        has_poo = any(k in raw for k in ('poo', 'dirty', 'sucio'))
        has_pee = any(k in raw for k in ('pee', 'wet', 'mojado'))
        if any(k in raw for k in ('both', 'mixed', 'variado')) or (has_poo and has_pee):
            return 'mixed'
        if has_poo:
            return 'dirty'
        if has_pee:
            return 'wet'
        if any(k in raw for k in ('clean', 'dry', 'seco')):
            return 'dry'
        return 'other'

    def generate_diaper_stats(self, baby_id: str, start: date, end: date, only: str | None = None) -> dict:
        df = _events_df(self.repository.get_events_by_categories(baby_id, ["diaper"], start, end), self.tz)
        if df.empty:
            return _empty()

        df['kind'] = df['metadata'].apply(self._diaper_kind)
        keys, x_labels = _date_axis(start, end)
        tracked = max(df['day'].nunique(), 1)
        wet = df[df['kind'].isin(['wet', 'mixed'])]
        dirty = df[df['kind'].isin(['dirty', 'mixed'])]

        if only is None:
            summary_cards = [
                _card("Pañales/día", _fmt_num(len(df) / tracked)),
                _card("Mojados/día", _fmt_num(len(wet) / tracked)),
                _card("Sucios/día", _fmt_num(len(dirty) / tracked)),
                _card("Total pañales", str(len(df))),
            ]
            names = {'wet': "Mojado", 'dirty': "Sucio", 'mixed': "Mixto", 'dry': "Seco", 'other': "Otro"}
            per_day = [_series(name, _per_day(df[df['kind'] == k], keys), 0) for k, name in names.items()]
            per_day = [s for s in per_day if _has_data([s])]
            charts = [_chart("diaper_daily", "Pañales por día", "stacked_bar", x_labels, per_day, UNIT_COUNT)]

            counts = df['kind'].value_counts()
            present = [k for k in names if k in counts.index]
            if len(present) > 1:
                charts.append(_chart("diaper_types", "Tipo de pañal", "donut", [names[k] for k in present],
                                     [_series("Pañales", [counts[k] for k in present], 0)], UNIT_COUNT))
            return {"summary_cards": summary_cards, "charts": charts}

        subset, name = (wet, "Mojado") if only == "wet" else (dirty, "Sucio")
        if subset.empty:
            return _empty()

        daily = _per_day(subset, keys)
        # Intervalo medio entre pañales, ignorando huecos de más de 12h (noches sin registrar)
        gaps = subset['start'].diff().dt.total_seconds() / 3600.0
        gaps = gaps[(gaps > 0) & (gaps <= 12)]

        summary_cards = [
            _card(f"{name}s/día", _fmt_num(len(subset) / tracked)),
            _card(f"Total {name.lower()}s", str(len(subset))),
            _card("Intervalo medio", _fmt_hm(gaps.mean()) if not gaps.empty else "—"),
            _card(f"Días sin {name.lower()}", f"{tracked - subset['day'].nunique()} de {tracked}"),
        ]
        charts = [_chart(f"diaper_{only}_daily", f"Pañales {name.lower()}s por día", "stacked_bar", x_labels,
                         [_series(name, daily, 0)], UNIT_COUNT)]
        by_hour = _by_hour_chart(f"diaper_{only}_by_hour", "Por hora del día", name, subset)
        if by_hour:
            charts.append(by_hour)

        return {"summary_cards": summary_cards, "charts": charts}
