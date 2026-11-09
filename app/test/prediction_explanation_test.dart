import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/widgets/home_screen/prediction_explanation.dart';

/// Hora local -> ISO UTC, como la envía la API.
String iso(int h, int m, {int day = 10}) => DateTime(2026, 11, day, h, m).toUtc().toIso8601String();

final now = DateTime(2026, 11, 10, 7, 30);

SleepPrediction pred(Map<String, dynamic> json) => SleepPrediction.fromJson(json);

List<String> texts(PredictionExplanation e) => e.reasons.map((r) => r.text).toList();

void main() {
  group('siesta', () {
    final firstNap = {
      'type': 'nap',
      'index': 1,
      'start': iso(9, 40),
      'end': iso(10, 55),
      'start_range': {'earliest': iso(9, 25), 'latest': iso(9, 55)},
      'basis': {
        'from': 'wake', 'from_time': iso(7, 0), 'from_predicted': false,
        'window_min': 160, 'usual_window_min': 160, 'shortened_min': 0,
        'duration_min': 75, 'usual_duration_min': 75, 'nap_count': 2, 'rescue': false,
        'correction_min': 0, 'days': 21, 'day_type': 'weekday',
      },
    };

    test('dice a qué hora, con qué margen y por qué', () {
      final e = PredictionExplanation.of(pred(firstNap), now: now);
      expect(e.title, 'Siesta 1 de 2');
      expect(e.time, '09:40 – 10:55');
      expect(e.subtitle, 'Hoy · en 2 h 10 min');
      expect(e.range, 'Lo más probable: entre 09:25 y 09:55');
      expect(texts(e), [
        'Se despertó a las 07:00',
        'Por la mañana suele aguantar 2 h 40 min despierto',
        'Suele dormir 1 h 15 min en esta siesta',
      ]);
      expect(e.footer, 'Calculado con sus últimos 21 días de registros.');
    });

    test('menciona la compensación y la corrección solo cuando mueven la hora', () {
      final json = {
        ...firstNap,
        'index': 2,
        'basis': {
          ...firstNap['basis'] as Map<String, dynamic>,
          'from': 'nap', 'from_time': iso(10, 55), 'from_predicted': true,
          'shortened_min': 20, 'correction_min': -12,
        },
      };
      final t = texts(PredictionExplanation.of(pred(json), now: now));
      expect(t.first, 'La siesta anterior debería terminar hacia las 10:55');
      expect(t, contains('Hoy se adelanta 20 min: ha dormido menos de lo habitual en las siestas'));
      expect(t, contains('12 min más pronto: últimamente se dormía antes de lo previsto'));

      final small = {...json, 'basis': {...json['basis'] as Map<String, dynamic>, 'shortened_min': 3, 'correction_min': 4}};
      final t2 = texts(PredictionExplanation.of(pred(small), now: now));
      expect(t2.any((s) => s.contains('adelanta') || s.contains('previsto')), isFalse);
    });

    test('siesta de rescate y siesta atrasada', () {
      final rescue = {
        ...firstNap,
        'index': 3,
        'is_catnap': true,
        'overdue': true,
        'basis': {...firstNap['basis'] as Map<String, dynamic>, 'rescue': true},
      };
      final e = PredictionExplanation.of(pred(rescue), now: DateTime(2026, 11, 10, 10));
      expect(e.title, 'Siesta corta extra');
      expect(e.subtitle, 'Ya es la hora');
      expect(texts(e).last, contains('sin una siesta corta la noche llegaría demasiado pronto'));
    });

    test('siesta sin registrar cuyo hueco ya pasó (guardería)', () {
      final p = pred({...firstNap, 'assumed': true, 'overdue': false});
      expect(p.assumed, isTrue);
      final e = PredictionExplanation.of(p, now: DateTime(2026, 11, 10, 15));
      expect(e.subtitle, 'Sin registrar · se cuenta como hecha a su hora');
      expect(pred(firstNap).assumed, isFalse); // respuestas antiguas sin el campo
    });
  });

  test('hora de dormir: cada criterio con su peso', () {
    final e = PredictionExplanation.of(pred({
      'type': 'bedtime',
      'start': iso(20, 15),
      'basis': {
        'from': 'nap', 'from_time': iso(15, 30), 'from_predicted': true,
        'window_min': 270, 'usual_window_min': 270, 'by_window': iso(20, 0),
        'routine_time': iso(20, 20), 'routine_weight': 0.41,
        'by_day_length': iso(20, 30), 'day_length_min': 810, 'day_length_weight': 0.28,
        'correction_min': 0, 'days': 5,
      },
    }), now: now);
    expect(e.title, 'Hora de dormir prevista');
    expect(e.reasons.map((r) => r.weightPercent).whereType<int>().toList(), [31, 41, 28]);
    expect(texts(e), [
      'La siesta anterior debería terminar hacia las 15:30',
      'Después de la última siesta suele aguantar 4 h 30 min despierto (20:00)',
      'Suele acostarse sobre las 20:20',
      'Su día suele durar 13 h 30 min desde que se despierta (20:30)',
    ]);
    expect(e.footer, contains('pocos días'));
  });

  test('hora de dormir solo por ventana: sin porcentajes', () {
    final e = PredictionExplanation.of(pred({
      'type': 'bedtime',
      'start': iso(19, 30),
      'basis': {
        'from': 'nap', 'from_time': iso(15, 30), 'from_predicted': false,
        'usual_window_min': 240, 'by_window': iso(19, 30),
        'routine_time': iso(20, 0), 'routine_weight': 0.05, 'day_length_weight': 0.0,
      },
    }), now: now);
    expect(texts(e), [
      'La última siesta terminó a las 15:30',
      'Después de la última siesta suele aguantar 4 h despierto',
    ]);
    expect(e.reasons.every((r) => r.weightPercent == null), isTrue);
  });

  test('despertar tras una noche real', () {
    final e = PredictionExplanation.of(pred({
      'type': 'woke_up',
      'start': iso(7, 50, day: 11),
      'basis': {
        'bed': iso(20, 10), 'bed_predicted': false,
        'usual_time': iso(8, 0, day: 11), 'by_night': iso(7, 40, day: 11),
        'night_min': 690, 'night_weight': 0.5, 'correction_min': 6, 'days': 28,
      },
    }), now: DateTime(2026, 11, 10, 21));
    expect(e.title, 'Despertar previsto');
    expect(e.subtitle, 'Mañana · en 10 h 50 min');
    expect(texts(e), [
      'Se acostó a las 20:10',
      'Suele despertarse sobre las 08:00',
      'Suele dormir 11 h 30 min por la noche (07:40)',
      '6 min más tarde: últimamente se despertaba después de lo previsto',
    ]);
  });

  test('respuesta antigua sin basis: cabecera y margen, sin motivos', () {
    final e = PredictionExplanation.of(pred({'type': 'bedtime', 'start': iso(20, 0)}), now: now);
    expect(e.time, '20:00');
    expect(e.range, isNull);
    expect(e.reasons, isEmpty);
    expect(e.footer, isNull);
  });
}
