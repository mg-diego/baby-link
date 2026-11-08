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

/// JPEG mínimo con un segmento APP1/EXIF que sólo contiene DateTimeOriginal
/// (TIFF big-endian: IFD0 -> puntero a ExifIFD -> tag 0x9003).
Uint8List _jpegWithExifDate(String exifDate) {
  final date = [...exifDate.codeUnits, 0]; // ASCII terminado en NUL (20 B)
  final tiff = ByteData(44 + date.length)
    // Cabecera TIFF
    ..setUint16(0, 0x4D4D) // 'MM'
    ..setUint16(2, 42)
    ..setUint32(4, 8) // offset IFD0
    // IFD0: 1 entrada, ExifIFDPointer (0x8769, LONG) -> 26
    ..setUint16(8, 1)
    ..setUint16(10, 0x8769)
    ..setUint16(12, 4)
    ..setUint32(14, 1)
    ..setUint32(18, 26)
    ..setUint32(22, 0)
    // ExifIFD: 1 entrada, DateTimeOriginal (0x9003, ASCII) -> 44
    ..setUint16(26, 1)
    ..setUint16(28, 0x9003)
    ..setUint16(30, 2)
    ..setUint32(32, date.length)
    ..setUint32(36, 44)
    ..setUint32(40, 0);
  final tiffBytes = tiff.buffer.asUint8List()..setAll(44, date);
  final app1 = [...'Exif'.codeUnits, 0, 0, ...tiffBytes];
  final len = app1.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, len >> 8, len & 0xFF, ...app1,
    0xFF, 0xD9, // EOI
  ]);
}

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
        ..._box('moov', [
          ..._box('udta', [1, 2, 3]),
          ..._mvhdV1(qtSecs),
        ]),
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

  group('readCaptureDate (imagen)', () {
    test('lee DateTimeOriginal de un JPEG real', () async {
      final f = write('foto.jpg', _jpegWithExifDate('2025:02:14 10:30:00'));
      expect(await readCaptureDate(f, 'image'), DateTime(2025, 2, 14, 10, 30));
    });

    test('sin EXIF cae al nombre del fichero (WhatsApp)', () async {
      final f = write('tmp_123.jpg', List.filled(64, 0xFF));
      expect(
        await readCaptureDate(
          f,
          'image',
          fileNames: ['IMG-20250214-WA0003.jpg'],
        ),
        DateTime(2025, 2, 14),
      );
    });

    test('el EXIF tiene prioridad sobre el nombre', () async {
      final f = write(
        'IMG_20240101_000000.jpg',
        _jpegWithExifDate('2025:02:14 10:30:00'),
      );
      expect((await readCaptureDate(f, 'image'))!.month, 2);
    });
  });

  group('parseDateFromFileName', () {
    test('formatos habituales', () {
      expect(
        parseDateFromFileName('IMG-20250214-WA0003.jpg'),
        DateTime(2025, 2, 14),
      );
      expect(
        parseDateFromFileName('PXL_20250214_103000123.jpg'),
        DateTime(2025, 2, 14),
      );
      expect(
        parseDateFromFileName('/cache/x/VID_20250214_103000.mp4'),
        DateTime(2025, 2, 14),
      );
      expect(
        parseDateFromFileName('Screenshot_2025-02-14-10-30-00.png'),
        DateTime(2025, 2, 14),
      );
      expect(
        parseDateFromFileName('foto_2025_02_14.jpg'),
        DateTime(2025, 2, 14),
      );
    });

    test('no inventa fechas', () {
      expect(parseDateFromFileName('image_picker_ABC123.jpg'), isNull);
      expect(parseDateFromFileName('20251399.jpg'), isNull); // mes 13
      expect(parseDateFromFileName('20250231.jpg'), isNull); // 31 feb
      expect(parseDateFromFileName('2025-0214.jpg'), isNull); // separador mixto
      expect(parseDateFromFileName('1234567890123.jpg'), isNull);
      expect(parseDateFromFileName(null), isNull);
    });
  });

  group('checkCaptureDate', () {
    final dob = DateTime(2026, 1, 31);

    test('antes del nacimiento se informa, no se descarta en silencio', () {
      final c = checkCaptureDate(DateTime(2025, 2, 14, 10), dob);
      expect(c, isA<OutOfRangeCaptureDate>());
      c as OutOfRangeCaptureDate;
      expect(c.beforeBirth, isTrue);
      expect(c.date, DateTime(2025, 2, 14));
      expect(outOfRangeMessage(c, 'image'), contains('14 feb 2025'));
    });

    test('sin fecha', () {
      expect(checkCaptureDate(null, dob), isA<NoCaptureDate>());
    });
  });

  group('fecha en bruto (formatos que el paquete exif no reconoce)', () {
    test('HEIF con marca mif1 (Android) y bloque EXIF dentro', () async {
      final jpeg = _jpegWithExifDate('2025:02:14 10:30:00');
      final exifPayload = jpeg.sublist(6, jpeg.length - 2); // Exif00 + TIFF
      final heif = [
        ..._box('ftyp', [
          ...'mif1'.codeUnits,
          0,
          0,
          0,
          0,
          ...'mif1heic'.codeUnits,
        ]),
        ..._box('meta', List.filled(200, 0)),
        ..._box('mdat', [...exifPayload, ...List.filled(5000, 0xAB)]),
      ];
      final f = write('1000012345.heic', heif);
      expect(await readCaptureDate(f, 'image'), DateTime(2025, 2, 14, 10, 30));
    });

    test('XMP (formato ISO) y se queda con la fecha más antigua', () async {
      final xmp =
          '<x:xmpmeta><rdf:Description '
          'xmp:ModifyDate="2026-11-08T09:00:00+01:00" '
          'xmp:CreateDate="2025-02-14T10:30:00+01:00"/></x:xmpmeta>';
      final f = write('edit.png', [0x89, 0x50, 0x4E, 0x47, ...xmp.codeUnits]);
      expect(await scanRawMetadataDate(f), DateTime(2025, 2, 14, 10, 30));
    });

    test('ignora relojes reiniciados y basura', () async {
      final f = write('x.jpg', [
        0xFF,
        0xD8,
        ...'2000:01:01 00:00:00 1970:01:01 00:00:00 2025:13:40 99:99:99'
            .codeUnits,
      ]);
      expect(await scanRawMetadataDate(f), isNull);
    });
  });

  group('fecha de la galería (Android datetaken)', () {
    test(
      'JPEG sin EXIF (180 KB de WhatsApp) usa la fecha de la galería',
      () async {
        final f = write('6136.jpg', [
          0xFF,
          0xD8,
          ...List.filled(500, 0),
          0xFF,
          0xD9,
        ]);
        expect(
          await readCaptureDate(
            f,
            'image',
            galleryDate: DateTime(2025, 2, 14, 18, 3),
            modifiedDate: DateTime(2026, 11, 8),
          ),
          DateTime(2025, 2, 14, 18, 3),
        );
      },
    );

    test('el EXIF del fichero tiene prioridad sobre la galería', () async {
      final f = write('a.jpg', _jpegWithExifDate('2025:02:10 08:00:00'));
      expect(
        await readCaptureDate(f, 'image', galleryDate: DateTime(2025, 3, 1)),
        DateTime(2025, 2, 10, 8),
      );
    });

    test('nombre antes que fecha de modificación', () async {
      final f = write('6137.jpg', [0xFF, 0xD8, 0xFF, 0xD9]);
      expect(
        await readCaptureDate(
          f,
          'image',
          fileNames: ['IMG-20250214-WA0003.jpg'],
          modifiedDate: DateTime(2026, 11, 8),
        ),
        DateTime(2025, 2, 14),
      );
      expect(
        await readCaptureDate(f, 'image', modifiedDate: DateTime(2025, 5, 1)),
        DateTime(2025, 5, 1),
      );
    });
  });
}
