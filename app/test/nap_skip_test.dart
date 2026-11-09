import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/views/nap_skip_actions.dart';
import 'package:app/features/events/widgets/home_screen/prediction_explanation.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_logic.dart';
import 'package:app/shared/models/event_type.dart';

DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 10, h, m);

SleepPrediction nap(int index, DateTime start, {bool overdue = false, bool assumed = false}) => SleepPrediction(
      type: 'nap',
      index: index,
      start: start,
      end: start.add(const Duration(minutes: 90)),
      overdue: overdue,
      assumed: assumed,
    );

void main() {
  group('cuándo se puede marcar como no hecha', () {
    final now = at(12);

    test('la próxima siesta, cuando ya le ha llegado la hora', () {
      final overdue = nap(1, now, overdue: true);
      final assumed = nap(1, at(9, 30), assumed: true);
      expect(canSkipNap(overdue, [overdue, nap(2, at(16))], now), isTrue);
      expect(canSkipNap(assumed, [assumed, nap(2, at(14))], now), isTrue);
    });

    test('no una que aún no toca, ni una posterior, ni la hora de dormir', () {
      final upcoming = nap(1, at(13));
      final later = nap(2, at(16));
      expect(canSkipNap(upcoming, [upcoming, later], now), isFalse);
      expect(canSkipNap(later, [nap(1, now, overdue: true), later], now), isFalse);
      final bed = SleepPrediction(type: 'bedtime', start: at(11));
      expect(canSkipNap(bed, [bed], now), isFalse);
    });
  });

  test('el reloj cuenta las siestas no hechas como turno ocupado', () {
    Map<String, dynamic> ev(String c, DateTime t) => {'category': c, 'start_time': t.toUtc().toIso8601String()};
    final preds = [nap(1, at(9, 30)), nap(2, at(12, 30))];
    final shown = VisualClockLogic.getNapPredictions(preds, [ev('woke_up', at(7)), ev('nap_skipped', at(9, 30))]);
    expect(shown.map((p) => p.index), [2]);
  });

  test('el tipo existe, pero no se ofrece en la lista del "+"', () {
    expect(EventType.fromBackend('nap_skipped', const {}), EventType.napSkipped);
    expect(EventType.napSkipped.isLoggable, isFalse);
    expect(EventType.nap.isLoggable, isTrue);
  });

  test('la explicación dice desde qué siesta no hecha se cuenta', () {
    final p = SleepPrediction.fromJson({
      'type': 'nap',
      'index': 2,
      'start': at(12, 30).toUtc().toIso8601String(),
      'end': at(14).toUtc().toIso8601String(),
      'basis': {
        'from': 'skipped', 'from_time': at(9, 30).toUtc().toIso8601String(), 'from_predicted': false,
        'window_min': 180, 'usual_window_min': 180, 'shortened_min': 0,
        'duration_min': 90, 'usual_duration_min': 90, 'nap_count': 2, 'rescue': false,
        'correction_min': 0, 'days': 14,
      },
    });
    final texts = PredictionExplanation.of(p, now: at(10)).reasons.map((r) => r.text).toList();
    expect(texts.first, 'No hizo la siesta de las 09:30: se cuenta desde entonces');
  });
}
