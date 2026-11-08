"""Estadísticas de alimentación: lactancia, biberón y sólidos."""
from datetime import date

import pandas as pd

from services.analytics.base import StatsBase
from services.analytics.formatting import (
    _empty, _card, _clean, _series, _has_data, _chart, _fmt_num, _fmt_hm, _fmt_clock, _fmt_day, _safe_float, _by_hour_chart,
    UNIT_HOURS, UNIT_MINUTES, UNIT_COUNT, UNIT_ML, UNIT_KG, UNIT_CM,
)
from services.analytics.frames import _date_axis, _events_df, _per_day


class FeedingStats(StatsBase):
    # ─── Alimentación ─────────────────────────────────────────────────────────

    def _load_feeds(self, baby_id: str, start: date, end: date) -> pd.DataFrame:
        df = _events_df(self.repository.get_events_by_categories(baby_id, ["feed"], start, end), self.tz)
        if df.empty:
            return df

        def kind(meta: dict):
            t = meta.get('type')
            return t if t in ('nursing', 'bottle', 'solids') else None

        def side(meta: dict):
            s = meta.get('side')
            return s if s in ('Izquierdo', 'Derecho', 'Ambos') else None

        df['kind'] = df['metadata'].apply(kind)
        df['ml'] = df['metadata'].apply(lambda m: _safe_float(m.get('amount_ml')))
        df['side'] = df['metadata'].apply(side)
        df['milk_type'] = df['metadata'].apply(lambda m: m.get('milk_type') or None)
        minutes = (df['end'] - df['start']).dt.total_seconds() / 60.0
        df['minutes'] = minutes.where((minutes > 0) & (minutes < 180))
        return df

    def generate_feed_analytics(self, baby_id: str, start: date, end: date) -> dict:
        df = self._load_feeds(baby_id, start, end)
        if df.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        tracked = max(df['day'].nunique(), 1)
        nursing, bottle, solids = (df[df['kind'] == k] for k in ('nursing', 'bottle', 'solids'))
        milk_feeds = len(nursing) + len(bottle)

        summary_cards = [
            _card("Tomas de leche/día", _fmt_num(milk_feeds / tracked)),
            _card("Biberón/día", f"{int(round(bottle['ml'].sum() / tracked))} ml" if bottle['ml'].sum() > 0 else "—"),
            _card("Sólidos/día", _fmt_num(len(solids) / tracked)),
            _card("Total tomas", str(len(df))),
        ]

        per_day = [
            _series("Lactancia", _per_day(nursing, keys), 0),
            _series("Biberón", _per_day(bottle, keys), 0),
            _series("Sólidos", _per_day(solids, keys), 0),
        ]
        per_day = [s for s in per_day if _has_data([s])]
        charts = [_chart("feed_daily_count", "Tomas por día", "stacked_bar", x_labels, per_day, UNIT_COUNT)]

        if not bottle.empty and bottle['ml'].sum() > 0:
            charts.append(_chart("feed_bottle_ml", "Biberón por día", "line", x_labels,
                                 [_series("Volumen", _per_day(bottle, keys, 'ml'), 0)], UNIT_ML))

        types = [_series("Tomas", [len(nursing), len(bottle), len(solids)], 0)]
        if sum(1 for v in types[0]["data"] if v) > 1:
            charts.append(_chart("feed_type_dist", "Tipo de toma", "donut",
                                 ["Lactancia", "Biberón", "Sólidos"], types, UNIT_COUNT))

        return {"summary_cards": summary_cards, "charts": charts}

    def generate_bottle_stats(self, baby_id: str, start: date, end: date) -> dict:
        df = self._load_feeds(baby_id, start, end)
        bottle = df[df['kind'] == 'bottle'] if not df.empty else df
        if bottle.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        tracked = max(df['day'].nunique(), 1)
        with_ml = bottle[bottle['ml'] > 0]
        daily_count = _per_day(bottle, keys)
        daily_ml = _per_day(bottle, keys, 'ml')

        summary_cards = [
            _card("Volumen/día", f"{int(round(bottle['ml'].sum() / tracked))} ml" if not with_ml.empty else "—"),
            _card("Biberones/día", _fmt_num(len(bottle) / tracked)),
            _card("Media por biberón", f"{int(round(with_ml['ml'].mean()))} ml" if not with_ml.empty else "—"),
            _card("Total biberones", str(len(bottle))),
        ]

        charts = []
        if daily_ml.sum() > 0:
            charts.append(_chart("bottle_ml", "Volumen por día", "line", x_labels,
                                 [_series("Volumen", daily_ml, 0)], UNIT_ML))
        charts.append(_chart("bottle_count", "Biberones por día", "stacked_bar", x_labels,
                             [_series("Biberón", daily_count, 0)], UNIT_COUNT))

        milk = bottle['milk_type'].dropna().value_counts()
        if len(milk) > 1:
            charts.append(_chart("bottle_milk_type", "Tipo de leche", "donut", milk.index.tolist(),
                                 [_series("Biberones", milk.tolist(), 0)], UNIT_COUNT))

        return {"summary_cards": summary_cards, "charts": charts}

    def generate_nursing_stats(self, baby_id: str, start: date, end: date) -> dict:
        df = self._load_feeds(baby_id, start, end)
        nursing = df[df['kind'] == 'nursing'] if not df.empty else df
        if nursing.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        tracked = max(df['day'].nunique(), 1)
        avg_minutes = nursing['minutes'].mean()

        summary_cards = [
            _card("Tomas/día", _fmt_num(len(nursing) / tracked)),
            _card("Duración media", f"{_fmt_num(avg_minutes, 0)} min" if not pd.isna(avg_minutes) else "—"),
            _card("Al pecho/día", _fmt_hm(nursing['minutes'].sum() / 60.0 / tracked) if not pd.isna(avg_minutes) else "—"),
            _card("Total tomas", str(len(nursing))),
        ]

        charts = [_chart("nursing_count", "Tomas al pecho por día", "stacked_bar", x_labels,
                         [_series("Lactancia", _per_day(nursing, keys), 0)], UNIT_COUNT)]

        if not pd.isna(avg_minutes):
            charts.append(_chart("nursing_minutes", "Minutos al pecho por día", "stacked_bar", x_labels,
                                 [_series("Lactancia", _per_day(nursing.fillna({'minutes': 0}), keys, 'minutes'), 0)],
                                 UNIT_MINUTES))

        sides = nursing['side'].dropna().value_counts()
        if not sides.empty:
            order = [s for s in ('Izquierdo', 'Derecho', 'Ambos') if s in sides.index]
            charts.append(_chart("nursing_side", "Pecho utilizado", "donut", order,
                                 [_series("Tomas", [sides[s] for s in order], 0)], UNIT_COUNT))

        return {"summary_cards": summary_cards, "charts": charts}

    def generate_solids_stats(self, baby_id: str, start: date, end: date) -> dict:
        df = self._load_feeds(baby_id, start, end)
        solids = df[df['kind'] == 'solids'] if not df.empty else df
        if solids.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        tracked = max(df['day'].nunique(), 1)

        summary_cards = [
            _card("Comidas/día", _fmt_num(len(solids) / tracked)),
            _card("Total comidas", str(len(solids))),
            _card("Días con sólidos", f"{solids['day'].nunique()} de {tracked}"),
        ]

        charts = [_chart("solids_count", "Comidas sólidas por día", "stacked_bar", x_labels,
                         [_series("Sólidos", _per_day(solids, keys), 0)], UNIT_COUNT)]
        by_hour = _by_hour_chart("solids_by_hour", "Horario de las comidas", "Sólidos", solids, order_from=5)
        if by_hour:
            charts.append(by_hour)

        return {"summary_cards": summary_cards, "charts": charts}
