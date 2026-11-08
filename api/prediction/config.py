from dataclasses import dataclass


@dataclass(frozen=True)
class PredictionConfig:
    """Parámetros del motor. Ajustarlos midiendo con `tools/backtest.py`, no a ojo."""

    # ─── Datos ────────────────────────────────────────────────────────────────
    history_days: int = 28           # ventana de historial que se usa para aprender
    min_sleep_events: int = 20       # mínimo para predecir (solo eventos de sueño)
    min_days: int = 7                # mínimo de días distintos con eventos de sueño

    # ─── Aprendizaje del perfil ───────────────────────────────────────────────
    half_life_days: float = 7.0      # un dato de hace 7 días pesa la mitad que uno de hoy
    prior_strength: float = 1.5      # el valor por edad "vale" como 1,5 muestras: decide al principio, se diluye después
    clock_prior_strength: float = 1.0
    outlier_mads: float = 3.5        # se descarta lo que se aleja > 3.5 MAD de la mediana del propio bebé
    nap_count_days: int = 14         # días recientes para decidir cuántas siestas hace
    min_complete_days: int = 3       # días completos necesarios para fiarse del nº de siestas aprendido

    # ─── Corrección por feedback (predicción vs realidad) ─────────────────────
    feedback_gain: float = 0.6
    feedback_window: int = 10        # últimas N muestras por métrica
    feedback_min_samples: int = 3
    feedback_max_abs_min: float = 30.0
    feedback_outlier_min: float = 120.0  # errores mayores suelen ser registros a posteriori

    # ─── Generación de la agenda ──────────────────────────────────────────────
    deficit_threshold_min: float = 15.0   # déficit de siesta a partir del cual se acortan las ventanas
    deficit_compensation: float = 0.85
    min_window_factor: float = 0.6        # una ventana nunca baja del 60 % de la aprendida
    catnap_min: float = 30.0
    bed_late_tolerance_min: float = 60.0  # cuánto puede retrasarse la hora de dormir sobre la habitual
    bed_early_tolerance_min: float = 120.0
    wake_clock_blend: float = 0.85        # peso de la hora habitual de despertar frente a la duración de la noche
    wake_clamp_min: float = 45.0
    max_items: int = 8

    # ─── Detección del estado actual ──────────────────────────────────────────
    max_open_nap_hours: float = 6.0   # una siesta abierta más tiempo es un cronómetro olvidado
    night_state_hours: float = 16.0   # tras un bed_time, cuánto se considera que sigue siendo "noche"
    max_day_hours: float = 20.0       # un día sin bed_time no se alarga más de esto


DEFAULT_CONFIG = PredictionConfig()
