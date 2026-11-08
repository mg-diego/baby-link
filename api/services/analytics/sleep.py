"""Estadísticas de sueño: siestas, noches y despertares."""
from datetime import date

import pandas as pd

from services.analytics.base import StatsBase
from services.analytics.formatting import (
    _empty, _card, _clean, _series, _has_data, _chart, _fmt_num, _fmt_hm, _fmt_clock, _fmt_day, _safe_float, _by_hour_chart,
    UNIT_HOURS, UNIT_MINUTES, UNIT_COUNT, UNIT_ML, UNIT_KG, UNIT_CM,
)
from services.analytics.frames import _date_axis, _events_df, _per_day


class SleepStats(StatsBase):
    # ─── Sueño: carga de datos ────────────────────────────────────────────────

    def _load_naps(self, baby_id: str, start: date, end: date) -> pd.DataFrame:
        df = _events_df(self.repository.get_events_by_categories(baby_id, ["nap"], start, end), self.tz)
        if df.empty:
            return df
        # Las siestas en curso (sin end_time) o con duraciones absurdas no cuentan
        df = df.dropna(subset=['end']).copy()
        df['hours'] = (df['end'] - df['start']).dt.total_seconds() / 3600.0
        df = df[(df['hours'] > 0) & (df['hours'] < 12)].copy()
        df['nap_label'] = 'Siesta ' + (df.groupby('day').cumcount() + 1).astype(str)
        return df

    def _load_nights(self, baby_id: str, start: date, end: date) -> tuple[pd.DataFrame, pd.DataFrame]:
        """Empareja cada bed_time con su woke_up. La noche se asigna al día en que se acostó
        (restando 12h, para que acostarse a las 00:30 cuente como la noche anterior)."""
        night_cols = ['night', 'sleep_hrs', 'awake_hrs', 'wake_count', 'bed_min', 'woke_min']
        waking_cols = ['night', 'start', 'minutes']

        raw = self.repository.get_events_by_categories(
            baby_id, ["bed_time", "woke_up", "night_waking"], start, end, extra_hours_after=18
        )
        df = _events_df(raw, self.tz)
        if df.empty:
            return pd.DataFrame(columns=night_cols), pd.DataFrame(columns=waking_cols)

        keys = set(_date_axis(start, end)[0])
        beds = df[df['category'] == 'bed_time']['start'].tolist()
        wakes = df[df['category'] == 'woke_up']
        wakings = df[df['category'] == 'night_waking']

        nights, waking_rows = [], []
        for i, bed in enumerate(beds):
            logical = (bed - pd.Timedelta(hours=12)).strftime('%Y-%m-%d')
            if logical not in keys:
                continue

            limit = bed + pd.Timedelta(hours=16)
            if i + 1 < len(beds) and beds[i + 1] < limit:
                limit = beds[i + 1]
            candidates = wakes[(wakes['start'] > bed) & (wakes['start'] <= limit)]
            if candidates.empty:
                continue  # Noche sin cerrar
            woke = candidates['start'].iloc[0]

            night_wakings = wakings[(wakings['start'] >= bed) & (wakings['start'] <= woke)]
            minutes = ((night_wakings['end'] - night_wakings['start']).dt.total_seconds() / 60.0).clip(lower=0)

            in_bed = (woke - bed).total_seconds() / 3600.0
            awake = float(minutes.fillna(0).sum()) / 60.0
            nights.append({
                'night': logical,
                'sleep_hrs': max(in_bed - awake, 0),
                'awake_hrs': awake,
                'wake_count': len(night_wakings),
                # Minutos desde mediodía para poder promediar horas que cruzan la medianoche
                'bed_min': (bed.hour * 60 + bed.minute - 720) % 1440,
                'woke_min': woke.hour * 60 + woke.minute,
            })
            for (_, w), mins in zip(night_wakings.iterrows(), minutes):
                waking_rows.append({'night': logical, 'start': w['start'], 'minutes': mins})

        nights_df = pd.DataFrame(nights, columns=night_cols)
        # Si se registró dos veces la misma noche, nos quedamos con la última
        nights_df = nights_df.drop_duplicates(subset='night', keep='last')
        return nights_df, pd.DataFrame(waking_rows, columns=waking_cols)

    # ─── Sueño: Todo ──────────────────────────────────────────────────────────

    def generate_sleep_overview_stats(self, baby_id: str, start: date, end: date) -> dict:
        naps = self._load_naps(baby_id, start, end)
        nights, _ = self._load_nights(baby_id, start, end)
        if naps.empty and nights.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        nap_hours = _per_day(naps, keys, 'hours')
        night_hours = nights.set_index('night')['sleep_hrs'].reindex(keys, fill_value=0).astype(float)
        total = nap_hours + night_hours
        # Para las medias sólo cuentan los días con la noche cerrada (si no, la noche de hoy hunde la media)
        complete = night_hours > 0 if not nights.empty else nap_hours > 0

        summary_cards = [
            _card("Sueño total/día", _fmt_hm(total[complete].mean())),
            _card("Sueño nocturno", _fmt_hm(nights['sleep_hrs'].mean()) if not nights.empty else "—"),
            _card("Siestas/día", _fmt_hm(nap_hours[complete].mean())),
            _card("Despertares/noche", _fmt_num(nights['wake_count'].mean()) if not nights.empty else "—"),
        ]

        stacked = [_series("Sueño nocturno", night_hours), _series("Siestas", nap_hours)]
        stacked = [s for s in stacked if _has_data([s])]
        charts = [_chart("sleep_daily", "Sueño por día", "stacked_bar", x_labels, stacked, UNIT_HOURS)]

        if night_hours.sum() > 0 and nap_hours.sum() > 0:
            share = [_series("Horas", [night_hours.sum(), nap_hours.sum()])]
            charts.append(_chart("sleep_share", "Reparto del sueño", "donut",
                                 ["Sueño nocturno", "Siestas"], share, UNIT_HOURS))

        return {"summary_cards": summary_cards, "charts": charts}

    # ─── Sueño: Siestas ───────────────────────────────────────────────────────

    def generate_nap_sleep_stats(self, baby_id: str, start: date, end: date) -> dict:
        df = self._load_naps(baby_id, start, end)
        if df.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        daily_hours = _per_day(df, keys, 'hours')
        daily_count = _per_day(df, keys)
        nap_days = daily_count[daily_count > 0]

        summary_cards = [
            _card("Siestas/día", _fmt_num(nap_days.mean())),
            _card("Duración media", _fmt_hm(df['hours'].mean())),
            _card("Horas de siesta/día", _fmt_hm(daily_hours[daily_count > 0].mean())),
            _card("Total siestas", str(len(df))),
        ]

        # Los días sin siestas se dejan como hueco en las líneas (no hay dato, no es 0)
        daily_hours_line = daily_hours.where(daily_count > 0)
        charts = [
            _chart("naps_daily_hours", "Horas de siesta por día", "line", x_labels,
                   [_series("Horas de siesta", daily_hours_line)], UNIT_HOURS),
            _chart("naps_daily_count", "Siestas por día", "stacked_bar", x_labels,
                   [_series("Siestas", daily_count, 0)], UNIT_COUNT),
        ]

        labels = sorted(df['nap_label'].unique(), key=lambda l: int(l.split()[-1]))
        pivot = df.pivot_table(index='day', columns='nap_label', values='hours', aggfunc='sum').reindex(keys)
        # Con muchas siestas (recién nacido) las gráficas por siesta son ilegibles
        if 1 < len(labels) <= 5:
            charts.append(_chart("naps_evolution", "Duración de cada siesta", "line_multiple", x_labels,
                                 [_series(l, pivot[l]) for l in labels], UNIT_HOURS))

        avg_per_nap = df.groupby('nap_label')['hours'].mean().reindex(labels)
        charts.append(_chart("naps_average", "Duración media por siesta", "stacked_bar", labels,
                             [_series("Duración media", avg_per_nap)], UNIT_HOURS))

        if 1 < len(labels) <= 6:
            sums = df.groupby('nap_label')['hours'].sum().reindex(labels)
            charts.append(_chart("naps_distribution", "Reparto del sueño diurno", "donut", labels,
                                 [_series("Horas", sums)], UNIT_HOURS))

        return {"summary_cards": summary_cards, "charts": charts}

    # ─── Sueño: Nocturno ──────────────────────────────────────────────────────

    def generate_night_sleep_stats(self, baby_id: str, start: date, end: date) -> dict:
        nights, _ = self._load_nights(baby_id, start, end)
        if nights.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        by_night = nights.set_index('night').reindex(keys)

        summary_cards = [
            _card("Sueño nocturno", _fmt_hm(nights['sleep_hrs'].mean())),
            _card("Despertares/noche", _fmt_num(nights['wake_count'].mean())),
            _card("Hora de acostarse", _fmt_clock(nights['bed_min'].mean() + 720)),
            _card("Hora de despertar", _fmt_clock(nights['woke_min'].mean())),
        ]

        charts = [
            _chart("night_sleep_total", "Horas de sueño nocturno", "line", x_labels,
                   [_series("Sueño nocturno", by_night['sleep_hrs'])], UNIT_HOURS),
            _chart("night_in_bed", "Tiempo dormido vs despierto", "stacked_bar", x_labels,
                   [_series("Sueño nocturno", by_night['sleep_hrs'].fillna(0)),
                    _series("Despierto", by_night['awake_hrs'].fillna(0))], UNIT_HOURS),
        ]
        wake_counts = [_series("Despertares", by_night['wake_count'].fillna(0), 0)]
        if _has_data(wake_counts):
            charts.append(_chart("night_wake_count", "Despertares por noche", "stacked_bar",
                                 x_labels, wake_counts, UNIT_COUNT))

        return {"summary_cards": summary_cards, "charts": charts}

    # ─── Sueño: Despertares ───────────────────────────────────────────────────

    def generate_night_waking_stats(self, baby_id: str, start: date, end: date) -> dict:
        nights, wakings = self._load_nights(baby_id, start, end)
        if nights.empty:
            return _empty()

        keys, x_labels = _date_axis(start, end)
        by_night = nights.set_index('night').reindex(keys)
        quiet_nights = int((nights['wake_count'] == 0).sum())
        avg_waking_min = wakings['minutes'].mean() if not wakings.empty else None

        summary_cards = [
            _card("Despertares/noche", _fmt_num(nights['wake_count'].mean())),
            _card("Duración media", f"{_fmt_num(avg_waking_min, 0)} min" if avg_waking_min is not None and not pd.isna(avg_waking_min) else "—"),
            _card("Despierto/noche", _fmt_hm(nights['awake_hrs'].mean())),
            _card("Noches sin despertar", f"{quiet_nights} de {len(nights)}"),
        ]

        charts = [
            _chart("waking_count", "Despertares por noche", "stacked_bar", x_labels,
                   [_series("Despertares", by_night['wake_count'].fillna(0), 0)], UNIT_COUNT),
        ]
        awake_minutes = [_series("Minutos despierto", by_night['awake_hrs'] * 60, 0)]
        if _has_data(awake_minutes):
            charts.append(_chart("waking_minutes", "Tiempo despierto por noche", "line",
                                 x_labels, awake_minutes, UNIT_MINUTES))

        by_hour = _by_hour_chart("waking_by_hour", "¿A qué hora se despierta?", "Despertares", wakings, order_from=18)
        if by_hour:
            charts.append(by_hour)

        return {"summary_cards": summary_cards, "charts": charts}
