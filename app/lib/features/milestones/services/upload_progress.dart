/// Fases por las que pasa el guardado de un hito con foto/vídeo.
enum UploadPhase { compressing, uploading, saving }

/// Estado del guardado para pintar en la UI.
class UploadProgress {
  final UploadPhase phase;

  /// Avance de 0 a 1 dentro de la fase, o `null` si no se puede medir
  /// (la barra se muestra indeterminada).
  final double? fraction;

  /// Tipo de media ('image' | 'video' | 'none'), para el texto.
  final String mediaType;

  const UploadProgress(this.phase, {this.fraction, this.mediaType = 'none'});

  String get label => switch (phase) {
    UploadPhase.compressing =>
      mediaType == 'video' ? 'Comprimiendo vídeo' : 'Optimizando foto',
    UploadPhase.uploading =>
      mediaType == 'video' ? 'Subiendo vídeo' : 'Subiendo foto',
    UploadPhase.saving => 'Guardando',
  };

  /// "37 %" si hay avance medible.
  String? get percent =>
      fraction == null ? null : '${(fraction! * 100).clamp(0, 100).round()} %';
}

typedef UploadProgressCallback = void Function(UploadProgress progress);
