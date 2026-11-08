-- Zona horaria (IANA) de cada bebé. Si es NULL la API usa APP_TIMEZONE.
-- Determina qué es "hoy", los días del calendario, las estadísticas y las predicciones.
alter table public.babies add column if not exists timezone text;
