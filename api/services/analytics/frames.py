"""Carga de eventos en DataFrames en hora local y agregados por día."""
from datetime import date

import pandas as pd

from services.analytics.formatting import _fmt_day


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
