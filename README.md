# BabyLink

App para el seguimiento del día a día de un bebé: sueño, tomas, cuidados, crecimiento y recuerdos (fotos y vídeos de sus primeros hitos), con estadísticas y predicciones de sueño.

## Estructura

| Carpeta | Qué es |
|---|---|
| `app/` | App móvil en Flutter (Riverpod, go_router, Supabase) |
| `api/` | API REST en Python (FastAPI) sobre Supabase |
| `migrar_csv.py` | Script puntual para importar eventos desde un CSV |

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
pip install -r ../requirements.txt
```

Crea `api/.env` (también ignorado por git):

```env
SUPABASE_URL=https://<tu-proyecto>.supabase.co
SUPABASE_KEY=<tu-service-role-key>
```

Arranca el servidor (`--host 0.0.0.0` permite que un móvil físico lo alcance):

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

La documentación interactiva queda en <http://localhost:8000/docs>.

> La `service_role` key da acceso total a la base de datos: úsala solo en el servidor y nunca la incluyas en la app ni en el repositorio.
