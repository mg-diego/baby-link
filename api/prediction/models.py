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
    ww_mid: float              # minutos: fin de siesta -> siguiente siesta
    ww_evening: float          # minutos: última siesta (o despertar) -> dormir
    nap_minutes: tuple[float, ...]  # duración por índice de siesta
    day_minutes: float         # despertar -> dormir
    night_minutes: float       # dormir -> despertar
    wake_clock: float          # hora habitual de despertar, minutos desde medianoche local
    samples: dict              # nº de muestras por métrica (diagnóstico)

    def nap_duration(self, index: int) -> float:
        return self.nap_minutes[min(max(index, 1), len(self.nap_minutes)) - 1]


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
