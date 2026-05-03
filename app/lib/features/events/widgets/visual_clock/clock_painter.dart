import 'dart:math' as math;
import 'package:app/shared/models/event_type.dart';
import 'package:flutter/material.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'clock_palette.dart';

class ClockPainter extends CustomPainter {
  final BuildContext context;
  final List<Map<String, dynamic>> events;
  final DateTime startTime;
  final DateTime endTime;
  final int totalMinutes;
  final double startAngle;
  final double sweepAngle;
  final bool isDayMode;
  final List<SleepPrediction> napPredictions;
  final double? currentProgress;

  ClockPainter({
    required this.context,
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.totalMinutes,
    required this.startAngle,
    required this.sweepAngle,
    required this.isDayMode,
    required this.napPredictions,
    required this.currentProgress,
  });

  static const double _strokeW = 25.0;

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

    final bool isBiological = currentProgress != null;

    final Color trackColor = isBiological
        ? (isDayMode ? const Color(0xFFE8EAF6) : const Color(0xFF242746))
        : ClockPalette.trackBg;

    // 1. TRACK INACTIVO
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap = StrokeCap.round,
    );

    final double activeSweep = isBiological 
        ? sweepAngle * currentProgress!.clamp(0.0, 1.0) 
        : sweepAngle;
        
    final Color activeColor = isBiological
        ? (isDayMode ? const Color(0xFFFFA726) : const Color(0xFF5C6BC0))
        : (isDayMode ? ClockPalette.dayAccent : ClockPalette.nightAccent);

    // 2. ARCO PRINCIPAL (ACTIVO)
    canvas.drawArc(
      rect,
      startAngle,
      activeSweep,
      false,
      Paint()
        ..color = activeColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap = StrokeCap.round,
    );

    // --- NUEVO: INDICADOR DE MEDIANOCHE ---
    // Calculamos si hay una transición de día entre startTime y endTime
    final DateTime nextMidnight = DateTime(startTime.year, startTime.month, startTime.day + 1);
    
    if (nextMidnight.isAfter(startTime) && nextMidnight.isBefore(endTime)) {
      final sf = nextMidnight.difference(startTime).inMinutes / totalMinutes;
      final midnightAngle = startAngle + (sf * sweepAngle);

      // Dibujamos una línea sutil cruzando el ancho del track
      final innerR = radius - _strokeW / 2 + 2;
      final outerR = radius + _strokeW / 2 - 2;

      final p1 = Offset(center.dx + innerR * math.cos(midnightAngle), center.dy + innerR * math.sin(midnightAngle));
      final p2 = Offset(center.dx + outerR * math.cos(midnightAngle), center.dy + outerR * math.sin(midnightAngle));

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isDayMode ? Colors.black26 : Colors.white30
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      final textR = radius + _strokeW / 2 + 12;
      final tx = center.dx + textR * math.cos(midnightAngle);
      final ty = center.dy + textR * math.sin(midnightAngle);

      final tp = TextPainter(
        text: TextSpan(
          text: 'Medianoche',
          style: TextStyle(
            color: isDayMode ? Colors.black38 : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(tx - tp.width / 2, ty - tp.height / 2));
    }
    // --- FIN INDICADOR DE MEDIANOCHE ---

    // 3. SEGMENTOS DE DURACIÓN (Desvelos / Siestas reales)
    // 3. SEGMENTOS DE DURACIÓN
    for (var event in events) {
      final cat = event['category'];
      final eventType = EventType.fromBackend(cat, event['metadata'] ?? {});

      // SOLO dibujamos el arco si es siesta de día o desvelo de noche
      final bool isRelevant = (isDayMode && cat == 'nap') || 
                              (!isDayMode && cat == 'night_waking');
      
      if (!isRelevant) continue;

      final evStart = DateTime.parse(event['start_time']).toLocal();
      
      // Si el evento está en curso (end_time nulo), el recorrido llega hasta ahora
      final evEnd = event['end_time'] != null
          ? DateTime.parse(event['end_time']).toLocal()
          : DateTime.now();

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
          ..color = eventType.getAccentColor(context, forceNightMode: !isDayMode).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeW * 1.25
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4. SIESTAS PREDICHAS (Solo día)
    if (isDayMode) {
      for (final pred in napPredictions) {
        final cs = pred.start.isBefore(startTime) ? startTime : pred.start;
        final ce = pred.end!.isAfter(endTime) ? endTime : pred.end!;
        if (!cs.isBefore(ce)) continue;

        final sf = cs.difference(startTime).inMinutes / totalMinutes;
        final ef = ce.difference(startTime).inMinutes / totalMinutes;

        final arcStart = startAngle + sf * sweepAngle;
        final arcSweep = (ef - sf) * sweepAngle;

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
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW * 1.25
        ..strokeCap = StrokeCap.round,
    );

    final stripePaint = Paint()
      ..color = color.withOpacity(0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeW * 1.25
      ..strokeCap = StrokeCap.butt; 

    const double stripeSweep = 0.02; 
    const double gapSweep = 0.035; 
    const double step = stripeSweep + gapSweep;

    double currentAngle = start + 0.05;
    final double endAngle = start + sweep - 0.05;

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
      old.napPredictions != napPredictions ||
      old.currentProgress != currentProgress;
}