import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// El vídeo sigue pesando demasiado tras comprimirlo.
class MediaTooLargeException implements Exception {
  final int bytes;
  const MediaTooLargeException(this.bytes);

  @override
  String toString() =>
      'El vídeo ocupa ${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB '
      'incluso comprimido (máx. ${MediaCompressor.maxUploadBytes ~/ (1024 * 1024)} MB)';
}

/// Reduce fotos y vídeos antes de subirlos a Supabase Storage.
///
/// Las fotos de móvil (4000×3000, 3–8 MB) se quedan en ~1440 px de lado corto
/// en JPEG q80 (≈250–600 KB). Los vídeos se recodifican a 960×540 (≈8–12 MB
/// por minuto frente a 100+ MB del original).
class MediaCompressor {
  /// Lado corto máximo de las fotos. 1440 px se ve nítido a pantalla completa.
  static const imageShortSide = 1440;
  static const imageQuality = 80;

  /// Resolución objetivo de los vídeos.
  static const videoQuality = VideoQuality.Res960x540Quality;

  /// Límite por fichero del plan gratuito de Supabase Storage.
  static const maxUploadBytes = 50 * 1024 * 1024;

  const MediaCompressor();

  /// [onProgress] recibe el avance de 0 a 1 cuando el formato lo permite
  /// (sólo vídeo; las fotos tardan menos de un segundo).
  Future<File> compress(
    File file,
    String mediaType, {
    void Function(double fraction)? onProgress,
  }) => switch (mediaType) {
    'image' => compressImage(file),
    'video' => compressVideo(file, onProgress: onProgress),
    _ => Future.value(file),
  };

  /// Si la compresión falla o no gana nada, devuelve el original.
  Future<File> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = p.join(
        dir.path,
        'milestone_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final out = await FlutterImageCompress.compressAndGetFile(
        file.path,
        target,
        minWidth: imageShortSide,
        minHeight: imageShortSide,
        quality: imageQuality,
        format: CompressFormat.jpeg,
      );
      if (out == null) return file;
      final compressed = File(out.path);
      return await compressed.length() < await file.length()
          ? compressed
          : file;
    } catch (_) {
      return file;
    }
  }

  /// Lanza [MediaTooLargeException] si ni comprimido cabe en Storage.
  Future<File> compressVideo(
    File file, {
    void Function(double fraction)? onProgress,
  }) async {
    var result = file;
    // El plugin emite el avance en porcentaje (0–100) por un canal global.
    final sub = onProgress == null
        ? null
        : VideoCompress.compressProgress$.subscribe(
            (pct) => onProgress((pct / 100).clamp(0.0, 1.0)),
          );
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: videoQuality,
        includeAudio: true,
      );
      final compressed = info?.file;
      if (compressed != null &&
          await compressed.length() < await file.length()) {
        result = compressed;
      }
    } catch (_) {
      // Seguimos con el original; el control de tamaño de abajo decide.
    } finally {
      sub?.unsubscribe();
    }
    final size = await result.length();
    if (size > maxUploadBytes) throw MediaTooLargeException(size);
    return result;
  }
}
