import random
from datetime import date, datetime, timedelta

import pytest

from core.timeutils import parse_ts
from prediction import DEFAULT_CONFIG, predict
from prediction.feedback import compute_biases
from prediction.profile import half_life_for_age, learn_profile
from prediction.segmentation import parse_events, segment_days
from tests.synthetic import MADRID, event, local, make_day, make_history
from tools.backtest import _rows_before
from tools.cohort import BabySpec, Routine, evaluate, simulate

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


def test_short_naps_get_a_rescue_catnap():
    # Dos siestas de 30': sin una siesta extra la noche llegaría a las 16:30
    base = HISTORY + [event("woke_up", local(TODAY, 7)), event("nap", local(TODAY, 9, 30), local(TODAY, 10, 0))]
    out = run(base + [event("nap", local(TODAY, 12, 30), local(TODAY, 13, 0))], local(TODAY, 13, 5))
    rescue = naps(out)
    assert len(rescue) == 1 and rescue[0]["is_catnap"] and rescue[0]["index"] == 3
    assert local(TODAY, 18) <= bedtime(out) <= local(TODAY, 20)


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


def test_unlogged_nap_whose_slot_passed_is_assumed():
    """Guardería: no se sabe cuándo durmió. La siesta cuyo hueco ya pasó no desaparece:
    se queda en su sitio (sin "retrasada") y el resto del día cuenta con ella."""
    now = local(TODAY, 13)
    out = run(HISTORY + [event("woke_up", local(TODAY, 7))], now)
    first, second = naps(out)
    assert first["assumed"] is True and first["overdue"] is False
    assert abs(minutes(local(TODAY, 9, 30), parse_ts(first["start"]))) <= 2
    assert second["assumed"] is False and parse_ts(second["start"]) > now
    assert abs(minutes(local(TODAY, 19), bedtime(out))) <= 10


def test_all_unlogged_naps_keep_bedtime():
    # Por la tarde sin ninguna siesta registrada: la hora de dormir no se adelanta
    now = local(TODAY, 16)
    out = run(HISTORY + [event("woke_up", local(TODAY, 7))], now)
    assert [n["assumed"] for n in naps(out)] == [True, True]
    assert abs(minutes(local(TODAY, 19), bedtime(out))) <= 10
    assert not any(parse_ts(n["start_range"]["earliest"]) == now for n in naps(out))


# ─── Siestas marcadas como no hechas ──────────────────────────────────────────

def test_skipped_nap_moves_to_the_next_one():
    # La de las 9:30 no la hizo: la siguiente es la 2ª, contada desde las 9:30 y no "supuesta"
    now = local(TODAY, 10, 30)
    rows = HISTORY + [event("woke_up", local(TODAY, 7)), event("nap_skipped", local(TODAY, 9, 30))]
    out = run(rows, now)
    first = naps(out)[0]
    assert first["index"] == 2 and first["assumed"] is False and parse_ts(first["start"]) > now
    assert first["basis"]["from"] == "skipped"
    assert parse_ts(first["basis"]["from_time"]) == local(TODAY, 9, 30)


def test_skipped_naps_do_not_count_as_sleep():
    # Por la tarde: con las dos marcadas como no hechas no se supone ninguna y se acuesta antes
    now = local(TODAY, 16)
    base = HISTORY + [event("woke_up", local(TODAY, 7))]
    assumed = run(base, now)
    skipped = run(base + [event("nap_skipped", local(TODAY, 9, 30)), event("nap_skipped", local(TODAY, 14))], now)
    assert all(n["assumed"] for n in naps(assumed))
    assert not any(n.get("assumed") for n in naps(skipped))
    assert bedtime(skipped) < bedtime(assumed)


def test_skipped_rescue_nap_is_not_proposed_again():
    base = HISTORY + [event("woke_up", local(TODAY, 7)), event("nap", local(TODAY, 9, 30), local(TODAY, 10, 0)),
                      event("nap", local(TODAY, 12, 30), local(TODAY, 13, 0))]
    out = run(base + [event("nap_skipped", local(TODAY, 15))], local(TODAY, 15, 5))
    assert naps(out) == []


def test_skip_without_an_open_day_is_ignored():
    rows = HISTORY + [event("nap_skipped", local(TODAY, 3))]
    assert segment_days(parse_events(rows), DEFAULT_CONFIG) == segment_days(parse_events(HISTORY), DEFAULT_CONFIG)


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
    # 10 eventos de sueño, pero solo 2 días
    rows += make_history(FIRST, 2, windows=(120, 150, 150), naps=(60, 60, 40), evening=150)
    out = run(rows, local(FIRST + timedelta(days=2), 12))
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


# ─── Compensación por déficit de siesta (aprendida por bebé) ──────────────────

def _deficit_history(slope: float) -> list[dict]:
    rows = []
    for i, deficit in enumerate([0, 30, 45, -20, 10, 40, 25, -15, 35, 0, 20, 45, -10, 30]):
        rows += make_day(FIRST + timedelta(days=i), naps=(90, 90 - deficit), evening=210 - slope * deficit)
    return rows


@pytest.mark.parametrize("slope", [0.0, 0.8])
def test_deficit_compensation_is_learned(slope):
    base = _deficit_history(slope) + [event("woke_up", local(TODAY, 7)),
                                      event("nap", local(TODAY, 9, 30), local(TODAY, 11))]
    out = run(base + [event("nap", local(TODAY, 14), local(TODAY, 14, 45))], local(TODAY, 14, 50))
    assert out.profile.deficit_slope == pytest.approx(slope * 14 / 19, abs=0.1)
    expected = local(TODAY, 14, 45) + timedelta(minutes=210 - slope * 45)
    assert abs(minutes(expected, bedtime(out))) <= 15


def test_rescue_catnap_is_extra_sleep_not_deficit():
    """Una siesta de rescate ya hecha contaba como ~60' de déficit (se esperaba una siesta
    normal) y adelantaba aún más la noche."""
    base = _deficit_history(0.8) + [event("woke_up", local(TODAY, 7)),
                                    event("nap", local(TODAY, 9, 30), local(TODAY, 10)),
                                    event("nap", local(TODAY, 12, 30), local(TODAY, 13))]
    before = run(base, local(TODAY, 13, 5))
    after = run(base + [event("nap", local(TODAY, 15, 30), local(TODAY, 16))], local(TODAY, 16, 5))
    assert after.profile.expected_nap(3) == 0
    # Dormir 30' más no puede acortar la ventana de tarde respecto a la prevista sin ella
    rescue = naps(before)[0]
    evening_before = minutes(parse_ts(rescue["end"]), bedtime(before))
    evening_after = minutes(local(TODAY, 16), bedtime(after))
    assert evening_after >= evening_before - 5


# ─── Feedback sin sesgo de censura ────────────────────────────────────────────

def test_feedback_uses_base_start_even_when_overdue():
    base = local(TODAY, 19)
    rows = [_fb_event("bed_time", base + timedelta(days=d, minutes=40),
                      (base + timedelta(days=d, minutes=35)).isoformat(),
                      applied=0, overdue=True, base_start=(base + timedelta(days=d)).isoformat())
            for d in range(4)]
    # Lo mostrado era "ahora" (35' tarde), pero la predicción era las 19:00 -> error 40'
    biases = compute_biases(parse_events(rows), DEFAULT_CONFIG)
    assert biases.bedtime == pytest.approx(DEFAULT_CONFIG.feedback_gain * 40)


def test_closed_loop_without_censoring_bias():
    """La app refresca la predicción al abrirla para registrar: si el bebé se duerme tarde,
    lo mostrado ya es "ahora" (overdue). Antes esos días se descartaban y la corrección
    adelantaba las predicciones ~15'. Con `base_start` se mide igual que sin refresco."""
    rng = random.Random(3)
    true_ww, sigma = 180, 25
    rows = make_history(FIRST, 7, windows=(true_ww, 180), noise=sigma, seed=3)
    errors = []
    for i in range(7, 47):
        day = FIRST + timedelta(days=i)
        wake = local(day, 7)
        rows.append(event("woke_up", wake))
        actual = wake + timedelta(minutes=true_ww + rng.gauss(0, sigma))
        errors.append(minutes(parse_ts(naps(run(rows, wake + timedelta(minutes=5)))[0]["start"]), actual))
        logged = naps(run(rows, actual))[0]  # lo que muestra la app en el momento de registrar
        meta = {"predicted_start_time": logged["start"], "predicted_end_time": logged["end"],
                "nap_index": 1, "predicted_feedback": logged["predicted_feedback"]}
        rows.append(event("nap", actual, actual + timedelta(minutes=90), meta))
        rest = make_day(day, windows=(true_ww, 180), noise=sigma, rng=rng)
        rows += [r for r in rest if r["category"] != "woke_up"][1:]
    tail = errors[-20:]
    assert abs(sum(tail) / len(tail)) <= 8


# ─── Comportamientos que se aprenden por bebé ─────────────────────────────────

def _at(rows, instant, dob):
    return predict(_rows_before(rows, instant), dob, instant, MADRID)


def _last(rows, category):
    return parse_ts([r for r in rows if r["category"] == category][-1]["start_time"])


TWO_NAPS = Routine(7 * 60, (180, 210), (75, 75), 240)


@pytest.mark.parametrize("weight", [0.0, 0.8])
def test_wake_clock_vs_night_duration_is_learned(weight):
    """Unos bebés se despiertan a su hora pase lo que pase y otros tras X horas de noche."""
    spec = BabySpec("w", 12, TWO_NAPS, wake_duration_weight=weight, night=660, noise=25, days=28)
    rows, dob = simulate(spec, seed=1)
    out = _at(rows, _last(rows, "bed_time") + timedelta(minutes=5), dob)
    assert out.profile.wake_duration_weight == pytest.approx(max(weight, 0.15), abs=0.2)


def test_routine_bedtime_is_learned():
    """Rutina de dormir a las 20:30 aunque las siestas cambien: manda el reloj, no la ventana."""
    spec = BabySpec("r", 9, Routine(7 * 60, (150, 180), (75, 75), 210), bed_clock=20 * 60 + 30,
                    bed_clock_weight=0.9, noise=25, days=28)
    rows, dob = simulate(spec, seed=2)
    p = _at(rows, _last(rows, "woke_up") + timedelta(minutes=5), dob).profile
    assert p.bed_day_weight + p.bed_clock_weight >= 0.6
    assert abs(p.bed_clock - (20 * 60 + 30)) <= 15


def test_window_driven_bedtime_ignores_the_clock():
    spec = BabySpec("v", 12, TWO_NAPS, noise=25, days=28)
    rows, dob = simulate(spec, seed=4)
    p = _at(rows, _last(rows, "woke_up") + timedelta(minutes=5), dob).profile
    assert p.bed_day_weight + p.bed_clock_weight <= 0.25


def test_each_window_is_learned_separately():
    """Con 3 siestas las ventanas se alargan durante el día (105' -> 135' -> 170')."""
    spec = BabySpec("p", 7, Routine(6 * 60 + 45, (105, 135, 170), (60, 80, 35), 180), noise=10, days=21)
    rows, dob = simulate(spec, seed=0)
    p = _at(rows, _last(rows, "woke_up") + timedelta(minutes=5), dob).profile
    assert p.nap_count == 3
    assert abs(p.window_before(2) - 135) <= 10 and abs(p.window_before(3) - 170) <= 10


def test_nap_count_outside_age_table_is_trusted_with_enough_days():
    """Con 3,3 meses la tabla por edad dice 4-5 siestas; si hace 3 de forma estable, son 3."""
    spec = BabySpec("y", 3.3, Routine(7 * 60, (90, 105, 120), (75, 90, 50), 120), noise=10, days=14)
    rows, dob = simulate(spec, seed=0)
    assert _at(rows, _last(rows, "woke_up") + timedelta(minutes=5), dob).profile.nap_count == 3


def test_daycare_weekdays_and_weekends_get_their_own_schedule():
    spec = BabySpec("d", 15, Routine(7 * 60 + 45, (180, 210), (75, 45), 240),
                    daycare=Routine(6 * 60 + 45, (300,), (120,), 285), days=28)
    rows, dob = simulate(spec, seed=0)
    wakes = [parse_ts(r["start_time"]) for r in rows if r["category"] == "woke_up"]
    saturday = next(w for w in reversed(wakes) if w.astimezone(MADRID).weekday() == 5)
    monday = next(w for w in reversed(wakes) if w.astimezone(MADRID).weekday() == 0)
    sat = _at(rows, saturday + timedelta(minutes=5), dob).profile
    mon = _at(rows, monday + timedelta(minutes=5), dob).profile
    assert (sat.weekend, sat.nap_count) == (True, 2)
    assert (mon.weekend, mon.nap_count) == (False, 1)
    assert abs(mon.wake_clock - (6 * 60 + 45)) <= 15
    assert abs(sat.wake_clock - (7 * 60 + 45)) <= 20


def test_same_schedule_every_day_is_not_split():
    """Sin guardería, entre semana y fin de semana salen prácticamente iguales."""
    days = segment_days(parse_events(make_history(FIRST, 21, noise=15, seed=5)), DEFAULT_CONFIG)
    now = local(FIRST + timedelta(days=21), 6)
    sat = learn_profile(days, DOB_10M, now, MADRID, DEFAULT_CONFIG, target_day=date(2026, 6, 20))
    mon = learn_profile(days, DOB_10M, now, MADRID, DEFAULT_CONFIG, target_day=date(2026, 6, 22))
    assert (sat.weekend, mon.weekend) == (True, False)
    assert abs(sat.ww_first - mon.ww_first) <= 5
    assert abs(sat.wake_clock - mon.wake_clock) <= 5
    assert abs(sat.bed_clock - mon.bed_clock) <= 5


def test_young_babies_forget_faster():
    assert half_life_for_age(60, DEFAULT_CONFIG) == DEFAULT_CONFIG.half_life_young_days
    assert half_life_for_age(300, DEFAULT_CONFIG) == DEFAULT_CONFIG.half_life_days
    assert DEFAULT_CONFIG.half_life_young_days < half_life_for_age(135, DEFAULT_CONFIG) < DEFAULT_CONFIG.half_life_days


# ─── Margen de las predicciones ───────────────────────────────────────────────

def _width(item) -> float:
    return minutes(parse_ts(item["start_range"]["earliest"]), parse_ts(item["start_range"]["latest"]))


def test_every_prediction_has_a_range_around_it():
    out = run(make_history(FIRST, 14, noise=15, seed=2) + [event("woke_up", local(TODAY, 7))], local(TODAY, 7, 5))
    for item in out.schedule + [out.wake]:
        rng = item["start_range"]
        assert parse_ts(rng["earliest"]) <= parse_ts(item["start"]) <= parse_ts(rng["latest"])
    # Lo que está más lejos (la noche) es más incierto que la próxima siesta
    assert _width(out.schedule[-1]) > _width(naps(out)[0])


def test_irregular_baby_gets_wider_range():
    def first_width(noise):
        rows = make_history(FIRST, 14, noise=noise, seed=2) + [event("woke_up", local(TODAY, 7))]
        return _width(naps(run(rows, local(TODAY, 7, 5)))[0])
    assert first_width(35) > 1.5 * first_width(8)


def test_overdue_range_starts_now():
    now = local(TODAY, 11)
    first = naps(run(HISTORY + [event("woke_up", local(TODAY, 7))], now))[0]
    assert parse_ts(first["start_range"]["earliest"]) == now
    assert parse_ts(first["predicted_feedback"]["base_start"]) < now


# ─── Grupo de bebés sintéticos (red de seguridad de calidad) ─────────────────

def test_cohort_quality_guard():
    """El motor tiene que ganar con holgura a "como ayer" en todo el grupo y no empeorar
    respecto a lo medido al ajustar los parámetros (ver tools/cohort.py). Si un cambio
    sube la puntuación, mídelo con `python -m tools.cohort --compare` antes de relajar esto."""
    res = evaluate(seeds=(0,))
    assert res["engine"]["score"] <= 21.0
    assert res["engine"]["score"] < 0.75 * res["baseline"]["score"]
    for name, metric in res["engine"]["metrics"].items():
        if metric["coverage"] is not None:
            assert 0.35 <= metric["coverage"] <= 0.65, name


# ─── Explicación de cada predicción (basis) ───────────────────────────────────

def test_every_prediction_explains_where_it_comes_from():
    wake = local(TODAY, 7)
    out = run(HISTORY + [event("woke_up", wake)], local(TODAY, 7, 5))
    first, second = naps(out)[:2]
    b1, b2 = first["basis"], second["basis"]
    assert (b1["from"], parse_ts(b1["from_time"]), b1["from_predicted"]) == ("wake", wake, False)
    assert abs(minutes(wake, parse_ts(first["start"])) - b1["window_min"]) <= 1
    assert (b2["from"], parse_ts(b2["from_time"]), b2["from_predicted"]) == ("nap", parse_ts(first["end"]), True)
    assert b1["days"] == 14 and b1["nap_count"] == 2

    bed = out.schedule[-1]["basis"]
    assert bed["from"] == "nap" and parse_ts(bed["from_time"]) == parse_ts(naps(out)[-1]["end"])
    assert 0 <= bed["routine_weight"] + bed["day_length_weight"] <= 1
    assert out.wake["basis"]["bed_predicted"] is True
    assert parse_ts(out.wake["basis"]["bed"]) == bedtime(out)


def test_night_wake_basis_uses_real_bedtime():
    bed = local(TODAY, 20)
    out = run(HISTORY + [event("woke_up", local(TODAY, 7)), event("bed_time", bed)], local(TODAY, 21))
    basis = out.wake["basis"]
    assert parse_ts(basis["bed"]) == bed and basis["bed_predicted"] is False
    assert abs(minutes(bed, parse_ts(basis["by_night"])) - basis["night_min"]) <= 1
