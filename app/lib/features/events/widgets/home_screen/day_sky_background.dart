import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Color keyframes by hour ─────────────────────────────────────────────────

class _SkyFrame {
  final double hour;
  final Color top;
  final Color bottom;
  const _SkyFrame(this.hour, this.top, this.bottom);
}

const _kFrames = [
  _SkyFrame(0.0,  Color(0xFF090720), Color(0xFF12102E)),
  _SkyFrame(5.0,  Color(0xFF1A1240), Color(0xFF6B3058)),
  _SkyFrame(6.0,  Color(0xFF3A1D60), Color(0xFFE8703A)),
  _SkyFrame(7.0,  Color(0xFF5A8ED4), Color(0xFFFFD09A)),
  _SkyFrame(9.0,  Color(0xFF3498E8), Color(0xFFCCE8FF)),
  _SkyFrame(12.0, Color(0xFF1A7ED4), Color(0xFFB8DCFF)),
  _SkyFrame(15.0, Color(0xFF2282D8), Color(0xFFCCE8FF)),
  _SkyFrame(17.5, Color(0xFF2E50A0), Color(0xFFFFCA58)),
  _SkyFrame(18.5, Color(0xFF22185A), Color(0xFFFF6030)),
  _SkyFrame(19.5, Color(0xFF160E38), Color(0xFFCC2858)),
  _SkyFrame(21.0, Color(0xFF0C0A22), Color(0xFF180E2C)),
  _SkyFrame(24.0, Color(0xFF090720), Color(0xFF12102E)),
];

List<Color> _interpolateSky(double hour) {
  int i = 0;
  while (i < _kFrames.length - 2 && _kFrames[i + 1].hour <= hour) i++;
  final a = _kFrames[i];
  final b = _kFrames[i + 1];
  final t = ((hour - a.hour) / (b.hour - a.hour)).clamp(0.0, 1.0);
  return [Color.lerp(a.top, b.top, t)!, Color.lerp(a.bottom, b.bottom, t)!];
}

// ── Cloud model ─────────────────────────────────────────────────────────────

class _Cloud {
  final double x, y, scale, speed, opacity;
  const _Cloud({
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
  });
}

// ── Widget ───────────────────────────────────────────────────────────────────

class DaySkyBackground extends StatefulWidget {
  const DaySkyBackground({super.key});

  @override
  State<DaySkyBackground> createState() => _DaySkyBackgroundState();
}

class _DaySkyBackgroundState extends State<DaySkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _driftController;
  late Timer _clockTimer;
  final List<_Cloud> _clouds = [];
  double _hour = 12.0;

  @override
  void initState() {
    super.initState();

    _hour = _currentHour();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _hour = _currentHour());
    });

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    final rng = math.Random(42); // fixed seed → consistent cloud positions
    for (int i = 0; i < 7; i++) {
      _clouds.add(_Cloud(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.35 + 0.05,
        scale: rng.nextDouble() * 1.2 + 0.65,
        speed: rng.nextDouble() * 0.30 + 0.10,
        opacity: rng.nextDouble() * 0.20 + 0.55,
      ));
    }
  }

  double _currentHour() {
    final n = DateTime.now();
    return n.hour + n.minute / 60.0;
  }

  @override
  void dispose() {
    _driftController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  // Sun traces an arc: 6 am = left horizon, noon = top center, 7 pm = right horizon
  (double x, double y) _sunPosition() {
    final t = ((_hour - 6.0) / 13.0).clamp(0.0, 1.0);
    final x = 0.05 + t * 0.90;
    final y = 0.80 - math.sin(t * math.pi) * 0.65;
    return (x, y);
  }

  bool get _sunVisible => _hour >= 5.5 && _hour <= 20.5;

  bool get _isTransition =>
      (_hour >= 5.5 && _hour < 8.5) || (_hour > 16.5 && _hour <= 20.5);

  @override
  Widget build(BuildContext context) {
    final colors = _interpolateSky(_hour);
    final (sx, sy) = _sunPosition();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: AnimatedBuilder(
        animation: _driftController,
        builder: (_, __) => CustomPaint(
          painter: _DaySkyPainter(
            clouds: _clouds,
            drift: _driftController.value,
            sunX: sx,
            sunY: sy,
            sunVisible: _sunVisible,
            isTransition: _isTransition,
            isDawn: _hour < 12,
          ),
        ),
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _DaySkyPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final double drift;
  final double sunX, sunY;
  final bool sunVisible, isTransition, isDawn;

  const _DaySkyPainter({
    required this.clouds,
    required this.drift,
    required this.sunX,
    required this.sunY,
    required this.sunVisible,
    required this.isTransition,
    required this.isDawn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sunVisible) {
      if (isTransition) _drawHorizonGlow(canvas, size);
      _drawSun(canvas, size);
    }
    for (final c in clouds) {
      double cx = (c.x + drift * c.speed) % 1.0;
      final dx = cx * size.width;
      final dy = c.y * size.height;
      _drawCloud(canvas, size, dx, dy, c.scale, c.opacity);
    }
  }

  void _drawHorizonGlow(Canvas canvas, Size size) {
    // Warm radial glow near the horizon on the side where the sun sits
    final glowColor = isDawn ? const Color(0xFFFF9040) : const Color(0xFFFF5020);
    final alignX = sunX * 2 - 1; // -1..1
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(alignX, 1.4),
        radius: 1.1,
        colors: [glowColor.withOpacity(0.45), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawSun(Canvas canvas, Size size) {
    final cx = sunX * size.width;
    final cy = sunY * size.height;
    final nearHorizon = sunY > 0.52;

    final sunColor = nearHorizon ? const Color(0xFFFF8C38) : const Color(0xFFFFF59D);
    final glowColor = nearHorizon ? const Color(0xFFFF5520) : const Color(0xFFFFFDE7);
    final radius = nearHorizon ? 22.0 : 17.0;
    final center = Offset(cx, cy);

    // Outer soft glow
    canvas.drawCircle(
      center,
      radius * 4.5,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withOpacity(nearHorizon ? 0.22 : 0.10), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 4.5)),
    );

    // Mid glow
    canvas.drawCircle(
      center,
      radius * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withOpacity(nearHorizon ? 0.40 : 0.20), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.2)),
    );

    // Sun disc
    canvas.drawCircle(center, radius, Paint()..color = sunColor);

    // Bright core
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.85), sunColor.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawCloud(
    Canvas canvas,
    Size size,
    double x,
    double y,
    double scale,
    double opacity,
  ) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);

    // Draw the same cloud at x and x±width for seamless looping
    for (final offsetX in [x, x - size.width, x + size.width]) {
      _paintCloudAt(canvas, offsetX, y, scale, paint);
    }
  }

  void _paintCloudAt(Canvas canvas, double x, double y, double s, Paint p) {
    // Natural cloud shape: overlapping circles + base fill
    const circles = [
      (0.0, 0.0, 16.0),
      (-18.0, 7.0, 13.0),
      (18.0, 5.0, 14.0),
      (-9.0, -9.0, 13.0),
      (10.0, -11.0, 15.0),
      (28.0, 3.0, 11.0),
      (-28.0, 5.0, 10.0),
    ];
    for (final (dx, dy, r) in circles) {
      canvas.drawCircle(Offset(x + dx * s, y + dy * s), r * s, p);
    }
    // Fill the base so circles don't appear disconnected
    canvas.drawRect(
      Rect.fromLTRB(x - 32 * s, y, x + 32 * s, y + 13 * s),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _DaySkyPainter old) =>
      old.drift != drift || old.sunX != sunX || old.sunY != sunY;
}