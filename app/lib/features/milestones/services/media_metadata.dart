import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Intenta averiguar cuándo se tomó una foto o se grabó un vídeo.
///
/// 1. Metadatos del fichero (EXIF en fotos, `mvhd` en vídeos).
/// 2. [galleryDate]: la fecha con la que la galería muestra el fichero
///    (Android `datetaken`). Existe aunque el fichero no lleve EXIF.
/// 3. El nombre del fichero: muchas apps lo codifican ahí
///    (`IMG-20250214-WA0003.jpg` de WhatsApp, que borra el EXIF;
///    `PXL_20250214_…`, `Screenshot_2025-02-14-…`). Se prueban todos los
///    [fileNames] dados (el picker puede renombrar la copia que devuelve).
/// 4. [modifiedDate]: última modificación, como último recurso.
///
/// Devuelve `null` si no hay fecha fiable. Es "best effort": nunca lanza.
Future<DateTime?> readCaptureDate(
  File file,
  String mediaType, {
  Iterable<String?> fileNames = const [],
  DateTime? galleryDate,
  DateTime? modifiedDate,
}) async {
  DateTime? fromMeta;
  try {
    fromMeta = switch (mediaType) {
      'image' => await _readImageDate(file),
      'video' => await readMp4CreationDate(file),
      _ => null,
    };
  } catch (e) {
    debugPrint('[media_metadata] Error leyendo metadatos de ${file.path}: $e');
  }
  if (fromMeta != null) {
    debugPrint('[media_metadata] Fecha de metadatos: $fromMeta');
    return fromMeta;
  }

  if (galleryDate != null) {
    debugPrint('[media_metadata] Fecha de la galería: $galleryDate');
    return galleryDate;
  }

  for (final name in [...fileNames, file.path]) {
    final fromName = parseDateFromFileName(name);
    if (fromName != null) {
      debugPrint('[media_metadata] Fecha del nombre "$name": $fromName');
      return fromName;
    }
  }

  if (modifiedDate != null) {
    debugPrint('[media_metadata] Fecha de modificación: $modifiedDate');
    return modifiedDate;
  }
  debugPrint('[media_metadata] Sin fecha en ${file.path}');
  return null;
}

/// Busca una fecha `AAAAMMDD` / `AAAA-MM-DD` / `AAAA_MM_DD` en el nombre.
DateTime? parseDateFromFileName(String? name) {
  if (name == null) return null;
  final base = p.basename(name);
  final re = RegExp(r'(?<!\d)(20\d{2})([-_]?)(\d{2})\2(\d{2})(?!\d)');
  for (final m in re.allMatches(base)) {
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(3)!);
    final d = int.parse(m.group(4)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;
    final date = DateTime(y, mo, d);
    if (date.month != mo) continue; // 31 de febrero, etc.
    return date;
  }
  return null;
}

// ─── Imágenes (EXIF) ──────────────────────────────────────────────────────────

/// Por orden de preferencia: momento del disparo, digitalización y, en último
/// lugar, la última modificación registrada por la cámara/editor.
const _exifDateTags = [
  'EXIF DateTimeOriginal',
  'EXIF DateTimeDigitized',
  'Image DateTime',
];

Future<DateTime?> _readImageDate(File file) async {
  final format = await _describeFormat(file);

  // `details: false` evita decodificar el MakerNote del fabricante, que en
  // algunos móviles lanza y tumba la lectura entera. Sólo queremos fechas.
  var tags = const <String, IfdTag>{};
  try {
    tags = await readExifFromFile(file, details: false);
  } catch (e) {
    debugPrint('[media_metadata] El paquete exif falló ($format): $e');
  }
  for (final key in _exifDateTags) {
    final date = parseExifDateTime(tags[key]?.printable);
    if (date != null) {
      debugPrint('[media_metadata] $key en $format: $date');
      return date;
    }
  }

  // El paquete sólo reconoce HEIF con marca `heic`; los de Android suelen
  // ser `mif1`/`heix` y devuelve 0 tags sin error. Buscamos en bruto.
  debugPrint(
    '[media_metadata] Sin fecha vía exif ($format, ${tags.length} tags); '
    'buscando en bruto',
  );
  final raw = await scanRawMetadataDate(file);
  if (raw == null) {
    debugPrint('[media_metadata] La imagen no tiene fecha en sus metadatos');
  }
  return raw;
}

/// Busca fechas EXIF (`2025:02:14 10:30:00`) y XMP (`2025-02-14T10:30:00`)
/// directamente en los bytes del principio del fichero. Funciona con
/// cualquier contenedor (JPEG, HEIF de cualquier marca, PNG, WebP…) porque
/// el bloque EXIF y el XMP guardan las fechas como texto ASCII.
///
/// Devuelve la más antigua: el disparo (DateTimeOriginal) siempre es anterior
/// o igual a la digitalización y a la última edición (DateTime/ModifyDate).
Future<DateTime?> scanRawMetadataDate(
  File file, {
  int maxBytes = 1024 * 1024,
}) async {
  final raf = await file.open();
  final List<int> bytes;
  try {
    bytes = await raf.read(maxBytes);
  } finally {
    await raf.close();
  }
  final text = String.fromCharCodes(bytes); // latin-1: 1 byte = 1 carácter
  final re = RegExp(
    r'(?<!\d)(\d{4})([:-])(\d{2})\2(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  );
  DateTime? oldest;
  for (final m in re.allMatches(text)) {
    final v = [
      for (final g in [1, 3, 4, 5, 6, 7]) int.parse(m.group(g)!),
    ];
    // Años < 2001: relojes de cámara reiniciados (1970, 2000-01-01…).
    if (v[0] < 2001 || v[1] < 1 || v[1] > 12 || v[2] < 1 || v[2] > 31) {
      continue;
    }
    if (v[3] > 23 || v[4] > 59 || v[5] > 59) continue;
    final date = DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
    if (oldest == null || date.isBefore(oldest)) oldest = date;
  }
  return oldest;
}

/// "JPEG", "HEIF(mif1)", "PNG"… para los logs de diagnóstico.
Future<String> _describeFormat(File file) async {
  try {
    final raf = await file.open();
    final h = await raf.read(12);
    final size = await raf.length();
    await raf.close();
    final kb = '${(size / 1024).round()} KB';
    if (h.length >= 2 && h[0] == 0xFF && h[1] == 0xD8) return 'JPEG, $kb';
    if (h.length >= 12 && String.fromCharCodes(h.sublist(4, 8)) == 'ftyp') {
      return 'HEIF(${String.fromCharCodes(h.sublist(8, 12))}), $kb';
    }
    if (h.length >= 4 && h[0] == 0x89 && h[1] == 0x50) return 'PNG, $kb';
    if (h.length >= 12 && String.fromCharCodes(h.sublist(8, 12)) == 'WEBP') {
      return 'WebP, $kb';
    }
    final hex = h.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'desconocido($hex), $kb';
  } catch (_) {
    return 'ilegible';
  }
}

/// Parsea el formato EXIF `YYYY:MM:DD HH:MM:SS` (hora local, sin zona).
DateTime? parseExifDateTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  if (v[0] < 1970 || v[1] < 1 || v[1] > 12 || v[2] < 1 || v[2] > 31) {
    return null; // p. ej. "0000:00:00 00:00:00" en cámaras sin reloj
  }
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}

// ─── Vídeos (MP4 / MOV) ───────────────────────────────────────────────────────

/// Segundos entre la época de QuickTime (1904-01-01 UTC) y la Unix.
const _qtEpochOffset = 2082844800;

/// Lee `creation_time` del átomo `moov/mvhd` de un MP4/MOV (formato ISO BMFF).
///
/// Sólo lee las cabeceras de las cajas saltando su contenido, así que no
/// carga el vídeo en memoria aunque el `moov` esté al final del fichero.
Future<DateTime?> readMp4CreationDate(File file) async {
  final raf = await file.open();
  try {
    final length = await raf.length();
    final moov = await _findBox(raf, 'moov', 0, length);
    if (moov == null) return null;
    final mvhd = await _findBox(raf, 'mvhd', moov.$1, moov.$2);
    if (mvhd == null) return null;

    await raf.setPosition(mvhd.$1);
    final head = await raf.read(12);
    if (head.length < 8) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(head));
    final version = bd.getUint8(0); // seguido de 3 bytes de flags
    final int secs;
    if (version == 1) {
      if (head.length < 12) return null;
      secs = bd.getUint64(4);
    } else {
      secs = bd.getUint32(4);
    }
    return qtSecondsToDateTime(secs);
  } finally {
    await raf.close();
  }
}

/// Convierte segundos desde 1904 a fecha local. Los móviles que no rellenan
/// el campo lo dejan a 0 (→ 1904), así que lo descartamos.
DateTime? qtSecondsToDateTime(int secs) {
  final unix = secs - _qtEpochOffset;
  if (unix <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    unix * 1000,
    isUtc: true,
  ).toLocal();
}

/// Busca una caja hija de tipo [type] entre [start] y [end].
/// Devuelve (inicio del contenido, fin de la caja).
Future<(int, int)?> _findBox(
  RandomAccessFile raf,
  String type,
  int start,
  int end,
) async {
  var pos = start;
  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final header = await raf.read(16);
    if (header.length < 8) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(header));
    var size = bd.getUint32(0);
    final boxType = String.fromCharCodes(header.sublist(4, 8));
    var headerLen = 8;
    if (size == 1) {
      if (header.length < 16) return null;
      size = bd.getUint64(8); // tamaño de 64 bits
      headerLen = 16;
    } else if (size == 0) {
      size = end - pos; // la caja llega hasta el final
    }
    if (size < headerLen) return null; // fichero corrupto
    if (boxType == type) return (pos + headerLen, pos + size);
    pos += size;
  }
  return null;
}

// ─── Utilidades para la UI ────────────────────────────────────────────────────

/// Resultado de comprobar la fecha leída frente al rango del selector.
sealed class CaptureDateCheck {
  const CaptureDateCheck();
}

/// No se encontró fecha en el fichero.
class NoCaptureDate extends CaptureDateCheck {
  const NoCaptureDate();
}

/// Fecha válida, normalizada a día.
class ValidCaptureDate extends CaptureDateCheck {
  final DateTime date;
  const ValidCaptureDate(this.date);
}

/// Se encontró fecha, pero el selector no la admite (antes del nacimiento o
/// en el futuro). Se informa al usuario en lugar de descartarla en silencio.
class OutOfRangeCaptureDate extends CaptureDateCheck {
  final DateTime date;
  final bool beforeBirth;
  const OutOfRangeCaptureDate(this.date, {required this.beforeBirth});
}

/// Comprueba la fecha leída frente al rango del selector de fecha del hito
/// (`[babyDob, hoy]`).
CaptureDateCheck checkCaptureDate(DateTime? captured, DateTime? babyDob) {
  if (captured == null) return const NoCaptureDate();
  final day = DateTime(captured.year, captured.month, captured.day);
  final now = DateTime.now();
  if (day.isAfter(DateTime(now.year, now.month, now.day))) {
    return OutOfRangeCaptureDate(day, beforeBirth: false);
  }
  if (babyDob != null &&
      day.isBefore(DateTime(babyDob.year, babyDob.month, babyDob.day))) {
    return OutOfRangeCaptureDate(day, beforeBirth: true);
  }
  return ValidCaptureDate(day);
}

/// Atajo: la fecha si es válida, `null` en otro caso.
DateTime? captureDateWithin(DateTime? captured, DateTime? babyDob) =>
    switch (checkCaptureDate(captured, babyDob)) {
      ValidCaptureDate(:final date) => date,
      _ => null,
    };

/// Mensaje para el usuario cuando la fecha leída no se puede usar.
String outOfRangeMessage(OutOfRangeCaptureDate c, String mediaType) {
  const m = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final what = mediaType == 'video' ? 'El vídeo' : 'La foto';
  final when = '${c.date.day} ${m[c.date.month - 1]} ${c.date.year}';
  return c.beforeBirth
      ? '$what es del $when, antes del nacimiento. Elige la fecha a mano.'
      : '$what tiene una fecha futura ($when). Elige la fecha a mano.';
}
