import 'dart:math' as math;
import 'package:flutter/material.dart';

class NightSkyBackground extends StatefulWidget {
  const NightSkyBackground({super.key});

  @override
  State<NightSkyBackground> createState() => _NightSkyBackgroundState();
}

class _NightSkyBackgroundState extends State<NightSkyBackground>
    with TickerProviderStateMixin {
  late AnimationController _twinkleController;
  late AnimationController _driftController;
  final List<_Star> _stars = [];

  @override
  void initState() {
    super.initState();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 150),
    )..repeat();

    final random = math.Random();
    for (int i = 0; i < 120; i++) {
      final colorType = random.nextInt(10);
      Color starColor = Colors.white;
      if (colorType == 0) starColor = const Color(0xFFBBDEFB);
      if (colorType == 1) starColor = const Color(0xFFFFF9C4);

      _stars.add(
        _Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 1.5 + 0.3,
          twinkleSpeed: random.nextDouble() * 0.8 + 0.2,
          depth: random.nextDouble() * 0.6 + 0.1,
          color: starColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
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
          colors: [Color(0xFF04060F), Color(0xFF0F1222)],
        ),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_twinkleController, _driftController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _SkyPainter(
              stars: _stars,
              twinkleValue: _twinkleController.value,
              driftValue: _driftController.value,
            ),
          );
        },
      ),
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double twinkleSpeed;
  final double depth;
  final Color color;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.depth,
    required this.color,
  });
}

class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final double twinkleValue;
  final double driftValue;

  _SkyPainter({
    required this.stars,
    required this.twinkleValue,
    required this.driftValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final opacity =
          (math.sin(twinkleValue * math.pi * 2 * star.twinkleSpeed) + 1) / 2;
      final currentOpacity = (opacity * 0.7 + 0.3).clamp(0.0, 1.0);

      double currentX = star.x - (driftValue * star.depth);
      currentX -= currentX.floorToDouble();

      final dx = currentX * size.width;
      final dy = star.y * size.height;

      if (star.size > 1.2) {
        final glowPaint = Paint()
          ..color = star.color.withOpacity(currentOpacity * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(Offset(dx, dy), star.size * 2.5, glowPaint);
      }

      final corePaint = Paint()
        ..color = star.color.withOpacity(currentOpacity * 0.5);
      canvas.drawCircle(Offset(dx, dy), star.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return oldDelegate.twinkleValue != twinkleValue ||
        oldDelegate.driftValue != driftValue;
  }
}