import 'package:app/core/network/api_service.dart';
import 'package:app/features/analytics/views/widgets/category_selector.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la predicción conserva el bloque de feedback al guardarse en el evento', () {
    final prediction = SleepPrediction.fromJson({
      'type': 'nap',
      'index': 2,
      'start': '2026-03-01T12:00:00Z',
      'end': '2026-03-01T13:30:00Z',
      'predicted_feedback': {'start_bias_min': 4.5, 'catnap': false},
    });

    final meta = prediction.toPredictionMetadata();

    expect(meta['predicted_start_time'], '2026-03-01T12:00:00.000Z');
    expect(meta['predicted_end_time'], '2026-03-01T13:30:00.000Z');
    expect(meta['nap_index'], 2);
    expect(meta['predicted_feedback'], {'start_bias_min': 4.5, 'catnap': false});
    // El formulario de edición conserva estas claves: todas deben empezar por predicted_ o ser nap_index
    expect(meta.keys.every((k) => k.startsWith('predicted_') || k == 'nap_index'), isTrue);
  });

  test('la predicción lee su margen (start_range) y lo formatea', () {
    final prediction = SleepPrediction.fromJson({
      'type': 'bedtime',
      'start': '2026-03-01T19:30:00Z',
      'start_range': {'earliest': '2026-03-01T19:15:00Z', 'latest': '2026-03-01T19:45:00Z'},
    });
    expect(prediction.earliest, DateTime.parse('2026-03-01T19:15:00Z').toLocal());
    expect(prediction.latest, DateTime.parse('2026-03-01T19:45:00Z').toLocal());
    final from = prediction.earliest!, to = prediction.latest!;
    expect(prediction.rangeLabel,
        'entre ${from.hour}:${from.minute.toString().padLeft(2, '0')} y ${to.hour}:${to.minute.toString().padLeft(2, '0')}');

    final legacy = SleepPrediction.fromJson({'type': 'bedtime', 'start': '2026-03-01T19:30:00Z'});
    expect(legacy.rangeLabel, isNull);
  });

  test('todas las etiquetas de estadísticas tienen código de API', () {
    for (final entry in StatsCategorySelector.subCategories.entries) {
      expect(ApiService.statCategoryCodes, contains(entry.key));
      for (final sub in entry.value) {
        expect(ApiService.statSubcategoryCodes, contains(sub), reason: '${entry.key}/$sub');
      }
    }
  });
}
