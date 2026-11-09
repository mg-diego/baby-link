import 'package:app/features/events/widgets/visual_clock/visual_clock_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> ev(String category, DateTime local) =>
    {'category': category, 'start_time': local.toUtc().toIso8601String()};

void main() {
  final day = DateTime(2026, 3, 10);
  final today = [
    ev('woke_up', DateTime(2026, 3, 10, 7)),
    ev('nap', DateTime(2026, 3, 10, 13)),
    ev('bed_time', DateTime(2026, 3, 10, 20)),
    ev('feed', DateTime(2026, 3, 10, 23)),
  ];
  final tomorrow = [
    ev('night_waking', DateTime(2026, 3, 11, 3)),
    ev('woke_up', DateTime(2026, 3, 11, 6, 45)),
    ev('nap', DateTime(2026, 3, 11, 10)),
  ];

  test('la noche termina en el primer despertar del día siguiente', () {
    final range = VisualClockLogic.computeRange(
      events: today,
      yesterdayEvents: const [],
      tomorrowEvents: tomorrow,
      selectedDate: day,
      isDayMode: false,
      forceNightMode: null,
    );
    expect(range.start, DateTime(2026, 3, 10, 20));
    expect(range.end, DateTime(2026, 3, 11, 6, 45));
  });

  test('sin datos de mañana (hoy) se estima el final de la noche', () {
    final range = VisualClockLogic.computeRange(
      events: today,
      yesterdayEvents: const [],
      selectedDate: day,
      isDayMode: false,
      forceNightMode: null,
    );
    expect(range.start, DateTime(2026, 3, 10, 20));
    expect(range.end, DateTime(2026, 3, 11, 7, 30));
  });

  test('si hoy no hay bed_time, la noche es la anterior (de ayer a hoy)', () {
    final range = VisualClockLogic.computeRange(
      events: today.where((e) => e['category'] != 'bed_time').toList(),
      yesterdayEvents: [ev('bed_time', DateTime(2026, 3, 9, 19, 30))],
      tomorrowEvents: tomorrow,
      selectedDate: day,
      isDayMode: false,
      forceNightMode: null,
    );
    expect(range.start, DateTime(2026, 3, 9, 19, 30));
    expect(range.end, DateTime(2026, 3, 10, 7));
  });

  test('noche en curso: el final es el despertar previsto, también tras medianoche', () {
    final bed = [ev('bed_time', DateTime(2026, 3, 10, 20))];
    final predicted = DateTime(2026, 3, 11, 7, 6);

    // Antes de medianoche: el día de referencia es el de acostarse
    final before = VisualClockLogic.computeRange(
      events: bed,
      yesterdayEvents: const [],
      selectedDate: day,
      isDayMode: false,
      forceNightMode: true,
      predictedWake: predicted,
    );
    // Después de medianoche: el bed_time ya es de "ayer"
    final after = VisualClockLogic.computeRange(
      events: [ev('night_waking', DateTime(2026, 3, 11, 0, 30))],
      yesterdayEvents: bed,
      selectedDate: DateTime(2026, 3, 11),
      isDayMode: false,
      forceNightMode: true,
      predictedWake: predicted,
    );
    expect(before.end, predicted);
    expect(after.end, predicted);
  });

  test('un despertar previsto que no pertenece a esta noche se ignora', () {
    final range = VisualClockLogic.computeRange(
      events: today,
      yesterdayEvents: const [],
      selectedDate: day,
      isDayMode: false,
      forceNightMode: null,
      predictedWake: DateTime(2026, 3, 20, 7),
    );
    expect(range.end, DateTime(2026, 3, 11, 7, 30));
  });
}
