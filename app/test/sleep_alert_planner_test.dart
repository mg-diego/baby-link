import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/notifications/sleep_alert_planner.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 8, 9, 0);
  DateTime at(int h, int m) => DateTime(2026, 11, 8, h, m);

  final schedule = [
    SleepPrediction(type: 'nap', index: 1, start: at(10, 30), end: at(11, 30)),
    SleepPrediction(type: 'nap', index: 2, start: at(14, 0), end: at(14, 30), isCatnap: true),
    SleepPrediction(type: 'bedtime', start: at(20, 15)),
  ];

  const all = SleepAlertSettings(
    napsEnabled: true,
    napLeadMinutes: 15,
    bedtimeEnabled: true,
    bedtimeLeadMinutes: 30,
  );

  test('avisa el margen elegido antes de cada siesta y de la hora de dormir', () {
    final alerts = planSleepAlerts(schedule, all, now);

    expect(alerts.map((a) => a.fireAt), [at(10, 15), at(13, 45), at(19, 45)]);
    expect(alerts.map((a) => a.title), [
      'Siesta en 15 min',
      'Siesta corta en 15 min',
      'Hora de dormir en 30 min',
    ]);
    expect(alerts.first.body, 'Prevista a las 10:30');
    expect(alerts.map((a) => a.id).toSet().length, alerts.length);
  });

  test('respeta qué avisos están activados', () {
    final onlyBed = planSleepAlerts(schedule, all.copyWith(napsEnabled: false), now);
    expect(onlyBed.map((a) => a.title), ['Hora de dormir en 30 min']);

    expect(planSleepAlerts(schedule, const SleepAlertSettings(), now), isEmpty);
  });

  test('no avisa si la hora del aviso ya ha pasado', () {
    // 10:20: el aviso de la 1ª siesta (10:15) ya pasó, aunque la siesta no
    final alerts = planSleepAlerts(schedule, all, at(10, 20));
    expect(alerts.map((a) => a.fireAt), [at(13, 45), at(19, 45)]);
  });

  test('ignora el despertar previsto y la agenda vacía (noche)', () {
    final wake = [SleepPrediction(type: 'woke_up', start: at(23, 0))];
    expect(planSleepAlerts(wake, all, now), isEmpty);
    expect(planSleepAlerts(const [], all, now), isEmpty);
  });

  test('lee is_catnap del JSON de la API', () {
    final p = SleepPrediction.fromJson({
      'type': 'nap',
      'start': '2026-11-08T13:00:00Z',
      'is_catnap': true,
    });
    expect(p.isCatnap, isTrue);
  });
}
