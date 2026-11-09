"""Motor de predicción de sueño (funciones puras, sin BD ni reloj).

Flujo (ver `engine.predict`):
1. `segmentation`: agrupa los eventos en días de sueño (woke_up -> bed_time) y decide
   el estado actual (día / noche / sin datos).
2. `profile`: aprende el perfil del bebé (ventanas de vigilia por siesta, duraciones, nº
   de siestas, horarios, cuánto manda el reloj frente a la ventana o la duración de la
   noche, si compensa las siestas cortas, si entre semana y el fin de semana hace horarios
   distintos y cuánto varía cada cosa) partiendo de valores típicos por edad.
3. `feedback`: mide el error sistemático de predicciones pasadas.
4. `schedule`: genera la agenda que queda del día y la hora prevista de despertar, cada
   predicción con su margen (`start_range`, ≈ 50 % de probabilidad).

`rules` contiene las reglas que comparten el aprendizaje y la agenda, y `stats` la
estadística robusta. La calidad se mide con `tools/cohort.py` y `tools/backtest.py`.
"""
from prediction.config import DEFAULT_CONFIG, PredictionConfig
from prediction.engine import predict

__all__ = ["predict", "PredictionConfig", "DEFAULT_CONFIG"]
