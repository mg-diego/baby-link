"""Verificación de los JWT de Supabase Auth que envía la app.

Orden de preferencia:
1. Claves asimétricas (ES256/RS256, las de los proyectos nuevos): se validan en local
   contra el JWKS público del proyecto (cacheado).
2. HS256 con `SUPABASE_JWT_SECRET` configurado: validación local.
3. HS256 sin secreto: se pregunta a Supabase Auth (`auth.get_user`) y se cachea el
   resultado hasta que caduque el token.
"""
import logging
import threading
import time
from typing import Callable

import jwt
from cachetools import TTLCache

from core.errors import UnauthorizedError

logger = logging.getLogger(__name__)

AUDIENCE = "authenticated"
ASYMMETRIC_ALGS = ("ES256", "RS256", "EdDSA")


class TokenVerifier:
    def __init__(
        self,
        supabase_url: str,
        jwt_secret: str | None = None,
        remote_lookup: Callable[[str], str | None] | None = None,
        jwks_client: jwt.PyJWKClient | None = None,
    ):
        self._issuer = f"{supabase_url}/auth/v1"
        self._jwt_secret = jwt_secret
        self._remote_lookup = remote_lookup
        self._jwks = jwks_client or jwt.PyJWKClient(
            f"{self._issuer}/.well-known/jwks.json", cache_keys=True, lifespan=3600
        )
        self._remote_cache: TTLCache = TTLCache(maxsize=1024, ttl=3600)
        self._lock = threading.Lock()

    def verify(self, token: str) -> str:
        """Devuelve el `sub` (user_id) del token o lanza UnauthorizedError."""
        try:
            alg = jwt.get_unverified_header(token).get("alg")
        except jwt.PyJWTError as exc:
            raise UnauthorizedError("Token mal formado") from exc

        try:
            if alg in ASYMMETRIC_ALGS:
                key = self._jwks.get_signing_key_from_jwt(token).key
                claims = self._decode(token, key, alg)
            elif alg == "HS256" and self._jwt_secret:
                claims = self._decode(token, self._jwt_secret, alg)
            elif alg == "HS256" and self._remote_lookup:
                return self._verify_remote(token)
            else:
                raise UnauthorizedError("Algoritmo de token no soportado")
        except jwt.ExpiredSignatureError as exc:
            raise UnauthorizedError("Sesión caducada") from exc
        except jwt.PyJWTError as exc:
            raise UnauthorizedError("Token no válido") from exc

        sub = claims.get("sub")
        if not sub:
            raise UnauthorizedError("Token sin usuario")
        return sub

    def _decode(self, token: str, key, alg: str) -> dict:
        return jwt.decode(
            token, key, algorithms=[alg], audience=AUDIENCE, issuer=self._issuer,
            options={"require": ["exp", "sub"]},
        )

    def _verify_remote(self, token: str) -> str:
        with self._lock:
            cached = self._remote_cache.get(token)
        if cached:
            user_id, exp = cached
            if exp > time.time():
                return user_id

        # Comprobamos caducidad antes de hacer la llamada de red
        try:
            claims = jwt.decode(token, options={"verify_signature": False})
        except jwt.PyJWTError as exc:
            raise UnauthorizedError("Token no válido") from exc
        exp = float(claims.get("exp") or 0)
        if exp <= time.time():
            raise UnauthorizedError("Sesión caducada")

        try:
            user_id = self._remote_lookup(token)
        except Exception as exc:  # error de red o token rechazado por Supabase
            logger.warning("Supabase Auth rechazó el token: %s", exc)
            raise UnauthorizedError("Token no válido") from exc
        if not user_id:
            raise UnauthorizedError("Token no válido")

        with self._lock:
            self._remote_cache[token] = (user_id, exp)
        return user_id
