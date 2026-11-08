from tests.conftest import HA_KEY, USER_A, USER_B, auth

NAP = {"baby_id": "baby-a", "category": "nap", "start_time": "2026-03-01T10:00:00Z"}


def _add_event(events, **overrides):
    return events.save({**NAP, "end_time": None, "metadata": {}, **overrides})


# ─── Autenticación y autorización ─────────────────────────────────────────────

def test_requires_token(client):
    response = client.get("/events/last/baby-a")
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_cannot_read_other_users_baby(client):
    assert client.get("/events/last/baby-b", headers=auth(USER_A)).status_code == 404
    assert client.get("/events/last/baby-b", headers=auth(USER_B)).status_code == 200


def test_unknown_baby_is_404(client):
    assert client.get("/analytics/nope/sleep-prediction", headers=auth()).status_code == 404


def test_cannot_list_babies_of_other_user(client):
    assert client.get(f"/babies/{USER_B}", headers=auth(USER_A)).status_code == 403
    response = client.get(f"/babies/{USER_A}", headers=auth(USER_A))
    assert [b["id"] for b in response.json()["data"]] == ["baby-a"]


def test_register_baby_owner_comes_from_token(client, babies):
    response = client.post("/babies", headers=auth(USER_A),
                           json={"name": "Nuevo", "dob": "2026-01-01", "user_id": USER_B})
    assert response.status_code == 200
    assert response.json()["data"]["user_id"] == USER_A


def test_cannot_register_event_for_other_users_baby(client, events):
    response = client.post("/events/register", headers=auth(USER_B), json=NAP)
    assert response.status_code == 404
    assert events.events == []


def test_cannot_edit_or_delete_other_users_event(client, events):
    event = _add_event(events)
    assert client.patch(f"/events/{event['id']}", headers=auth(USER_B), json={"notes": "x"}).status_code == 404
    assert client.delete(f"/events/{event['id']}", headers=auth(USER_B)).status_code == 404
    assert events.get_by_id(event["id"]) is not None


def test_auth_disabled_allows_legacy_clients(client, settings):
    from dataclasses import replace
    import dependencies as deps
    from main import app
    app.dependency_overrides[deps.get_settings] = lambda: replace(settings, auth_enabled=False)
    assert client.get("/events/last/baby-a").status_code == 200


# ─── Errores ──────────────────────────────────────────────────────────────────

def test_delete_missing_event_is_404_not_400(client):
    response = client.delete("/events/missing", headers=auth())
    assert response.status_code == 404
    assert response.json()["detail"] == "El evento no existe"


def test_unhandled_errors_do_not_leak_details(client, events):
    def boom(*args, **kwargs):
        raise RuntimeError("password=secret connection string")
    events.get_latest = boom
    response = client.get("/events/last/baby-a", headers=auth())
    assert response.status_code == 500
    assert "secret" not in response.text


def test_insufficient_data_prediction_is_200_with_empty_list(client):
    response = client.get("/analytics/baby-a/sleep-prediction", headers=auth())
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "insufficient_data"
    assert body["data"] == []
    assert body["detail"]["reason"] == "insufficient_events"

    wake = client.get("/analytics/baby-a/wake-prediction", headers=auth()).json()
    assert wake["status"] == "insufficient_data" and wake["data"] is None


# ─── Validación de eventos ────────────────────────────────────────────────────

def test_event_end_before_start_is_rejected(client):
    response = client.post("/events/register", headers=auth(),
                           json={**NAP, "end_time": "2026-03-01T09:00:00Z"})
    assert response.status_code == 422


def test_atomic_event_cannot_have_end_time(client):
    response = client.post("/events/register", headers=auth(), json={
        "baby_id": "baby-a", "category": "bed_time",
        "start_time": "2026-03-01T19:00:00Z", "end_time": "2026-03-01T20:00:00Z",
    })
    assert response.status_code == 400


def test_invalid_start_time_is_422_not_500(client):
    response = client.post("/events/register", headers=auth(), json={**NAP, "start_time": "ayer"})
    assert response.status_code == 422


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


def test_update_keeps_legacy_metadata_editable(client, events):
    # Pañal importado del CSV con un formato antiguo: cambiar solo la hora debe funcionar
    diaper = _add_event(events, category="diaper", metadata={"condition": "Both, pee:medium"})
    response = client.patch(f"/events/{diaper['id']}", headers=auth(), json={"start_time": "2026-03-01T10:30:00Z"})
    assert response.status_code == 200


# ─── Home Assistant ───────────────────────────────────────────────────────────

def test_home_assistant_requires_api_key(client):
    assert client.get("/homeassistant/baby-a/summary").status_code == 401
    assert client.get("/homeassistant/baby-a/summary", headers={"X-API-Key": "mala"}).status_code == 401
    response = client.get("/homeassistant/baby-a/summary", headers={"X-API-Key": HA_KEY})
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Bebé A"
