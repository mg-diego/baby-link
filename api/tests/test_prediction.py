from datetime import date, datetime, timedelta

import pytest

from core.timeutils import parse_ts
from prediction import DEFAULT_CONFIG, predict
from prediction.feedback import compute_biases
from prediction.segmentation import parse_events
from tests.synthetic import MADRID, event, local, make_day, make_history

DOB_10M = date(2025, 8, 15)          # ~10 meses en junio de 2026 -> 2 siestas por edad
FIRST = date(2026, 6, 1)
TODAY = FIRST + timedelta(days=14)


def minutes(a: datetime, b: datetime) -> float:
    return (b - a).total_seconds() / 60


def bedtime(out) -> datetime:
    return parse_ts(next(i for i in out.schedule if i["type"] == "bedtime")["start"])


def naps(out) -> list[dict]:
    return [i for i in out.schedule if i["type"] == "nap"]


def run(rows, now, dob=DOB_10M):
    return predict(rows, dob, now, MADRID)


# Historial base: despierta 7:00, ventanas 150/180, siestas 90/90, noche tras 210 -> dormir 19:00
HISTORY = make_history(FIRST, 14)


def test_learns_regular_baby_exactly():
    out = run(HISTORY + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5))
    assert out.state == "day"
    first, second = naps(out)
    assert abs(minutes(local(TODAY, 9, 30), parse_ts(first["start"]))) <= 2
    assert abs(minutes(local(TODAY, 14), parse_ts(second["start"]))) <= 2
    assert abs(minutes(local(TODAY, 19), bedtime(out))) <= 5


def test_ongoing_nap_does_not_pull_bedtime_earlier():
    """Bug A: la siesta en curso contaba como déficit y adelantaba la noche ~75 min."""
    base = HISTORY + [event("woke_up", local(TODAY, 7)), event("nap", local(TODAY, 9, 30), local(TODAY, 11))]
    ongoing = run(base + [event("nap", local(TODAY, 14))], local(TODAY, 14, 15))
    finished = run(base + [event("nap", local(TODAY, 14), local(TODAY, 15, 30))], local(TODAY, 15, 35))
    assert abs(minutes(bedtime(finished), bedtime(ongoing))) <= 5
    assert abs(minutes(local(TODAY, 19), bedtime(ongoing))) <= 5


def test_short_naps_bring_bedtime_forward():
    base = HISTORY + [event("woke_up", local(TODAY, 7)), event("nap", local(TODAY, 9, 30), local(TODAY, 10, 0))]
    out = run(base + [event("nap", local(TODAY, 12, 30), local(TODAY, 13, 0))], local(TODAY, 13, 5))
    assert bedtime(out) < local(TODAY, 18, 30)


def test_early_morning_before_woke_up_is_logged():
    """Bug B: entre el bed_time y el woke_up salían 'siestas de rescate' en plena noche."""
    rows = make_history(FIRST, 15)  # incluye el bed_time de ayer
    out = run(rows, local(TODAY + timedelta(days=1), 5, 30))
    assert out.state == "night"
    wake = parse_ts(out.wake["start"])
    assert abs(minutes(local(TODAY + timedelta(days=1), 7), wake)) <= 10
    assert all(parse_ts(n["start"]) > wake for n in naps(out))
    assert len(naps(out)) == 2


@pytest.mark.parametrize("true_ww", [170, 190, 240])
def test_profile_learns_the_babys_own_windows(true_ww):
    """Bug C: con ventanas reales de 240' el perfil se quedaba en 150' (los datos fuera de
    ±30 % del valor por edad se descartaban)."""
    rows = make_history(FIRST, 14, windows=(true_ww, 180), noise=10, seed=1)
    out = run(rows + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5))
    first = parse_ts(naps(out)[0]["start"])
    assert abs(minutes(local(TODAY, 7) + timedelta(minutes=true_ww), first)) <= 15


def test_closed_loop_feedback_converges():
    """Con la app guardando `predicted_feedback`, el error de la 1ª siesta se va a ~0."""
    true_ww = 240
    rows = make_history(FIRST, 7, windows=(true_ww, 180))
    errors = []
    for i in range(7, 37):
        day = FIRST + timedelta(days=i)
        wake = local(day, 7)
        rows.append(event("woke_up", wake))
        out = run(rows, wake + timedelta(minutes=5))
        nap = naps(out)[0]
        actual = wake + timedelta(minutes=true_ww)
        errors.append(minutes(parse_ts(nap["start"]), actual))
        meta = {"predicted_start_time": nap["start"], "predicted_end_time": nap["end"],
                "nap_index": nap["index"], "predicted_feedback": nap["predicted_feedback"]}
        rows.append(event("nap", actual, actual + timedelta(minutes=90), meta))
        rows += [r for r in make_day(day, windows=(true_ww, 180)) if r["category"] != "woke_up"][1:]
    assert abs(errors[0]) <= 30
    assert max(abs(e) for e in errors[-10:]) <= 5


def test_newborn_short_windows_are_learned():
    dob = date(2026, 4, 20)  # ~2 meses -> 5 siestas, ventanas de < 60'
    rows = make_history(FIRST, 14, wake=(7, 0), windows=(45,) * 5, naps=(40,) * 5, evening=60)
    out = run(rows + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5), dob=dob)
    assert abs(out.profile.ww_first - 45) <= 3
    assert abs(minutes(local(TODAY, 7, 45), parse_ts(naps(out)[0]["start"]))) <= 3


def test_wake_clock_is_learned_in_local_time_across_dst():
    """El historial cruza el cambio de hora (29-mar-2026). En UTC la media saltaba 1 h."""
    first = date(2026, 3, 15)
    rows = make_history(first, 21, wake=(7, 0))
    bed = local(first + timedelta(days=20), 19)
    out = run(rows, bed + timedelta(hours=2))
    assert out.state == "night"
    assert abs(minutes(local(first + timedelta(days=21), 7), parse_ts(out.wake["start"]))) <= 15


def test_nap_count_is_learned_not_just_age():
    dob = date(2025, 10, 1)  # ~8,5 meses -> 3 siestas por edad
    rows = make_history(FIRST, 14, windows=(150, 180), naps=(90, 90))
    out = run(rows + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5), dob=dob)
    assert out.profile.nap_count == 2
    assert len(naps(out)) == 2


def test_no_naps_toddler_has_no_rescue_nap():
    dob = date(2022, 1, 1)
    rows = make_history(FIRST, 14, windows=(), naps=(), evening=720)
    out = run(rows + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5), dob=dob)
    assert naps(out) == []
    assert abs(minutes(local(TODAY, 19), bedtime(out))) <= 10


def test_nothing_is_predicted_in_the_past():
    # Lleva despierto mucho más de lo normal: la siesta es "ya", marcada como retrasada
    now = local(TODAY, 11)
    out = run(HISTORY + [event("woke_up", local(TODAY, 7))], now)
    first = naps(out)[0]
    assert parse_ts(first["start"]) == now and first["overdue"] is True
    assert first["predicted_feedback"]["overdue"] is True
    assert all(parse_ts(i["start"]) >= now for i in out.schedule)


def test_nap_longer_than_expected():
    now = local(TODAY, 11, 30)  # la siesta de las 9:30 va por 2 h (lo normal: 1h30)
    out = run(HISTORY + [event("woke_up", local(TODAY, 7)), event("nap", local(TODAY, 9, 30))], now)
    assert all(parse_ts(i["start"]) > now for i in out.schedule)
    assert naps(out)[0]["index"] == 2


def test_forgotten_bedtime_does_not_merge_days():
    rows = make_history(FIRST, 14)
    rows = [r for r in rows if not (r["category"] == "bed_time" and r["start_time"].startswith("2026-06-14"))]
    out = run(rows + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5))
    assert [n["index"] for n in naps(out)] == [1, 2]


def test_insufficient_data_counts_only_sleep_events():
    rows = [event("diaper", local(FIRST + timedelta(days=d), h)) for d in range(10) for h in range(8, 20)]
    rows += make_history(FIRST, 5)  # 20 eventos de sueño, pero solo 5 días
    out = run(rows, local(FIRST + timedelta(days=5), 12))
    assert out.insufficient.reason == "insufficient_days"
    assert out.schedule == [] and out.wake is None


# ─── Feedback ─────────────────────────────────────────────────────────────────

def _fb_event(category, actual, predicted, applied, **extra):
    meta = {"predicted_start_time": predicted, "predicted_feedback": {"start_bias_min": applied, **extra}}
    return event(category, actual, metadata=meta)


def test_feedback_is_measured_against_base_prediction():
    base = local(TODAY, 19)
    rows = [
        _fb_event("bed_time", base + timedelta(days=d, minutes=5),
                  (base + timedelta(days=d)).isoformat(), applied=10)
        for d in range(4)
    ]
    biases = compute_biases(parse_events(rows), DEFAULT_CONFIG)
    # error contra lo mostrado = +5, pero ya llevaba +10 aplicado -> sesgo base = 15
    assert biases.bedtime == pytest.approx(DEFAULT_CONFIG.feedback_gain * 15)


def test_feedback_ignores_legacy_and_overdue_predictions():
    base = local(TODAY, 19)
    legacy = [event("bed_time", base + timedelta(days=d, minutes=40),
                    metadata={"predicted_start_time": (base + timedelta(days=d)).isoformat()}) for d in range(5)]
    overdue = [_fb_event("bed_time", base + timedelta(days=d, minutes=40), (base + timedelta(days=d)).isoformat(),
                         applied=0, overdue=True) for d in range(5, 10)]
    assert compute_biases(parse_events(legacy + overdue), DEFAULT_CONFIG).bedtime == 0
