# google_mlkit_text_recognition referencia los reconocedores de todos los
# alfabetos, pero solo se incluye el latino (hoja de la guardería). Sin esto,
# R8 falla en la build de release por las clases que faltan.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
