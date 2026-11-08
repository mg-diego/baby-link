import 'package:app/features/milestones/services/upload_progress.dart';
import 'package:app/features/milestones/views/widgets/save_progress_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(SaveProgressButton b) =>
    MaterialApp(home: Scaffold(body: Center(child: b)));

LinearProgressIndicator _bar(WidgetTester t) =>
    t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

void main() {
  testWidgets('en reposo es un botón pulsable', (t) async {
    var taps = 0;
    await t.pumpWidget(_host(SaveProgressButton(
      label: 'Guardar recuerdo',
      busy: false,
      progress: null,
      onPressed: () => taps++,
    )));
    await t.tap(find.text('Guardar recuerdo'));
    expect(taps, 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('compresión de vídeo muestra porcentaje y barra determinada',
      (t) async {
    await t.pumpWidget(_host(SaveProgressButton(
      label: 'Guardar recuerdo',
      busy: true,
      progress: const UploadProgress(
        UploadPhase.compressing,
        fraction: 0.42,
        mediaType: 'video',
      ),
      onPressed: () {},
    )));
    await t.pumpAndSettle();
    expect(find.text('Comprimiendo vídeo · 42 %'), findsOneWidget);
    expect(_bar(t).value, closeTo(0.42, 1e-9));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('subida sin avance medible → barra indeterminada', (t) async {
    await t.pumpWidget(_host(SaveProgressButton(
      label: 'Guardar recuerdo',
      busy: true,
      progress: const UploadProgress(UploadPhase.uploading, mediaType: 'image'),
      onPressed: () {},
    )));
    await t.pump();
    expect(find.text('Subiendo foto'), findsOneWidget);
    expect(_bar(t).value, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
