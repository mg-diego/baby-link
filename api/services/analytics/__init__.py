"""Estadísticas para la pantalla de análisis, separadas por dominio (sueño, alimentación,
pañales, crecimiento). El formato de los valores (p. ej. "1h 30m") se genera aquí porque
la app es solo en español y así la lógica de cada tarjeta vive en un único sitio."""
from services.analytics.service import STAT_CODES, AnalyticsService

__all__ = ["AnalyticsService", "STAT_CODES"]
