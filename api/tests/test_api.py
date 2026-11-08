from datetime import timedelta

import pytest

from core.timeutils import utc_now
from tests.conftest import HA_KEY, USER_A, USER_B, auth
from tests.synthetic import MADRID, make_history
from tests.test_analytics import _Repo

NAP = {"category": "nap", "start_time": "2026-03-01T10:00:00Z"}


def _add_event(events, **overrides):
    return events.save({**NAP, "baby_id": "baby-a", "end_time": None, "metadata": {}, **overrides})


@pytest.fixture
def analytics_override(events):
    import dependencies as deps
    from main import app
    from services.analytics import AnalyticsService
    app.dependency_overrides[deps.get_analytics_service] = lambda: AnalyticsService(_Repo(events.events))


# ─── Autenticación y autorización ─────────────────────────────────────────────

def test_requires_token(client):
    response = client.get("/babies/baby-a/events/last")
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_cannot_read_other_users_baby(client):
    assert client.get("/babies/baby-b/events/last", headers=auth(USER_A)).status_code == 404
    assert client.get("/babies/baby-b/events/last", headers=auth(USER_B)).status_code == 200


def test_unknown_baby_is_404(client):
    assert client.get("/babies/nope/predictions", headers=auth()).status_code == 404


def test_me_babies_lists_only_own(client):
    body = client.get("/me/babies", headers=auth(USER_A)).json()
    assert body["status"] == "success"
    assert [b["id"] for b in body["data"]] == ["baby-a"]


def test_register_baby_owner_comes_from_token(client):
    response = client.post("/babies", headers=auth(USER_A),
                           json={"name": "Nuevo", "dob": "2026-01-01", "user_id": USER_B})
    assert response.status_code == 200
    assert response.json()["data"]["user_id"] == USER_A


def test_create_event_uses_baby_from_url(client, events):
    response = client.post("/babies/baby-a/events", headers=auth(), json={**NAP, "baby_id": "baby-b"})
    assert response.status_code == 200
    assert response.json()["data"]["baby_id"] == "baby-a"


def test_cannot_register_event_for_other_users_baby(client, events):
    assert client.post("/babies/baby-a/events", headers=auth(USER_B), json=NAP).status_code == 404
    assert events.events == []


def test_cannot_edit_or_delete_other_users_event(client, events):
    event = _add_event(events)
    assert client.patch(f"/events/{event['id']}", headers=auth(USER_B), json={"notes": "x"}).status_code == 404
    assert client.delete(f"/events/{event['id']}", headers=auth(USER_B)).status_code == 404
    assert events.get_by_id(event["id"]) is not None


def test_stats_require_ownership(client, analytics_override):
    params = {"start_date": "2026-01-01", "end_date": "2026-01-31", "category": "sleep"}
    assert client.get("/babies/baby-a/stats", headers=auth(USER_B), params=params).status_code == 404


# ─── Errores ──────────────────────────────────────────────────────────────────

def test_delete_missing_event_is_404_not_400(client):
    response = client.delete("/events/missing", headers=auth())
    assert response.status_code == 404
    assert response.json()["detail"] == "El evento no existe"


def test_delete_returns_deleted_event(client, events):
    event = _add_event(events)
    body = client.delete(f"/events/{event['id']}", headers=auth()).json()
    assert body["status"] == "success" and body["data"]["id"] == event["id"]


def test_unhandled_errors_do_not_leak_details(client, events):
    def boom(*args, **kwargs):
        raise RuntimeError("password=secret connection string")
    events.get_latest = boom
    response = client.get("/babies/baby-a/events/last", headers=auth())
    assert response.status_code == 500
    assert "secret" not in response.text


# ─── Validación de eventos ────────────────────────────────────────────────────

def test_event_end_before_start_is_rejected(client):
    response = client.post("/babies/baby-a/events", headers=auth(), json={**NAP, "end_time": "2026-03-01T09:00:00Z"})
    assert response.status_code == 422


def test_atomic_event_cannot_have_end_time(client):
    response = client.post("/babies/baby-a/events", headers=auth(), json={
        "category": "bed_time", "start_time": "2026-03-01T19:00:00Z", "end_time": "2026-03-01T20:00:00Z",
    })
    assert response.status_code == 400


def test_invalid_start_time_is_422_not_500(client):
    assert client.post("/babies/baby-a/events", headers=auth(), json={**NAP, "start_time": "ayer"}).status_code == 422


def test_invalid_metadata_is_400_with_readable_message(client):
    response = client.post("/babies/baby-a/events", headers=auth(),
                           json={"category": "feed", "start_time": "2026-03-01T18:00:00Z", "metadata": {"type": "pizza"}})
    assert response.status_code == 400
    assert "'type'" in response.json()["detail"]


def test_update_validates_resulting_state(client, events):
    bed = _add_event(events, category="bed_time", start_time="2026-03-01T19:00:00Z")
    response = client.patch(f"/events/{bed['id']}", headers=auth(), json={"end_time": "2026-03-01T20:00:00Z"})
    assert response.status_code == 400

    nap = _add_event(events, end_time="2026-03-01T11:00:00Z")
    response = client.patch(f"/events/{nap['id']}", headers=auth(), json={"start_time": "2026-03-01T12:00:00Z"})
    assert response.status_code == 400  # el inicio quedaría después del fin

    feed = _add_event(events, category="feed", metadata={"type": "bottle"})
    response = client.patch(f"/events/{feed['id']}", headers=auth(), json={"metadata": {"type": "pizza"}})
    assert response.status_code == 400


def test_update_can_clear_nullable_fields(client, events):
    nap = _add_event(events, end_time="2026-03-01T11:00:00Z", notes="hola")
    response = client.patch(f"/events/{nap['id']}", headers=auth(), json={"notes": None, "end_time": None})
    assert response.status_code == 200
    assert events.get_by_id(nap["id"])["notes"] is None
    assert events.get_by_id(nap["id"])["end_time"] is None


def test_update_keeps_old_events_editable(client, events):
    # Pañal antiguo sin condición (no cumple el esquema actual): cambiar solo la hora debe funcionar
    diaper = _add_event(events, category="diaper", metadata={})
    response = client.patch(f"/events/{diaper['id']}", headers=auth(), json={"start_time": "2026-03-01T10:30:00Z"})
    assert response.status_code == 200


# ─── Lecturas ─────────────────────────────────────────────────────────────────

def test_event_dates_use_each_babys_timezone(client, events):
    _add_event(events, category="bath", start_time="2026-03-11T03:00:00+00:00")
    assert client.get("/babies/baby-a/events/dates", headers=auth()).json()["data"] == ["2026-03-11"]

    # Cambiar la zona invalida la caché: a las 03:00 UTC en Nueva York aún es el día 10
    assert client.patch("/babies/baby-a", headers=auth(), json={"timezone": "America/New_York"}).status_code == 200
    assert client.get("/babies/baby-a/events/dates", headers=auth()).json()["data"] == ["2026-03-10"]


def test_invalid_timezone_is_rejected(client):
    assert client.patch("/babies/baby-a", headers=auth(), json={"timezone": "Marte/Base"}).status_code == 422


def test_last_events_envelope(client, events):
    _add_event(events, category="bath", start_time="2026-03-01T18:00:00Z")
    body = client.get("/babies/baby-a/events/last", headers=auth()).json()
    assert body == {"status": "success", "data": {"bath": "2026-03-01T18:00:00Z"}}


def test_stats_with_codes(client, events, analytics_override):
    for row in make_history(utc_now().date() - timedelta(days=5), 5):
        events.save({**row, "baby_id": "baby-a"})
    params = {"start_date": "2026-01-01", "end_date": "2026-12-31"}
    response = client.get("/babies/baby-a/stats", headers=auth(), params={**params, "category": "sleep", "subcategory": "naps"})
    assert response.status_code == 200 and response.json()["data"]["summary_cards"]
    assert client.get("/babies/baby-a/stats", headers=auth(), params={**params, "category": "Sueño"}).status_code == 400


# ─── Predicciones ─────────────────────────────────────────────────────────────

def test_predictions_insufficient(client):
    response = client.get("/babies/baby-a/predictions", headers=auth())
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "insufficient_data"
    assert body["data"] == {"schedule": [], "wake": None}
    assert body["detail"]["reason"] == "insufficient_events"


def test_predictions_combined(client, events):
    first = (utc_now().astimezone(MADRID) - timedelta(days=10)).date()
    for row in make_history(first, 10):
        events.save({**row, "baby_id": "baby-a"})
    body = client.get("/babies/baby-a/predictions", headers=auth()).json()
    assert body["status"] == "success"
    assert body["data"]["schedule"][-1]["type"] == "bedtime"
    assert body["data"]["wake"]["type"] == "woke_up"
    assert "predicted_feedback" in body["data"]["wake"]


# ─── Home Assistant ───────────────────────────────────────────────────────────

def test_home_assistant_requires_api_key(client):
    assert client.get("/homeassistant/baby-a/summary").status_code == 401
    assert client.get("/homeassistant/baby-a/summary", headers={"X-API-Key": "mala"}).status_code == 401
    response = client.get("/homeassistant/baby-a/summary", headers={"X-API-Key": HA_KEY})
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Bebé A"
