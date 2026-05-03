import 'dart:math' as math;
import 'package:flutter/material.dart';

class DaySkyBackground extends StatefulWidget {
  const DaySkyBackground({super.key});

  @override
  State<DaySkyBackground> createState() => _DaySkyBackgroundState();
}

class _DaySkyBackgroundState extends State<DaySkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftController;
  final List<_Cloud> _clouds = [];

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();

    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _clouds.add(
        _Cloud(
          x: random.nextDouble(),
          y: random.nextDouble() * 0.45 + 0.05,
          scale: random.nextDouble() * 1.5 + 0.8,
          speed: random.nextDouble() * 0.6 + 0.3,
          opacity: random.nextDouble() * 0.3 + 0.4,
        ),
      );
    }
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF64B5F6), Color(0xFFE3F2FD)],
        ),
      ),
      child: AnimatedBuilder(
        animation: _driftController,
        builder: (context, child) {
          return CustomPaint(
            painter: _DaySkyPainter(
              clouds: _clouds,
              driftValue: _driftController.value,
            ),
          );
        },
      ),
    );
  }
}

class _Cloud {
  final double x;
  final double y;
  final double scale;
  final double speed;
  final double opacity;

  _Cloud({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
  });
}

class _DaySkyPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final double driftValue;

  _DaySkyPainter({required this.clouds, required this.driftValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in clouds) {
      double currentX = cloud.x + (driftValue * cloud.speed);
      currentX -= currentX.floorToDouble();

      final dx = currentX * size.width;
      final dy = cloud.y * size.height;

      _drawCloud(canvas, dx, dy, cloud.scale, cloud.opacity);
      _drawCloud(canvas, dx - size.width, dy, cloud.scale, cloud.opacity);
      _drawCloud(canvas, dx + size.width, dy, cloud.scale, cloud.opacity);
    }
  }

  void _drawCloud(
    Canvas canvas,
    double x,
    double y,
    double scale,
    double opacity,
  ) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: 70 * scale,
      height: 24 * scale,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(12 * scale));
    canvas.drawRRect(rrect, paint);

    canvas.drawCircle(
      Offset(x - 12 * scale, y - 10 * scale),
      18 * scale,
      paint,
    );
    canvas.drawCircle(
      Offset(x + 14 * scale, y - 14 * scale),
      22 * scale,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DaySkyPainter oldDelegate) {
    return oldDelegate.driftValue != driftValue;
  }
}