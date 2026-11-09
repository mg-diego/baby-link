"""Estadística robusta para aprender del historial del bebé.

La idea: empezar en el valor típico para su edad (prior) e ir pasando a sus propios
datos a medida que hay más, dando más peso a lo reciente e ignorando registros raros.
"""
import math
from dataclasses import dataclass
from statistics import median
from typing import Sequence

MAD_TO_SD = 1.4826
# La mediana es menos eficiente que la media: su error típico es ~1,25 σ/√n
MEDIAN_SE_FACTOR = 1.2533


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
    mad = median(abs(v - med) for v in values) * MAD_TO_SD
    if mad == 0:
        return list(range(len(values)))
    return [i for i, v in enumerate(values) if abs(v - med) <= max_mads * mad]


def recency_weight(age_days: float, half_life_days: float) -> float:
    return 0.5 ** (max(age_days, 0.0) / half_life_days)


@dataclass(frozen=True)
class Location:
    value: float
    n: int            # muestras usadas (sin outliers)
    n_eff: float      # tamaño efectivo con los pesos por recencia
    sd: float         # dispersión robusta (MAD escalada), 0 si hay < 2 muestras


def robust_location(samples: Sequence[tuple[float, float]], half_life_days: float, max_mads: float) -> Location | None:
    """Mediana ponderada por recencia de `samples` = [(valor, antigüedad en días)], sin outliers."""
    if not samples:
        return None
    values = [v for v, _ in samples]
    kept = drop_outliers(values, max_mads)
    values = [values[i] for i in kept]
    weights = [recency_weight(samples[i][1], half_life_days) for i in kept]
    total, total_sq = sum(weights), sum(w * w for w in weights)
    location = weighted_median(values, weights)
    n_eff = total * total / total_sq if total_sq > 0 else float(len(values))
    sd = median(abs(v - location) for v in values) * MAD_TO_SD if len(values) >= 2 else 0.0
    return Location(location, len(values), n_eff, sd)


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
    loc = robust_location(samples, half_life_days, max_mads)
    if loc is None:
        return prior, 0
    return (loc.n * loc.value + prior_strength * prior) / (loc.n + prior_strength), loc.n


def shrunk_spread(residuals: Sequence[float], prior_sd: float, prior_strength: float) -> float:
    """Dispersión robusta de unos residuos, encogida hacia `prior_sd` con pocos datos."""
    n = len(residuals)
    if n < 2:
        return prior_sd
    sd = median(abs(r) for r in residuals) * MAD_TO_SD
    return math.sqrt((n * sd * sd + prior_strength * prior_sd * prior_sd) / (n + prior_strength))


def split_by_group(
    base: float,
    group: Sequence[tuple[float, float]],
    other: Sequence[tuple[float, float]],
    half_life_days: float,
    max_mads: float,
    strictness: float = 6.0,
) -> float:
    """Valor de un subgrupo de días (p. ej. fines de semana) partiendo del valor común.

    Bayes empírico: la diferencia entre el grupo y el resto solo se cree en la medida en
    que supera lo que explicaría el ruido (`strictness` veces el error típico de la
    diferencia, al cuadrado). Un bebé con el mismo horario todos los días se
    queda en `base`; uno con guardería entre semana pasa a los valores de cada grupo.
    """
    g = robust_location(group, half_life_days, max_mads)
    o = robust_location(other, half_life_days, max_mads)
    if g is None or o is None or g.n < 2 or o.n < 2:
        return base
    sd = max(g.sd, o.sd, 1.0)
    se2_g = (MEDIAN_SE_FACTOR * sd) ** 2 / g.n_eff
    se2_o = (MEDIAN_SE_FACTOR * sd) ** 2 / o.n_eff
    tau2 = max((g.value - o.value) ** 2 - strictness * (se2_g + se2_o), 0.0)
    weight = tau2 / (tau2 + se2_g) if tau2 > 0 else 0.0
    return base + weight * (g.value - base)


def shrunk_regression(
    xs: Sequence[Sequence[float]],
    ys: Sequence[float],
    priors: Sequence[float],
    prior_strength: float,
    max_mads: float,
    min_samples: int,
) -> tuple[list[float], int]:
    """Regresión lineal por el origen y = Σ b_j·x_j, encogida hacia `priors` (ridge).

    Con pocos datos devuelve los priors; el peso del prior equivale a `prior_strength`
    muestras "típicas". Se quitan los residuos extremos (registros raros) y se repite.
    Coeficientes acotados a [0, 1] y con suma ≤ 1 (son pesos de una mezcla).
    """
    k = len(priors)
    rows = [(list(x), y) for x, y in zip(xs, ys)]
    if len(rows) < min_samples:
        return list(priors), len(rows)

    def solve(data):
        n = len(data)
        a = [[sum(x[i] * x[j] for x, _ in data) for j in range(k)] for i in range(k)]
        b = [sum(x[i] * y for x, y in data) for i in range(k)]
        for i in range(k):
            lam = prior_strength * a[i][i] / n if n else 0.0
            a[i][i] += lam
            b[i] += lam * priors[i]
        return _solve_linear(a, b, priors)

    coef = solve(rows)
    residuals = [y - sum(c * xi for c, xi in zip(coef, x)) for x, y in rows]
    kept = [rows[i] for i in drop_outliers(residuals, max_mads)]
    if len(kept) >= min_samples:
        coef = solve(kept)
    coef = [min(max(c, 0.0), 1.0) for c in coef]
    total = sum(coef)
    if total > 1.0:
        coef = [c / total for c in coef]
    return coef, len(kept)


def _solve_linear(a: list[list[float]], b: list[float], fallback: Sequence[float]) -> list[float]:
    """Gauss-Jordan para sistemas pequeños; si es singular, devuelve `fallback`."""
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        if abs(m[pivot][col]) < 1e-9:
            return list(fallback)
        m[col], m[pivot] = m[pivot], m[col]
        for r in range(n):
            if r != col:
                f = m[r][col] / m[col][col]
                m[r] = [vr - f * vc for vr, vc in zip(m[r], m[col])]
    return [m[i][n] / m[i][i] for i in range(n)]
