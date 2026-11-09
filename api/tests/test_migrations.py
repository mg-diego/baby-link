"""La BD tiene su propia lista de categorías (CHECK en baby_events): si la API acepta una
que la BD no conoce, el alta falla en producción con un 500."""
import re
from pathlib import Path

from models.event_models import EventCategory

MIGRATIONS = Path(__file__).resolve().parents[2] / "supabase" / "migrations"


def _latest_category_check() -> set[str]:
    for path in sorted(MIGRATIONS.glob("*.sql"), reverse=True):
        sql = path.read_text(encoding="utf-8")
        match = re.search(r"baby_events_category_check\s+check\s*\(\s*category\s+in\s*\((.*?)\)", sql,
                          re.IGNORECASE | re.DOTALL)
        if match:
            return set(re.findall(r"'([^']+)'", match.group(1)))
    raise AssertionError("Ninguna migración define baby_events_category_check")


def test_db_category_check_matches_api_enum():
    assert _latest_category_check() == {c.value for c in EventCategory}
