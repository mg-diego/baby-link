from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal

WOKE_UP = "woke_up"
NAP = "nap"
BED_TIME = "bed_time"
SLEEP_CATEGORIES = (WOKE_UP, NAP, BED_TIME)


@dataclass(frozen=True)
class SleepEvent:
    category: str
    start: datetime            # aware, UTC
    end: datetime | None
    metadata: dict


@dataclass
class Nap:
    start: datetime
    end: datetime | None
    index: int                 # 1 = primera siesta del día
    metadata: dict = field(default_factory=dict)

    @property
    def minutes(self) -> float | None:
        return (self.end - self.start).total_seconds() / 60 if self.end else None


@dataclass
class SleepDay:
    """Un "día de sueño": del despertar (woke_up) a la hora de dormir (bed_time).
    Cualquiera de los dos extremos puede faltar si no se registró."""
    wake: datetime | None
    naps: list[Nap] = field(default_factory=list)
    bed: datetime | None = None

    @property
    def anchor(self) -> datetime | None:
        return self.wake or (self.naps[0].start if self.naps else self.bed)

    @property
    def complete(self) -> bool:
        return self.wake is not None and self.bed is not None and all(n.end for n in self.naps)


@dataclass(frozen=True)
class DayState:
    """Dónde estamos ahora mismo:
    - day: hay un día abierto (se despertó y aún no se ha acostado)
    - night: se acostó hace poco y aún no se ha despertado
    - unknown: no hay datos recientes (p. ej. no se registró nada desde ayer)"""
    kind: Literal["day", "night", "unknown"]
    day: SleepDay | None = None
    bed: datetime | None = None


@dataclass(frozen=True)
class SleepProfile:
    nap_count: int
    ww_first: float            # minutos: despertar -> 1ª siesta
    ww_mid: float              # minutos: fin de siesta -> siguiente siesta (todas juntas)
    ww_evening: float          # minutos: última siesta (o despertar) -> dormir
    nap_minutes: tuple[float, ...]  # duración por índice de siesta
    day_minutes: float         # despertar -> dormir
    night_minutes: float       # dormir -> despertar
    wake_clock: float          # hora habitual de despertar, minutos desde medianoche local
    samples: dict              # nº de muestras por métrica (diagnóstico)
    # Minutos que se acorta la tarde por cada minuto de siesta "perdido" (0 = no compensa).
    # Se aprende del historial: unos bebés se duermen antes tras una mala siesta y otros no.
    deficit_slope: float = 0.0
    # Ventana antes de la siesta 2, 3...: a lo largo del día suelen alargarse.
    ww_by_index: tuple[float, ...] = ()
    # Hora habitual de dormir, minutos desde la medianoche del día (puede pasar de 1440).
    bed_clock: float = 20 * 60
    # Cuánto se acerca la hora de dormir a "despertar + duración del día" (day) y a la
    # hora habitual (clock), frente a "última siesta + ventana". 0 = manda la ventana.
    bed_day_weight: float = 0.0
    bed_clock_weight: float = 0.0
    # Despertar: 0 = a su hora de siempre, 1 = tras la duración habitual de la noche.
    wake_duration_weight: float = 0.15
    # Dispersión (minutos, ~desviación típica) de cada métrica: da el margen de las predicciones.
    spread: dict = field(default_factory=dict)
    weekend: bool | None = None  # perfil de fin de semana / entre semana (None = todos los días)
    days_learned: int = 0        # días de historial de los que se ha aprendido

    def nap_duration(self, index: int) -> float:
        return self.nap_minutes[min(max(index, 1), len(self.nap_minutes)) - 1]

    def expected_nap(self, index: int) -> float:
        """Lo que se espera que duerma la siesta `index`. Una siesta por encima de las
        habituales (p. ej. de rescate) es sueño extra: se espera 0 y no cuenta como déficit."""
        return 0.0 if index > self.nap_count else self.nap_duration(index)

    def window_before(self, index: int) -> float:
        if index <= 1:
            return self.ww_first
        if self.ww_by_index:
            return self.ww_by_index[min(index - 2, len(self.ww_by_index) - 1)]
        return self.ww_mid

    def sd(self, metric: str, default: float = 20.0) -> float:
        return self.spread.get(metric, default)


@dataclass(frozen=True)
class Biases:
    """Minutos a sumar a cada predicción, aprendidos del error de predicciones pasadas."""
    ww_first: float = 0.0
    ww_mid: float = 0.0
    nap_duration: float = 0.0
    bedtime: float = 0.0
    wake: float = 0.0


@dataclass(frozen=True)
class Sufficiency:
    reason: str
    required: int
    current: int


@dataclass
class PredictionOutput:
    schedule: list[dict] = field(default_factory=list)
    wake: dict | None = None
    insufficient: Sufficiency | None = None
    state: str | None = None
    profile: SleepProfile | None = None
