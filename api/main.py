import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import get_settings
from core.errors import DomainError
from routers import analytics, babies, events, home_assistant

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

settings = get_settings()  # falla al arrancar si falta configuración

app = FastAPI(title="BabyLink API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_credentials=False,  # la autenticación va por cabecera Bearer, no por cookies
    allow_methods=["*"],
    allow_headers=["*"],
)

for module in (babies, events, analytics, home_assistant):
    app.include_router(module.router)


# ─── Errores ──────────────────────────────────────────────────────────────────

@app.exception_handler(DomainError)
async def domain_exception_handler(request: Request, exc: DomainError):
    logger.info("HTTP %s en %s: %s", exc.status_code, request.url.path, exc.message)
    headers = {"WWW-Authenticate": "Bearer"} if exc.status_code == 401 else None
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.message}, headers=headers)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error("HTTP %s en %s: %s", exc.status_code, request.url.path, exc.detail)
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail}, headers=exc.headers)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # jsonable_encoder: los errores pueden incluir excepciones (ctx.error) que no son JSON
    errors = jsonable_encoder(exc.errors())
    logger.warning("Error de validación (422) en %s: %s", request.url.path, errors)
    return JSONResponse(status_code=422, content={"detail": errors})


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # El detalle va al log, nunca al cliente (puede contener datos internos de la BD)
    logger.exception("Error no controlado en %s", request.url.path)
    return JSONResponse(status_code=500, content={"detail": "Error interno del servidor"})
