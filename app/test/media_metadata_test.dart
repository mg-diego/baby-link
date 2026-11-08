import 'dart:io';
import 'dart:typed_data';

import 'package:app/features/milestones/services/media_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

/// Construye una caja ISO BMFF: tamaño (u32) + tipo + contenido.
Uint8List _box(String type, List<int> payload) {
  final b = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, payload.length + 8)).buffer.asUint8List())
    ..add(type.codeUnits)
    ..add(payload);
  return b.toBytes();
}

/// `mvhd` versión 0 con `creation_time` = [qtSecs].
Uint8List _mvhdV0(int qtSecs) {
  final d = ByteData(100)
    ..setUint8(0, 0)
    ..setUint32(4, qtSecs);
  return _box('mvhd', d.buffer.asUint8List());
}

/// `mvhd` versión 1 (campos de 64 bits).
Uint8List _mvhdV1(int qtSecs) {
  final d = ByteData(112)
    ..setUint8(0, 1)
    ..setUint64(4, qtSecs);
  return _box('mvhd', d.buffer.asUint8List());
}

const _qtOffset = 2082844800;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('media_meta'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${tmp.path}/$name')..writeAsBytesSync(bytes);

  group('parseExifDateTime', () {
    test('parsea el formato EXIF estándar como hora local', () {
      expect(
        parseExifDateTime('2025:03:14 09:26:53'),
        DateTime(2025, 3, 14, 9, 26, 53),
      );
    });

    test('descarta valores vacíos o a cero', () {
      expect(parseExifDateTime(null), isNull);
      expect(parseExifDateTime(''), isNull);
      expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
      expect(parseExifDateTime('basura'), isNull);
    });
  });

  group('readMp4CreationDate', () {
    final when = DateTime.utc(2025, 6, 1, 18, 30);
    final qtSecs = when.millisecondsSinceEpoch ~/ 1000 + _qtOffset;

    test('lee mvhd v0 con moov al final (típico de Android)', () async {
      final bytes = [
        ..._box('ftyp', 'isom0000'.codeUnits),
        ..._box('mdat', List.filled(4096, 7)),
        ..._box('moov', _mvhdV0(qtSecs)),
      ];
      final date = await readMp4CreationDate(write('a.mp4', bytes));
      expect(date, when.toLocal());
    });

    test('lee mvhd v1 con otras cajas delante dentro de moov', () async {
      final bytes = [
        ..._box('ftyp', 'qt  0000'.codeUnits),
        ..._box('moov', [..._box('udta', [1, 2, 3]), ..._mvhdV1(qtSecs)]),
        ..._box('mdat', [0, 0]),
      ];
      final date = await readMp4CreationDate(write('b.mov', bytes));
      expect(date, when.toLocal());
    });

    test('creation_time a 0 → null', () async {
      final bytes = _box('moov', _mvhdV0(0));
      expect(await readMp4CreationDate(write('c.mp4', bytes)), isNull);
    });

    test('fichero que no es MP4 → null sin lanzar', () async {
      final f = write('d.jpg', List.filled(64, 0xFF));
      expect(await readCaptureDate(f, 'video'), isNull);
      expect(await readCaptureDate(f, 'image'), isNull);
    });
  });

  group('captureDateWithin', () {
    final dob = DateTime(2025, 1, 10);

    test('normaliza a día', () {
      expect(
        captureDateWithin(DateTime(2025, 2, 3, 22, 15), dob),
        DateTime(2025, 2, 3),
      );
    });

    test('descarta fechas antes del nacimiento o en el futuro', () {
      expect(captureDateWithin(DateTime(2024, 12, 1), dob), isNull);
      expect(
        captureDateWithin(DateTime.now().add(const Duration(days: 2)), dob),
        isNull,
      );
      expect(captureDateWithin(null, dob), isNull);
    });

    test('el mismo día del nacimiento es válido', () {
      expect(captureDateWithin(DateTime(2025, 1, 10, 3), dob), dob);
    });
  });
}
