import 'package:app/features/analytics/providers/daily_summary_provider.dart';
import 'package:app/features/analytics/views/stats_screen.dart';
import 'package:app/features/analytics/views/widgets/chart_widgets.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

List<String> _days(int n) => List.generate(n, (i) => '${i + 1} Abr');

Map<String, dynamic> _chart(String type, List<String> x, List<Map<String, dynamic>> series, String unit) => {
      'id': '$type-$unit',
      'title': 'Un título de gráfica bastante largo para ver si se corta en pantallas pequeñas',
      'type': type,
      'data': {'x_labels': x, 'series': series, 'unit': unit},
    };

Map<String, dynamic> _s(String name, List<num?> data) => {'name': name, 'data': data};

final _payload = <String, dynamic>{
  'summary_cards': [
    {'label': 'Sueño total/día', 'value': '13h 46m', 'trend': null},
    {'label': 'Peso actual', 'value': '10,5 kg', 'trend': '+0,7'},
    {'label': 'Media por biberón', 'value': '1206 ml', 'trend': '-120'},
    {'label': 'Noches sin despertar muy largas', 'value': '16 de 30', 'trend': null},
    {'label': 'Comidas/día', 'value': '3,1', 'trend': null},
  ],
  'charts': [
    _chart('line', _days(31), [_s('Horas de siesta', [for (var i = 0; i < 31; i++) i % 5 == 0 ? null : 1 + i % 3])], 'hours'),
    _chart('line', _days(1), [_s('Sueño nocturno', [11.5])], 'hours'),
    _chart('line_multiple', _days(7), [
      for (var n = 1; n <= 5; n++) _s('Siesta $n', [for (var i = 0; i < 7; i++) n > 3 && i.isEven ? null : 0.5 * n]),
    ], 'hours'),
    _chart('line', ['15 Ene 25', '20 Ene 25', '28 Ene 25', '24 Feb 25', '2 Abr 26'], [_s('Peso', [2.88, 2.75, 3.04, 4.0, 10.5])], 'kg'),
    _chart('line', _days(7), [_s('Volumen', [390, 2200, 210, 410, 420, 420, 0])], 'ml'),
    _chart('stacked_bar', _days(31), [
      _s('Mojado', [for (var i = 0; i < 31; i++) i % 4]),
      _s('Sucio', [for (var i = 0; i < 31; i++) i % 2]),
      _s('Mixto', [for (var i = 0; i < 31; i++) i % 3 == 0 ? 1 : 0]),
      _s('Otro', [for (var i = 0; i < 31; i++) 0]),
    ], 'count'),
    _chart('stacked_bar', ['Siesta 1'], [_s('Duración media', [1.59])], 'hours'),
    _chart('stacked_bar', [for (var h = 0; h < 24; h++) '${h}h'], [_s('Despertares', [for (var h = 0; h < 24; h++) h % 7])], 'count'),
    _chart('stacked_bar', _days(7), [_s('Lactancia', [0, 0, 0, 0, 0, 0, 0])], 'minutes'),
    _chart('donut', ['Lactancia', 'Biberón', 'Sólidos'], [_s('Tomas', [92, 7, 0])], 'count'),
    _chart('donut', [for (var n = 1; n <= 8; n++) 'Siesta número $n con nombre largo'], [_s('Horas', [for (var n = 1; n <= 8; n++) n * 3.3])], 'hours'),
    _chart('donut', ['Izquierdo', 'Derecho'], [_s('Minutos', [0, 0])], 'minutes'),
    _chart('desconocido', _days(3), [], 'count'),
  ],
};

Widget _app(Map<String, dynamic>? payload) => ProviderScope(
      overrides: [
        statsProvider.overrideWith((ref) async => payload),
        validEventDatesProvider.overrideWith((ref, babyId) async => <DateTime>{}),
      ],
      child: const MaterialApp(home: StatsScreen(babyId: 'b')),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es');
  });

  for (final size in const [Size(320, 640), Size(412, 915)]) {
    testWidgets('pinta todas las gráficas sin desbordar a ${size.width.toInt()}dp', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_payload));
      await tester.pumpAndSettle();

      expect(find.text('13h 46m'), findsOneWidget);
      final list = find.byType(Scrollable).last;
      for (var i = 0; i < 40; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Gráfica no soportada'), findsOneWidget);
    });
  }

  testWidgets('listas vacías muestran el estado vacío', (tester) async {
    await tester.pumpWidget(_app({'summary_cards': [], 'charts': []}));
    await tester.pumpAndSettle();
    expect(find.text('Sin datos para este rango'), findsOneWidget);
  });

  test('formatChartValue respeta la unidad', () {
    expect(formatChartValue(1.5, ChartUnit.hours), '1h 30m');
    expect(formatChartValue(45, ChartUnit.minutes), '45 min');
    expect(formatChartValue(90, ChartUnit.minutes), '1h 30m');
    expect(formatChartValue(7, ChartUnit.count), '7');
    expect(formatChartValue(210, ChartUnit.ml), '210 ml');
    expect(formatChartValue(10.5, ChartUnit.kg), '10,5 kg');
    expect(formatChartValue(75, ChartUnit.cm), '75 cm');
  });
}
