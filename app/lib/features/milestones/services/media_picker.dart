import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'media_metadata.dart';

/// Fichero elegido + lo que la galería sabe de él.
class PickedMedia {
  final File file;

  /// 'image' | 'video'.
  final String type;

  /// Nombre original en la galería (`IMG-20250214-WA0003.jpg`), si se conoce.
  final String? originalName;

  /// Fecha con la que la galería muestra el fichero (`datetaken` de Android).
  /// Existe aunque el fichero no lleve EXIF.
  final DateTime? galleryDate;

  /// Última modificación del fichero. Último recurso: si se copió o
  /// restauró de una copia de seguridad puede ser posterior a la real.
  final DateTime? modifiedDate;

  const PickedMedia({
    required this.file,
    required this.type,
    this.originalName,
    this.galleryDate,
    this.modifiedDate,
  });

  /// Fecha de captura combinando fichero, galería y nombre
  /// (ver [readCaptureDate]).
  Future<DateTime?> captureDate() => readCaptureDate(
    file,
    type,
    fileNames: [originalName],
    galleryDate: galleryDate,
    modifiedDate: modifiedDate,
  );
}

/// Abre el selector de la galería.
///
/// En Android usa un canal propio (ver `MediaPickerChannel.kt`) porque
/// `image_picker` no devuelve la fecha de la galería ni el nombre original.
/// En iOS, o si el canal falla, se recurre a `image_picker`.
class MediaPicker {
  static const _channel = MethodChannel('baby_link/media_picker');

  final ImagePicker _fallback;

  MediaPicker([ImagePicker? fallback]) : _fallback = fallback ?? ImagePicker();

  Future<PickedMedia?> pick(String type) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final r = await _channel.invokeMapMethod<String, Object?>('pick', {
          'type': type,
        });
        if (r == null) return null; // cancelado
        return PickedMedia(
          file: File(r['path']! as String),
          type: type,
          originalName: r['name'] as String?,
          galleryDate: _fromMs(r['dateTakenMs']),
          modifiedDate: _fromMs(r['dateModifiedMs']),
        );
      } on PlatformException catch (e) {
        if (e.code == 'already_active') return null;
        debugPrint('[media_picker] Canal nativo falló ($e); uso image_picker');
      } on MissingPluginException {
        // Sin canal registrado (tests, otra activity…): image_picker.
      }
    }

    // Sin `imageQuality`: recodificar la foto borraría el EXIF.
    final xf = type == 'video'
        ? await _fallback.pickVideo(source: ImageSource.gallery)
        : await _fallback.pickImage(source: ImageSource.gallery);
    if (xf == null) return null;
    return PickedMedia(file: File(xf.path), type: type, originalName: xf.name);
  }

  static DateTime? _fromMs(Object? v) => v is int && v > 0
      ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal()
      : null;
}
