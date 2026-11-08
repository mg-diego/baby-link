import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_compress/video_compress.dart';

/// Extrae un fotograma de un vídeo como JPEG para usarlo de miniatura.
///
/// En Android usa el canal nativo (`MediaPickerChannel.kt`), que admite tanto
/// ficheros locales como URLs: para las URLs sólo descarga lo necesario para
/// decodificar ese fotograma. En iOS recurre a `video_compress` (sólo
/// ficheros locales).
///
/// Es "best effort": devuelve `null` si no se puede.
class VideoThumbnailer {
  static const _channel = MethodChannel('baby_link/media_picker');

  /// Lado largo de la miniatura. 1080 px se ve nítido en la cabecera del
  /// detalle y pesa ~100–200 KB en JPEG.
  static const maxSide = 1080;

  const VideoThumbnailer();

  /// [source]: ruta local o URL `http(s)`.
  Future<File?> frameOf(String source) async {
    final isUrl = source.startsWith('http://') || source.startsWith('https://');
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final path = await _channel.invokeMethod<String>('videoFrame', {
          'source': source,
          'maxSide': maxSide,
        });
        return path == null ? null : File(path);
      }
      if (isUrl) return null;
      return await VideoCompress.getFileThumbnail(
        source,
        quality: 82,
        position: 0,
      );
    } catch (e) {
      debugPrint('[video_thumbnail] No se pudo extraer fotograma: $e');
      return null;
    }
  }
}
