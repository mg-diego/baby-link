from dataclasses import dataclass


@dataclass(frozen=True)
class PredictionConfig:
    """Parámetros del motor. Ajustarlos midiendo con `tools/cohort.py` (grupo de bebés
    sintéticos muy distintos) y `tools/backtest.py` (historiales reales), no a ojo ni con
    un solo bebé."""

    # ─── Datos ────────────────────────────────────────────────────────────────
    history_days: int = 28           # ventana de historial que se usa para aprender
    # Con 3 días el backtest ya da errores comparables a los de régimen (los valores por
    # edad cubren el arranque en frío), así que no hace falta esperar una semana.
    min_sleep_events: int = 10       # mínimo para predecir (solo eventos de sueño)
    min_days: int = 3                # mínimo de días distintos con eventos de sueño

    # ─── Aprendizaje del perfil ───────────────────────────────────────────────
    half_life_days: float = 7.0      # un dato de hace 7 días pesa la mitad que uno de hoy...
    half_life_young_days: float = 4.0  # ...salvo de bebés pequeños, que cambian cada semana
    young_months: float = 3.0        # hasta esta edad se usa la vida media corta,
    adult_months: float = 6.0        # y a partir de esta la normal (entre medias, interpolada)
    prior_strength: float = 1.5      # el valor por edad "vale" como 1,5 muestras: decide al principio, se diluye después
    clock_prior_strength: float = 1.0
    outlier_mads: float = 3.5        # se descarta lo que se aleja > 3.5 MAD de la mediana del propio bebé
    nap_count_days: int = 14         # días recientes para decidir cuántas siestas hace
    min_complete_days: int = 3       # días completos necesarios para fiarse del nº de siestas aprendido
    # Con estos días completos se confía del todo en su nº de siestas aunque se salga de lo
    # típico para su edad (con menos, solo se acepta ±1 respecto a la edad).
    nap_count_trust_days: int = 7
    max_naps: int = 6

    # Pesos aprendidos por bebé (reloj frente a ventana/duración): con pocos días se
    # encogen hacia el valor por defecto; `blend_prior_days` días "valen" como el defecto.
    min_blend_days: int = 4
    blend_prior_days: float = 5.0
    wake_duration_prior: float = 0.15  # por defecto, el despertar lo marca sobre todo el reloj

    # Entre semana y fin de semana (guardería, despertador...) el horario puede cambiar.
    # Cada métrica se separa solo si la diferencia entre ambos es mayor que el ruido.
    day_type_split: bool = True
    # La diferencia (al cuadrado) tiene que superar estas veces su ruido. Con solo dos grupos
    # el azar da diferencias grandes a menudo: con 1, un bebé con el mismo horario todos los
    # días salía con el fin de semana desplazado hasta 45'; con 6 casi nunca (cohort).
    day_type_strictness: float = 6.0
    day_type_nap_count: bool = True   # el nº de siestas también puede ser distinto

    # ─── Corrección por feedback (predicción vs realidad) ─────────────────────
    feedback_gain: float = 0.6
    feedback_window: int = 10        # últimas N muestras por métrica
    feedback_min_samples: int = 3
    feedback_max_abs_min: float = 30.0
    feedback_outlier_min: float = 120.0  # errores mayores suelen ser registros a posteriori

    # ─── Generación de la agenda ──────────────────────────────────────────────
    deficit_threshold_min: float = 15.0   # déficit de siesta a partir del cual se acortan las ventanas
    # La compensación (minutos de ventana por minuto de siesta perdido) se aprende por bebé:
    min_deficit_days: int = 5             # días con déficit/superávit claro necesarios para aprenderla
    deficit_prior_days: float = 5.0       # con pocos días se encoge hacia 0 (no compensar)
    max_deficit_slope: float = 1.0
    min_window_factor: float = 0.6        # una ventana nunca baja del 60 % de la aprendida
    catnap_min: float = 30.0
    bed_late_tolerance_min: float = 60.0  # cuánto puede retrasarse la hora de dormir sobre la habitual
    bed_early_tolerance_min: float = 120.0
    wake_clamp_min: float = 45.0          # el despertar no se aleja de su hora habitual más de esto...
    wake_duration_clamp_min: float = 240.0  # ...o de peso_duración × esto, si es mayor
    max_items: int = 8

    # ─── Margen de las predicciones ───────────────────────────────────────────
    # Intervalo "lo más probable" (≈ 50 %). Con datos gaussianos bastaría ±0,674 σ, pero los
    # historiales reales tienen más días raros: 0,674 cubría solo el 34-47 % en un año de datos
    # reales; 0,8 da ≈ 50 % en los reales y 49-59 % en el grupo sintético (tools/cohort.py).
    range_z: float = 0.8
    range_min_min: float = 5.0
    range_max_min: float = 90.0
    spread_prior_min: float = 20.0   # dispersión supuesta mientras hay pocos datos...
    spread_prior_strength: float = 5.0  # ...que "vale" como 5 muestras

    # ─── Detección del estado actual ──────────────────────────────────────────
    max_open_nap_hours: float = 6.0   # una siesta abierta más tiempo es un cronómetro olvidado
    night_state_hours: float = 16.0   # tras un bed_time, cuánto se considera que sigue siendo "noche"
    max_day_hours: float = 20.0       # un día sin bed_time no se alarga más de esto


DEFAULT_CONFIG = PredictionConfig()
