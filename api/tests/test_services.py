from datetime import date, datetime

from core.pagination import fetch_all
from core.timeutils import UTC
from services import event_service as event_service_module
from services.event_service import EventService
from services.home_assistant_service import HomeAssistantService
from tests.fakes import FakeBabyRepository, FakeEventRepository
from tests.synthetic import MADRID, event, local


def _service(rows):
    return EventService(FakeEventRepository([{**r, "baby_id": "b"} for r in rows]))


def test_valid_dates_use_local_day():
    # 23:30 UTC del 10 de marzo son las 00:30 del 11 en Madrid
    service = _service([{"category": "bath", "start_time": "2026-03-10T23:30:00+00:00"}])
    assert service.get_valid_event_dates("b", MADRID) == ["2026-03-11"]


def test_last_events_mixed_diaper_counts_as_wet_and_dirty():
    service = _service([
        {"category": "diaper", "start_time": "2026-03-10T08:00:00Z", "metadata": {"condition": "wet"}},
        {"category": "diaper", "start_time": "2026-03-10T10:00:00Z", "metadata": {"condition": "mixed"}},
    ])
    last = service.get_last_events_by_category("b")
    assert last["diaper_wet"] == last["diaper_dirty"] == last["diaper"] == "2026-03-10T10:00:00Z"


def test_last_events_finds_rare_categories_outside_recent_window(monkeypatch):
    monkeypatch.setattr(event_service_module, "RECENT_WINDOW", 3)
    rows = [{"category": "temperature", "start_time": "2026-01-01T08:00:00Z"}]
    rows += [{"category": "bath", "start_time": f"2026-03-0{d}T08:00:00Z"} for d in range(1, 6)]
    last = _service(rows).get_last_events_by_category("b")
    assert last["temperature"] == "2026-01-01T08:00:00Z"
    assert last["bath"] == "2026-03-05T08:00:00Z"


def test_fetch_all_paginates():
    rows = [{"n": i} for i in range(2500)]
    calls = []

    class Query:
        def range(self, start, end):
            calls.append((start, end))
            self.slice = rows[start:end + 1]
            return self

        def execute(self):
            return type("R", (), {"data": self.slice})()

    assert len(fetch_all(Query)) == 2500
    assert calls == [(0, 999), (1000, 1999), (2000, 2999)]


def _ha(rows, now):
    babies = FakeBabyRepository([{"id": "b", "user_id": "u", "name": "Bebé", "dob": "2025-08-01"}])
    events = FakeEventRepository([{**r, "baby_id": "b"} for r in rows])
    return HomeAssistantService(babies, events, MADRID, clock=lambda: now)


def test_home_assistant_counts_night_and_naps_since_midnight():
    today, yesterday = date(2026, 3, 11), date(2026, 3, 10)
    rows = [
        event("bed_time", local(yesterday, 20)),
        event("night_waking", local(today, 3), local(today, 3, 30)),
        event("woke_up", local(today, 7)),
        event("nap", local(today, 9, 30), local(today, 11)),
        event("feed", local(today, 8), metadata={"type": "bottle", "amount_ml": 120}),
        event("diaper", local(today, 8, 5), metadata={"condition": "dirty"}),
    ]
    summary = _ha(rows, local(today, 12)).get_summary("b")
    # 00:00-07:00 (420) - despertar 30 + siesta 90
    assert summary["today_summary"] == {"total_sleep_mins": 480, "total_feeds": 1, "total_diapers": 1}
    assert summary["current_state"]["is_sleeping"] is False
    assert summary["last_events"]["last_feed"]["amount_ml"] == 120


def test_home_assistant_state():
    today = date(2026, 3, 11)
    bed = local(today, 20)
    summary = _ha([event("woke_up", local(today, 7)), event("bed_time", bed)], local(today, 22)).get_summary("b")
    assert summary["current_state"] == {"is_sleeping": True, "current_sleep_type": "Noche",
                                        "sleeping_since": event("bed_time", bed)["start_time"]}

    waking = _ha([event("bed_time", bed), event("night_waking", local(today, 23))], local(today, 23, 10)).get_summary("b")
    assert waking["current_state"]["is_sleeping"] is False

    nap = _ha([event("woke_up", local(today, 7)), event("nap", local(today, 10))], local(today, 10, 30)).get_summary("b")
    assert nap["current_state"]["current_sleep_type"] == "Siesta"


# ─── Normalización de metadatos antiguos ──────────────────────────────────────

import pytest  # noqa: E402

from tools.normalize_legacy_metadata import normalize, revert  # noqa: E402


@pytest.mark.parametrize("category, before, expected", [
    ("diaper", {"condition": "pee", "ui_condition": "Mojado"}, {"condition": "wet"}),
    ("diaper", {"condition": "poo:large", "ui_condition": "yellow"}, {"condition": "dirty"}),
    ("diaper", {"condition": "both, pee:medium poo:small"}, {"condition": "mixed"}),
    ("diaper", {"condition": "seco", "ui_condition": "Seco"}, {"condition": "clean"}),
    ("diaper", {"condition": None, "ui_condition": "Mojado"}, {"condition": "wet"}),
    ("feed", {"type": "nursing", "condition": "L"}, {"side": "Izquierdo"}),
    ("feed", {"type": "breast", "condition": "Both"}, {"type": "nursing", "side": "Ambos"}),
])
def test_normalize_legacy_metadata_is_reversible(category, before, expected):
    after = normalize(category, before)
    assert {k: after[k] for k in expected} == expected
    assert revert(after) == before


@pytest.mark.parametrize("category, meta", [
    ("diaper", {"condition": "wet"}),
    ("diaper", {}),                                # sin datos: no se inventa nada
    ("diaper", {"ui_condition": "37.7°C"}),
    ("feed", {"type": "nursing", "side": "Derecho"}),
    ("feed", {"type": "bottle", "amount_ml": 120}),
])
def test_normalize_leaves_valid_or_unknown_data_alone(category, meta):
    assert normalize(category, meta) is None
