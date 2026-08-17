import 'dart:math' as math;

import 'package:app/shared/models/event_type.dart';
import 'package:flutter/material.dart';
import 'clock_palette.dart';

/// Etiqueta de hora (inicio / fin del arco)
class TimeLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double scale;

  const TimeLabel(this.text, {super.key, this.color, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13 * scale,
        fontWeight: FontWeight.w600,
        color: color ?? ClockPalette.textPrimary,
        height: 1.0,
      ),
    );
  }
}

class EventIcon extends StatelessWidget {
  final EventType eventType;
  final bool isPrediction;
  final double scale;

  const EventIcon({
    super.key, 
    required this.eventType,
    this.isPrediction = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = eventType.getAccentColor(context).withOpacity(0.75);

    Widget innerContainer = Container(
      width: 34 * scale,
      height: 34 * scale,
      decoration: BoxDecoration(
        color: ClockPalette.surface,
        shape: BoxShape.circle,
        border: isPrediction ? null : Border.all(
          color: borderColor,
          width: 1.5 * scale,
        ),
        boxShadow: isPrediction ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            eventType.icon, 
            size: 16 * scale, 
            color: eventType.getAccentColor(context),
          ),
          if (isPrediction)
            Positioned(
              top: -4 * scale,
              right: -4 * scale,
              child: Container(
                padding: EdgeInsets.all(2 * scale),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ClockPalette.surface,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 10 * scale,
                  color: Colors.amber.shade500,
                ),
              ),
            ),
        ],
      ),
    );

    if (isPrediction) {
      return CustomPaint(
        painter: _DashedCirclePainter(color: borderColor, strokeWidth: 1.5 * scale),
        child: innerContainer,
      );
    }

    return innerContainer;
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();
    final sweepAngle = (dashWidth / circumference) * 2 * math.pi;
    final spaceAngle = (dashSpace / circumference) * 2 * math.pi;

    double startAngle = 0.0;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle + spaceAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Toggle sol / luna
class ClockToggle extends StatelessWidget {
  final bool isDayMode;
  final void Function(bool) onToggle;
  const ClockToggle({super.key, required this.isDayMode, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    width: 96,
    decoration: BoxDecoration(
      color: ClockPalette.trackBg,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Stack(
      children: [
        // Thumb animado
        AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: isDayMode ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: 48,
            height: 34,
            decoration: BoxDecoration(
              color: ClockPalette.surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: isDayMode
                    ? ClockPalette.dayAccent.withOpacity(0.5)
                    : ClockPalette.nightAccent.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
        ),
        // Iconos
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(true),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Icon(
                    Icons.wb_sunny_outlined,
                    size: 16,
                    color: isDayMode ? ClockPalette.dayAccent : ClockPalette.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(false),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Icon(
                    Icons.nights_stay_outlined,
                    size: 16,
                    color: !isDayMode ? ClockPalette.nightAccent : ClockPalette.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class EmptyClockState extends StatelessWidget {
  final bool isToday;
  const EmptyClockState({super.key, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            isToday ? 'Aún no hay eventos hoy.' : 'Sin eventos este día.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}