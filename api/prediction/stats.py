"""Estadística robusta para aprender del historial del bebé.

La idea: empezar en el valor típico para su edad (prior) e ir pasando a sus propios
datos a medida que hay más, dando más peso a lo reciente e ignorando registros raros.
"""
from statistics import median
from typing import Sequence


def weighted_median(values: Sequence[float], weights: Sequence[float]) -> float:
    pairs = sorted(zip(values, weights))
    total = sum(w for _, w in pairs)
    if total <= 0:
        return median(values)
    acc = 0.0
    for value, weight in pairs:
        acc += weight
        if acc >= total / 2:
            return value
    return pairs[-1][0]


def drop_outliers(values: Sequence[float], max_mads: float) -> list[int]:
    """Índices de los valores que se quedan (a menos de `max_mads` MAD de la mediana)."""
    if len(values) < 4:
        return list(range(len(values)))
    med = median(values)
    mad = median(abs(v - med) for v in values) * 1.4826
    if mad == 0:
        return list(range(len(values)))
    return [i for i, v in enumerate(values) if abs(v - med) <= max_mads * mad]


def robust_estimate(
    samples: Sequence[tuple[float, float]],
    prior: float,
    prior_strength: float,
    half_life_days: float,
    max_mads: float,
) -> tuple[float, int]:
    """`samples` = [(valor, antigüedad en días)]. Devuelve (estimación, nº de muestras usadas).

    Mediana ponderada por recencia, encogida hacia el prior con peso n / (n + k):
    con 0 muestras devuelve el prior; con muchas, prácticamente sus datos.
    """
    if not samples:
        return prior, 0
    values = [v for v, _ in samples]
    kept = drop_outliers(values, max_mads)
    values = [values[i] for i in kept]
    weights = [0.5 ** (max(samples[i][1], 0.0) / half_life_days) for i in kept]
    location = weighted_median(values, weights)
    n = len(values)
    return (n * location + prior_strength * prior) / (n + prior_strength), n
