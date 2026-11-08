"""Utilidades de fechas. Regla: dentro de la API todo `datetime` es *aware* y en UTC;
la zona local solo se usa para decidir a qué día pertenece algo o qué hora de reloj es."""
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

UTC = timezone.utc


def utc_now() -> datetime:
    return datetime.now(UTC)


def parse_ts(value) -> datetime | None:
    """ISO-8601 (con 'Z', con offset o sin zona) -> datetime aware en UTC.
    Los valores sin zona se interpretan como UTC (así los guarda la app)."""
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        text = str(value).strip()
        if text.endswith(("Z", "z")):
            text = text[:-1] + "+00:00"
        dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def to_iso_z(dt: datetime) -> str:
    """Formato que consume la app: 2026-01-31T07:15:00Z."""
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def local_date(dt: datetime, tz: ZoneInfo) -> date:
    return dt.astimezone(tz).date()


def local_midnight_utc(day: date, tz: ZoneInfo) -> datetime:
    return datetime.combine(day, time.min, tzinfo=tz).astimezone(UTC)


def local_range_utc(start: date, end: date, tz: ZoneInfo, extra_hours_after: int = 0) -> tuple[datetime, datetime]:
    """[start 00:00, end+1 00:00 + extra) en hora local, expresado en UTC."""
    return (
        local_midnight_utc(start, tz),
        local_midnight_utc(end + timedelta(days=1), tz) + timedelta(hours=extra_hours_after),
    )
