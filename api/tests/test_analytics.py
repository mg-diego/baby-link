from datetime import date

import pytest

from services.analytics import STAT_CODES, AnalyticsService
from tests.synthetic import MADRID, event, local, make_history

FIRST, LAST = date(2026, 5, 1), date(2026, 5, 10)


class _Repo:
    tz = MADRID

    def __init__(self, rows):
        self.rows = sorted(rows, key=lambda r: r["start_time"])

    def get_events_by_categories(self, baby_id, categories, start, end, extra_hours_after=0):
        return [r for r in self.rows if r["category"] in categories]

    def get_events_until(self, baby_id, category, end):
        return [r for r in self.rows if r["category"] == category]

    def get_events_by_date_range(self, baby_id, start, end):
        return self.rows


@pytest.fixture(scope="module")
def service():
    rows = make_history(FIRST, 10)
    rows += [event("night_waking", local(date(2026, 5, d), 2), local(date(2026, 5, d), 2, 20)) for d in range(2, 10)]
    rows += [event("feed", local(date(2026, 5, d), 9), metadata={"type": "bottle", "amount_ml": 120}) for d in range(1, 10)]
    rows += [event("feed", local(date(2026, 5, d), 12), local(date(2026, 5, d), 12, 15),
                   metadata={"type": "nursing", "side": "Izquierdo"}) for d in range(1, 10)]
    rows += [event("feed", local(date(2026, 5, d), 13), metadata={"type": "solids"}) for d in range(1, 10)]
    rows += [event("diaper", local(date(2026, 5, d), 10), metadata={"condition": c})
             for d in range(1, 10) for c in ("wet", "mixed", "dirty")]
    rows += [event("growth", local(date(2026, 5, d), 11), metadata={"weight_kg": 8 + d / 10, "height_cm": 70 + d,
                                                                    "head_cm": 44}) for d in (1, 5, 9)]
    return AnalyticsService(_Repo(rows))


@pytest.mark.parametrize("category, subcategory", [(c, s) for c, subs in STAT_CODES.items() for s in subs])
def test_every_stat_code_produces_cards_and_charts(service, category, subcategory):
    out = service.generate_stats("b", FIRST, LAST, category, subcategory)
    assert out["summary_cards"], (category, subcategory)
    assert out["charts"]
    for chart in out["charts"]:
        assert {"id", "title", "type", "data"} <= chart.keys()


def test_unknown_codes_return_none(service):
    assert service.generate_stats("b", FIRST, LAST, "sleep", "nope") is None

