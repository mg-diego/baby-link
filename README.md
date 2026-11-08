# BabyLink

App para el seguimiento del día a día de un bebé: sueño, tomas, cuidados, crecimiento y recuerdos (fotos y vídeos de sus primeros hitos), con estadísticas y predicciones de sueño.

## Estructura

| Carpeta | Qué es |
|---|---|
| `app/` | App móvil en Flutter (Riverpod, go_router, Supabase) |
| `api/` | API REST en Python (FastAPI) sobre Supabase |
| `supabase/migrations/` | Migraciones SQL (columnas, índices, funciones y RLS) |

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) (SDK Dart `^3.11`)
- Python 3.13 (solo si vas a ejecutar la API en local)
- Un proyecto de [Supabase](https://supabase.com) con las tablas y el bucket de Storage `milestones`

## Ejecutar la app en local

```bash
cd app
flutter pub get
```

Crea el fichero `app/.env` (está en `.gitignore`):

```env
SUPABASE_URL=https://<tu-proyecto>.supabase.co
SUPABASE_ANON_KEY=<tu-anon-key>
```

Y ejecuta:

```bash
flutter run
```

Tests: `flutter test`

### ¿Contra qué API se conecta?

La URL se define en [`app/lib/core/constants.dart`](app/lib/core/constants.dart). Por defecto apunta a la API desplegada en Railway. Para usar tu API local, cambia `apiUrl`:

- Emulador Android: `http://10.0.2.2:8000`
- Simulador iOS: `http://localhost:8000`
- Móvil físico: la IP de tu PC en la red local, p. ej. `http://192.168.1.140:8000`

## Ejecutar la API en local

```bash
cd api
python -m venv _venv
_venv\Scripts\activate          # Windows
# source _venv/bin/activate     # macOS / Linux
pip install -r requirements-dev.txt   # requirements.txt + pytest
```

Crea `api/.env` (también ignorado por git):

```env
SUPABASE_URL=https://<tu-proyecto>.supabase.co
SUPABASE_KEY=<tu-service-role-key>

# Opcionales
SUPABASE_JWT_SECRET=<jwt-secret>   # si el proyecto usa la clave JWT legacy (HS256): valida los tokens sin llamar a Supabase
HOME_ASSISTANT_API_KEY=<clave>     # necesaria para /homeassistant/... (cabecera X-API-Key)
APP_TIMEZONE=Europe/Madrid         # zona por defecto de los bebés sin `timezone` propia
CORS_ORIGINS=*
```

Arranca el servidor (`--host 0.0.0.0` permite que un móvil físico lo alcance):

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

La documentación interactiva queda en <http://localhost:8000/docs>.

> La `service_role` key da acceso total a la base de datos: úsala solo en el servidor y nunca la incluyas en la app ni en el repositorio.

### Estructura

| Carpeta | Qué contiene |
|---|---|
| `routers/` | Endpoints HTTP, uno por recurso |
| `services/` | Lógica de negocio (`analytics/` separado por dominio) |
| `repositories/` | Acceso a Supabase |
| `prediction/` | Motor de predicciones de sueño: funciones puras, sin BD ni reloj |
| `models/` | Modelos de entrada, de respuesta (`{status, data}`) y de `metadata` por categoría |
| `core/` | Configuración, autenticación, errores, fechas, paginación |
| `tools/` | Backtesting del motor de predicciones |
| `tests/` | `python -m pytest` |

### Autenticación

Todas las rutas exigen `Authorization: Bearer <access token de Supabase>` (la app lo envía automáticamente) y solo dan acceso a los bebés del usuario del token. Los tokens con claves asimétricas (ES256/RS256) se validan en local contra el JWKS del proyecto; con la clave HS256 legacy hace falta `SUPABASE_JWT_SECRET` o, si no está, se consulta a Supabase Auth (con caché).

Home Assistant usa una clave propia: añade `X-API-Key: <HOME_ASSISTANT_API_KEY>` a los `headers` del sensor REST.

### Base de datos (Supabase)

Las migraciones están en [`supabase/migrations/`](supabase/migrations/). Aplícalas en orden desde el SQL Editor de Supabase (o con `supabase db push`):

1. `..._baby_timezone.sql`: columna `babies.timezone` (zona IANA de cada bebé).
2. `..._event_indexes.sql`: índices para las consultas por bebé, categoría y fecha.
3. `..._event_functions.sql`: `event_dates` y `last_event_times`. Hasta que existan, la API usa una versión en Python más lenta.
4. `..._rls_owner_only.sql`: RLS "solo el dueño" en tablas y Storage. **Borra las políticas existentes de `babies`, `baby_events` y `milestones`**; revísalas antes con la consulta que hay al principio del fichero.

### Despliegue

La API y la app cambian de contrato a la vez (rutas nuevas y token obligatorio): despliega la API, instala la app nueva y añade `X-API-Key` a Home Assistant.

### Herramientas

```bash
cd api
python -m pytest
python -m tools.backtest --baby-id <uuid>                     # error del motor sobre el historial real (solo lectura)
```
