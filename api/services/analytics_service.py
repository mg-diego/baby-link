from datetime import datetime, date, timedelta

import pandas as pd
from models.analytics_models import DailySummary
from models.event_models import EventCategory
from repositories.analytics_repository import AnalyticsRepository

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


def _date_axis(start: date, end: date) -> tuple[list[str], list[str]]:
    days = pd.date_range(start=start, end=end)
    return [d.strftime('%Y-%m-%d') for d in days], [_fmt_day(d) for d in days]


def _to_local(column: pd.Series, tz: str) -> pd.Series:
    return pd.to_datetime(column, format='ISO8601', utc=True, errors='coerce').dt.tz_convert(tz)


def _events_df(raw: list, tz: str) -> pd.DataFrame:
    df = pd.DataFrame(raw)
    if df.empty:
        return df
    for col in ('end_time', 'metadata'):
        if col not in df.columns:
            df[col] = None
    df['start'] = _to_local(df['start_time'], tz)
    df['end'] = _to_local(df['end_time'], tz)
    df['metadata'] = df['metadata'].apply(lambda m: m if isinstance(m, dict) else {})
    df = df.dropna(subset=['start']).sort_values('start').reset_index(drop=True)
    df['day'] = df['start'].dt.strftime('%Y-%m-%d')
    return df


def _per_day(df: pd.DataFrame, keys: list[str], column: str | None = None) -> pd.Series:
    """Cuenta (o suma `column`) por día, con 0 en los días sin datos."""
    if df.empty:
        return pd.Series(0.0, index=keys)
    grouped = df.groupby('day')[column].sum() if column else df.groupby('day').size()
    return grouped.reindex(keys, fill_value=0).astype(float)


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


class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository):
        self.repository = repository
        self.tz = str(repository.tz)

    def get_events_by_date_range(self, baby_id: str, start_date: date, end_date: date) -> list:
        return self.repository.get_events_by_date_range(baby_id, start_date, end_date)

    def get_daily_summary(self, baby_id: str, target_date: date) -> DailySummary:
        events = self.repository.get_events_by_date_range(baby_id, target_date, target_date)

        total_nap = 0
        total_feeds = 0
        total_dirty = 0

        for event in events:
            category = event.get("category")
            metadata = event.get("metadata", {})

            if category == EventCategory.NAP:
                start_str = event.get("start_time")
                end_str = event.get("end_time")
                if start_str and end_str:
                    start_dt = datetime.fromisoformat(start_str.replace('Z', '+00:00'))
                    end_dt = datetime.fromisoformat(end_str.replace('Z', '+00:00'))
                    total_nap += int((end_dt - start_dt).total_seconds() / 60)

            elif category == EventCategory.FEED:
                total_feeds += 1

            elif category == EventCategory.DIAPER:
                condition = metadata.get("condition")
                if condition in ["dirty", "mixed"]:
                    total_dirty += 1

        return DailySummary(
            target_date=target_date,
            total_nap_minutes=total_nap,
            total_feeds=total_feeds,
            total_dirty_diapers=total_dirty
        )

    # ─── Punto de entrada ─────────────────────────────────────────────────────

    def generate_stats(self, baby_id: str, start: date, end: date, category: str, subcategory: str) -> dict | None:
        """Devuelve None si la categoría/subcategoría no existe."""
        handlers = {
            "Sueño": {
                "Todo": self.generate_sleep_overview_stats,
                "Siestas": self.generate_nap_sleep_stats,
                "Nocturno": self.generate_night_sleep_stats,
                "Sueño Nocturno": self.generate_night_sleep_stats,
                "Despertares": self.generate_night_waking_stats,
            },
            "Alimentación": {
                "Todo": self.generate_feed_analytics,
                "Biberón": self.generate_bottle_stats,
                "Lactancia": self.generate_nursing_stats,
                "Sólidos": self.generate_solids_stats,
            },
            "Pañales": {
                "Todo": self.generate_diaper_stats,
                "Mojado": lambda b, s, e: self.generate_diaper_stats(b, s, e, only="wet"),
                "Sucio": lambda b, s, e: self.generate_diaper_stats(b, s, e, only="dirty"),
            },
            "Crecimiento": {
                "Todo": lambda b, s, e: self.generate_growth_stats(b, e, "Peso"),
                "Peso": lambda b, s, e: self.generate_growth_stats(b, e, "Peso"),
                "Altura": lambda b, s, e: self.generate_growth_stats(b, e, "Altura"),
                "Perímetro": lambda b, s, e: self.generate_growth_stats(b, e, "Perímetro"),
            },
        }
        handler = handlers.get(category, {}).get(subcategory)
        if handler is None:
            return None
        return handler(baby_id, start, end)

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

    # ─── Alimentación ─────────────────────────────────────────────────────────

    def _load_feeds(self, baby_id: str, start: date, end: date) -> pd.DataFrame:
        df = _events_df(self.repository.get_events_by_categories(baby_id, ["feed"], start, end), self.tz)
        if df.empty:
            return df

        def kind(meta: dict):
            t = str(meta.get('type') or '').lower()
            if t in ('nursing', 'breast'):
                return 'nursing'
            if t in ('bottle', 'solids'):
                return t
            return None

        def side(meta: dict):
            # App: side = Izquierdo/Derecho/Ambos · Migración CSV: condition = L/R/Both
            raw = str(meta.get('side') or meta.get('condition') or '').strip().lower()
            if raw in ('izquierdo', 'l', 'left'):
                return 'Izquierdo'
            if raw in ('derecho', 'r', 'right'):
                return 'Derecho'
            if raw in ('ambos', 'both'):
                return 'Ambos'
            return None

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
