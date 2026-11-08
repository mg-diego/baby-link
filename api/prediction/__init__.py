"""Motor de predicción de sueño (funciones puras, sin BD ni reloj).

Flujo (ver `engine.predict`):
1. `segmentation`: agrupa los eventos en días de sueño (woke_up -> bed_time) y decide
   el estado actual (día / noche / sin datos).
2. `profile`: aprende el perfil del bebé (ventanas de vigilia, siestas, horarios)
   partiendo de valores típicos por edad.
3. `feedback`: mide el error sistemático de predicciones pasadas.
4. `schedule`: genera la agenda que queda del día y la hora prevista de despertar.
"""
from prediction.config import DEFAULT_CONFIG, PredictionConfig
from prediction.engine import predict

__all__ = ["predict", "PredictionConfig", "DEFAULT_CONFIG"]
