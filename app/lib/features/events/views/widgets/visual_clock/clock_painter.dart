import 'dart:math' as math;
import 'package:app/core/models/event_type.dart';
import 'package:flutter/material.dart';
import 'package:app/features/events/providers/events_provider.dart'; // Para SleepPrediction
import 'clock_palette.dart';

class ClockPainter extends CustomPainter {
  final List<Map<String, dynamic>> events;
  final DateTime startTime;
  final DateTime endTime;
  final int totalMinutes;
  final double startAngle;
  final double sweepAngle;
  final bool isDayMode;
  final List<SleepPrediction> napPredictions;

  ClockPainter({
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.totalMinutes,
    required this.startAngle,
    required this.sweepAngle,
    required this.isDayMode,
    required this.napPredictions,
  });

  static const double _strokeW = 30.0;

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Paint paint,
  ) {
    const int dashes = 10;
    const double dashRatio = 0.55;
    final double seg = sweep / dashes;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(rect, start + i * seg, seg * dashRatio, false, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. TRACK INACTIVO
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = ClockPalette.trackBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap = StrokeCap.round,
    );

    // 2. ARCO PRINCIPAL
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = isDayMode ? ClockPalette.dayAccent : ClockPalette.nightAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap = StrokeCap.round,
    );

    // 3. SEGMENTOS DE DURACIÓN
    for (var event in events) {
      final cat = event['category'];
      final eventType = EventType.fromBackend(cat, event['metadata'] ?? {});

      final bool isRelevant =
          (isDayMode && cat == 'nap' && event['end_time'] != null) ||
          (!isDayMode && cat == 'night_waking' && event['end_time'] != null);
      if (!isRelevant) continue;

      final evStart = DateTime.parse(event['start_time']).toLocal();
      final evEnd = DateTime.parse(event['end_time']).toLocal();

      if (!evStart.isBefore(endTime) || !evEnd.isAfter(startTime)) continue;

      final cs = evStart.isBefore(startTime) ? startTime : evStart;
      final ce = evEnd.isAfter(endTime) ? endTime : evEnd;

      final sf = cs.difference(startTime).inMinutes / totalMinutes;
      final ef = ce.difference(startTime).inMinutes / totalMinutes;

      canvas.drawArc(
        rect,
        startAngle + (sf * sweepAngle),
        (ef - sf) * sweepAngle,
        false,
        Paint()
          ..color = eventType.accentColor.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeW * 1.25
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4. SIESTAS PREDICHAS
    if (isDayMode) {
      for (final pred in napPredictions) {
        final cs = pred.start.isBefore(startTime) ? startTime : pred.start;
        final ce = pred.end!.isAfter(endTime) ? endTime : pred.end!;
        if (!cs.isBefore(ce)) continue;

        final sf = cs.difference(startTime).inMinutes / totalMinutes;
        final ef = ce.difference(startTime).inMinutes / totalMinutes;

        final arcStart = startAngle + sf * sweepAngle;
        final arcSweep = (ef - sf) * sweepAngle;

        // Llamamos al nuevo efecto de bloque rayado
        _drawPredictedBlock(
          canvas,
          rect,
          arcStart,
          arcSweep,
          ClockPalette.nightAccent,
        );

        final startLabel =
            '${cs.hour.toString().padLeft(2, '0')}:${cs.minute.toString().padLeft(2, '0')}';
        final endLabel =
            '${ce.hour.toString().padLeft(2, '0')}:${ce.minute.toString().padLeft(2, '0')}';

        _drawArcLabel(canvas, size, startLabel, arcStart);
        _drawArcLabel(canvas, size, endLabel, arcStart + arcSweep);
      }
    }
  }

  void _drawPredictedBlock(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Color color,
  ) {
    // 1. Fondo sólido suave (el bloque completo)
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW * 1.25
        ..strokeCap = StrokeCap.round,
    );

    // 2. Patrón de rayas (stripes) superpuesto
    final stripePaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeW * 1.25
      ..strokeCap =
          StrokeCap.butt; // Corta en recto para parecer barras y no círculos

    const double stripeSweep = 0.02; // Grosor de la raya (en radianes)
    const double gapSweep = 0.035; // Espacio entre rayas
    const double step = stripeSweep + gapSweep;

    // Margen interior para que las rayas no sobresalgan por las puntas redondeadas
    double currentAngle = start + 0.05;
    final double endAngle = start + sweep - 0.05;

    // Dibujamos las rayas iterando por el arco
    while (currentAngle < endAngle) {
      final drawSweep = (currentAngle + stripeSweep > endAngle)
          ? (endAngle - currentAngle)
          : stripeSweep;

      canvas.drawArc(rect, currentAngle, drawSweep, false, stripePaint);
      currentAngle += step;
    }
  }

  void _drawArcLabel(Canvas canvas, Size size, String text, double angle) {
    const double labelR = 0.82;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final x = center.dx + radius * labelR * math.cos(angle);
    final y = center.dy + radius * labelR * math.sin(angle);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y),
        width: tp.width + 8,
        height: tp.height + 5,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = ClockPalette.nightAccent.withOpacity(0.75),
    );

    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant ClockPainter old) =>
      old.isDayMode != isDayMode ||
      old.startTime != startTime ||
      old.endTime != endTime ||
      old.events != events ||
      old.napPredictions != napPredictions;
}
