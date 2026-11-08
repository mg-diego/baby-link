import os
import time

# main.py valida la configuración al importarse: valores ficticios para los tests
os.environ.setdefault("SUPABASE_URL", "https://test-project.supabase.co")
os.environ.setdefault("SUPABASE_KEY", "test-service-key")

import jwt
import pytest
from fastapi.testclient import TestClient

from core.auth import TokenVerifier
from core.config import Settings
from tests.fakes import FakeBabyRepository, FakeEventRepository

SUPABASE_URL = "https://test-project.supabase.co"
JWT_SECRET = "test-secret-with-enough-length-for-hs256"
HA_KEY = "ha-test-key"
USER_A = "user-a"
USER_B = "user-b"


def make_token(sub: str, secret: str = JWT_SECRET, exp_in: int = 3600, **extra) -> str:
    claims = {"sub": sub, "aud": "authenticated", "iss": f"{SUPABASE_URL}/auth/v1",
              "exp": int(time.time()) + exp_in, **extra}
    return jwt.encode(claims, secret, algorithm="HS256")


def auth(sub: str = USER_A) -> dict:
    return {"Authorization": f"Bearer {make_token(sub)}"}


@pytest.fixture(autouse=True)
def _clear_owner_cache():
    from services import access_service
    access_service._owner_cache.clear()
    yield
    access_service._owner_cache.clear()


@pytest.fixture
def settings():
    return Settings(
        supabase_url=SUPABASE_URL, supabase_key="x", supabase_jwt_secret=JWT_SECRET,
        auth_enabled=True, home_assistant_api_key=HA_KEY, timezone="Europe/Madrid", cors_origins=("*",),
    )


@pytest.fixture
def babies():
    return FakeBabyRepository([
        {"id": "baby-a", "user_id": USER_A, "name": "Bebé A", "dob": "2025-08-01", "photo_url": None},
        {"id": "baby-b", "user_id": USER_B, "name": "Bebé B", "dob": "2025-08-01", "photo_url": None},
    ])


@pytest.fixture
def events():
    return FakeEventRepository()


@pytest.fixture
def client(settings, babies, events):
    import dependencies as deps
    from main import app

    verifier = TokenVerifier(SUPABASE_URL, JWT_SECRET, jwks_client=object())
    app.dependency_overrides = {
        deps.get_settings: lambda: settings,
        deps.get_token_verifier: lambda: verifier,
        deps.get_baby_repository: lambda: babies,
        deps.get_event_repository: lambda: events,
    }
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides = {}
