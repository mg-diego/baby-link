"""Errores de dominio.

Los servicios lanzan estas excepciones (no `HTTPException`) para no depender de la
capa HTTP; `main.py` las traduce a respuestas con un único handler.
"""


class DomainError(Exception):
    status_code = 400

    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


class InvalidInputError(DomainError):
    status_code = 400


class UnauthorizedError(DomainError):
    status_code = 401


class ForbiddenError(DomainError):
    status_code = 403


class NotFoundError(DomainError):
    status_code = 404
