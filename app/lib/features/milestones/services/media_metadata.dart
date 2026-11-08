import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';

/// Intenta averiguar cuándo se tomó una foto o se grabó un vídeo leyendo los
/// metadatos del propio fichero. Devuelve `null` si no hay fecha fiable.
///
/// Es "best effort": nunca lanza.
Future<DateTime?> readCaptureDate(File file, String mediaType) async {
  try {
    return switch (mediaType) {
      'image' => await _readImageDate(file),
      'video' => await readMp4CreationDate(file),
      _ => null,
    };
  } catch (_) {
    return null;
  }
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
  final tags = await readExifFromFile(file);
  for (final key in _exifDateTags) {
    final date = parseExifDateTime(tags[key]?.printable);
    if (date != null) return date;
  }
  return null;
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
  return DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true)
      .toLocal();
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

/// Ajusta la fecha leída al rango que admite el selector de fecha del hito
/// (`[babyDob, hoy]`). Si cae fuera, devuelve `null` para no preasignarla.
DateTime? captureDateWithin(DateTime? captured, DateTime? babyDob) {
  if (captured == null) return null;
  final day = DateTime(captured.year, captured.month, captured.day);
  final now = DateTime.now();
  if (day.isAfter(DateTime(now.year, now.month, now.day))) return null;
  if (babyDob != null &&
      day.isBefore(DateTime(babyDob.year, babyDob.month, babyDob.day))) {
    return null;
  }
  return day;
}
