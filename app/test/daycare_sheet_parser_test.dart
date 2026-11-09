import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/daycare_scan/daycare_sheet_parser.dart';

final day = DateTime(2026, 11, 9);
DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 9, h, m);

List<(DateTime, DateTime)> ranges(String text) =>
    parseNapRanges(text, day).map((n) => (n.start, n.end)).toList();

void main() {
  group('hoja de ejemplo', () {
    test('solo la siesta: el resto del texto se ignora', () {
      const ocr = 'ALIMENTACIÓ\nTot 1 Tot\nx2\nDESCANS\n12:20-14:15\nDEPOSICIONS\nOBSERVACIONS';
      final naps = parseNapRanges(ocr, day);
      expect(naps, hasLength(1));
      expect(naps.single.start, at(12, 20));
      expect(naps.single.end, at(14, 15));
      expect(naps.single.source, '12:20-14:15');
    });

    test('da igual en qué fila esté o si el OCR parte el rango en dos líneas', () {
      expect(ranges('ALIMENTACIÓ 12:20 -\n14:15 Tot'), [(at(12, 20), at(14, 15))]);
      expect(ranges('12:20\n14:15'), [(at(12, 20), at(14, 15))]);
    });

    test('el "x2" de la línea anterior no se come la hora', () {
      expect(ranges('Tot 1 Tot\nx2\n12:20-14:15'), [(at(12, 20), at(14, 15))]);
      expect(ranges('Tot 1 Tot\nx2\n1220-1415'), [(at(12, 20), at(14, 15))]);
    });
  });

  group('lecturas imperfectas del OCR', () {
    for (final text in [
      '12:20-14:15',
      '12:20 - 14:15',
      '12.20-14.15',
      '12,20 – 14,15',
      '12h20-14h15',
      '1220-1415',
      '12:20 a 14:15',
      '12:20 al 14:15',
      '12:20—14:15',
      '12 :20-14: 15',
      'l2:2O-14:l5',
      'I2:20-I4:I5',
    ]) {
      test('"$text"', () => expect(ranges(text), [(at(12, 20), at(14, 15))]));
    }
  });

  group('formato de 12 h', () {
    test('la hora de fin de la tarde sin 24 h', () {
      expect(ranges('12:20-2:15'), [(at(12, 20), at(14, 15))]);
      expect(ranges('1:00-3:00'), [(at(13), at(15))]);
    });

    test('la mañana se queda como está', () {
      expect(ranges('9:30-10:15'), [(at(9, 30), at(10, 15))]);
    });
  });

  test('varias siestas, ordenadas y sin duplicados', () {
    expect(ranges('15:00-15:40\n10:00-10:45\n10:00 - 10:45'), [
      (at(10), at(10, 45)),
      (at(15), at(15, 40)),
    ]);
  });

  group('se descarta', () {
    for (final text in [
      'Tot 1 Tot x2', // texto sin horas
      '12:20', // hora suelta
      '1220 1415', // números sin guion ni separador
      '25:00-26:00', // hora imposible
      '12:75-13:20', // minutos imposibles
      '12:20-12:25', // demasiado corta
      '09:00-14:30', // demasiado larga
      '14:15-12:20', // al revés
      '112:20-14:15', // forma parte de un número más largo
    ]) {
      test('"$text"', () => expect(ranges(text), isEmpty));
    }
  });

  test('moveNapToDay conserva la hora del reloj', () {
    final nap = parseNapRanges('12:20-14:15', day).single;
    final moved = moveNapToDay(nap, DateTime(2026, 11, 7));
    expect(moved.start, DateTime(2026, 11, 7, 12, 20));
    expect(moved.end, DateTime(2026, 11, 7, 14, 15));
  });

  group('solape con siestas ya registradas', () {
    final nap = ScannedNap(start: at(12, 20), end: at(14, 15), source: '');
    Map<String, dynamic> ev(String category, DateTime start, [DateTime? end]) => {
          'category': category,
          'start_time': start.toUtc().toIso8601String(),
          'end_time': end?.toUtc().toIso8601String(),
        };

    test('pisa una siesta', () {
      expect(overlapsExistingNap(nap, [ev('nap', at(13), at(14))]), isTrue);
    });

    test('una siesta en curso cuenta hasta ahora', () {
      expect(overlapsExistingNap(nap, [ev('nap', at(12))], now: at(12, 30)), isTrue);
      expect(overlapsExistingNap(nap, [ev('nap', at(11))], now: at(12)), isFalse);
    });

    test('no cuenta si es contigua o de otra categoría', () {
      expect(overlapsExistingNap(nap, [ev('nap', at(10), at(12, 20))]), isFalse);
      expect(overlapsExistingNap(nap, [ev('feed', at(13))]), isFalse);
    });
  });
}
