import 'dart:async';
import 'package:app/features/milestones/providers/milestones_provider.dart';
import 'package:app/features/milestones/services/milestone_service.dart';
import 'package:app/features/milestones/views/milestones_screen.dart';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Svc implements MilestoneService {
  final Completer<List<Milestone>> c;
  _Svc(this.c);
  @override
  Future<List<Milestone>> fetchAll(String babyId) => c.future;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Milestone _m(String id, DateTime d, String cat) => Milestone(
  id: id,
  babyId: 'b',
  title: 'Primera sonrisa muy larga $id',
  date: d,
  category: cat,
  createdAt: DateTime(2026),
);

Widget _app(Completer<List<Milestone>> c) => ProviderScope(
  overrides: [
    milestoneServiceProvider.overrideWithValue(_Svc(c)),
    babyDobProvider.overrideWithValue(DateTime(2026, 1, 10)),
  ],
  child: MaterialApp(
    home: Scaffold(
      extendBody: true,
      body: const MilestonesScreen(babyId: 'b'),
      bottomNavigationBar: const SizedBox(height: 92),
    ),
  ),
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es');
  });

  testWidgets('loading → data', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    final c = Completer<List<Milestone>>();
    await tester.pumpWidget(_app(c));
    await tester.pump();
    expect(find.text('Recuerdos'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    c.complete([
      _m('1', DateTime(2026, 1, 20), 'physical'),
      _m('2', DateTime(2026, 3, 2), 'social'),
      _m('3', DateTime(2026, 3, 5), 'social'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 recuerdos'), findsOneWidget);
    expect(find.text('Marzo 2026'), findsOneWidget);
    expect(find.text('😊 Social'), findsOneWidget);

    await tester.tap(find.text('💪 Físico'));
    await tester.pump();
    expect(find.text('1 recuerdo'), findsOneWidget);
    expect(find.text('Marzo 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state above nav bar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    final c = Completer<List<Milestone>>()..complete([]);
    await tester.pumpWidget(_app(c));
    await tester.pump();
    await tester.pump();
    final btn = find.text('Añadir primer recuerdo');
    expect(btn, findsOneWidget);
    final screenH = 2340 / 3;
    expect(tester.getBottomLeft(btn).dy, lessThan(screenH - 92));
    expect(tester.takeException(), isNull);
  });
}
