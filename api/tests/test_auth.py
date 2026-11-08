import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from core.auth import TokenVerifier
from core.errors import UnauthorizedError
from tests.conftest import JWT_SECRET, SUPABASE_URL, make_token


class _StaticJwks:
    def __init__(self, key):
        self._key = key

    def get_signing_key_from_jwt(self, token):
        return type("Key", (), {"key": self._key})()


def test_hs256_with_secret():
    verifier = TokenVerifier(SUPABASE_URL, JWT_SECRET, jwks_client=object())
    assert verifier.verify(make_token("user-1")) == "user-1"


@pytest.mark.parametrize("token_kwargs, message", [
    ({"secret": "otro-secreto-distinto-de-32-bytes!!"}, "Token no válido"),
    ({"exp_in": -10}, "Sesión caducada"),
    ({"aud": "anon"}, "Token no válido"),
    ({"iss": "https://otro-proyecto.supabase.co/auth/v1"}, "Token no válido"),
])
def test_hs256_rejects_bad_tokens(token_kwargs, message):
    verifier = TokenVerifier(SUPABASE_URL, JWT_SECRET, jwks_client=object())
    with pytest.raises(UnauthorizedError, match=message):
        verifier.verify(make_token("user-1", **token_kwargs))


def test_garbage_token():
    verifier = TokenVerifier(SUPABASE_URL, JWT_SECRET, jwks_client=object())
    with pytest.raises(UnauthorizedError):
        verifier.verify("no-es-un-jwt")


def test_es256_via_jwks():
    private = ec.generate_private_key(ec.SECP256R1())
    token = jwt.encode(
        {"sub": "user-2", "aud": "authenticated", "iss": f"{SUPABASE_URL}/auth/v1", "exp": int(time.time()) + 60},
        private, algorithm="ES256",
    )
    verifier = TokenVerifier(SUPABASE_URL, None, jwks_client=_StaticJwks(private.public_key()))
    assert verifier.verify(token) == "user-2"

    other = ec.generate_private_key(ec.SECP256R1())
    verifier = TokenVerifier(SUPABASE_URL, None, jwks_client=_StaticJwks(other.public_key()))
    with pytest.raises(UnauthorizedError):
        verifier.verify(token)


def test_hs256_without_secret_uses_remote_lookup_and_caches():
    calls = []

    def lookup(token):
        calls.append(token)
        return "user-3"

    verifier = TokenVerifier(SUPABASE_URL, None, remote_lookup=lookup, jwks_client=object())
    token = make_token("user-3", secret="cualquiera-que-no-conocemos-localmente")
    assert verifier.verify(token) == "user-3"
    assert verifier.verify(token) == "user-3"
    assert len(calls) == 1  # la segunda vez sale de caché


def test_remote_lookup_rejection():
    def lookup(token):
        raise RuntimeError("invalid JWT")

    verifier = TokenVerifier(SUPABASE_URL, None, remote_lookup=lookup, jwks_client=object())
    with pytest.raises(UnauthorizedError):
        verifier.verify(make_token("user-3"))
