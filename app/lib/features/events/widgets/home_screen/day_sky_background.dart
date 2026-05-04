import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class _SkyFrame {
  final double hour;
  final Color top;
  final Color bottom;
  const _SkyFrame(this.hour, this.top, this.bottom);
}

const _kFrames = [
  _SkyFrame(0.0, Color(0xFF0B0A1E), Color(0xFF13112A)),
  _SkyFrame(5.0, Color(0xFF1C1640), Color(0xFF5A3050)),
  _SkyFrame(6.0, Color(0xFF3A2858), Color(0xFFB87858)),
  _SkyFrame(7.0, Color(0xFF5878A8), Color(0xFFDDC49A)),
  _SkyFrame(9.0, Color(0xFF4A80AA), Color(0xFFD0E4F0)),
  _SkyFrame(12.0, Color(0xFF3A70A0), Color(0xFFCCDFEE)),
  _SkyFrame(15.0, Color(0xFF3C78A8), Color(0xFFD0E4EE)),
  _SkyFrame(17.5, Color(0xFF3A4A80), Color(0xFFD4B87A)),
  _SkyFrame(18.5, Color(0xFF2A1E50), Color(0xFFB06848)),
  _SkyFrame(19.5, Color(0xFF1A1038), Color(0xFF803848)),
  _SkyFrame(21.0, Color(0xFF0E0C24), Color(0xFF1A1230)),
  _SkyFrame(24.0, Color(0xFF0B0A1E), Color(0xFF13112A)),
];

List<Color> _interpolateSky(double hour) {
  int i = 0;
  while (i < _kFrames.length - 2 && _kFrames[i + 1].hour <= hour) i++;
  final a = _kFrames[i];
  final b = _kFrames[i + 1];
  final t = ((hour - a.hour) / (b.hour - a.hour)).clamp(0.0, 1.0);
  return [Color.lerp(a.top, b.top, t)!, Color.lerp(a.bottom, b.bottom, t)!];
}

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

    final rng = math.Random(42);
    for (int i = 0; i < 7; i++) {
      _clouds.add(
        _Cloud(
          x: rng.nextDouble(),
          y: rng.nextDouble() * 0.35 + 0.05,
          scale: rng.nextDouble() * 1.2 + 0.65,
          speed: rng.nextDouble() * 0.30 + 0.10,
          opacity: rng.nextDouble() * 0.20 + 0.55,
        ),
      );
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

  // Intensidad del sol: 0.0 (noche) → 1.0 (mediodía)
  // Sube de 5:30 a 12:00, baja de 12:00 a 20:30
  double _sunIntensity() {
    if (_hour < 5.5 || _hour > 20.5) return 0.0;
    if (_hour <= 12.0) return ((_hour - 5.5) / 6.5).clamp(0.0, 1.0);
    return ((20.5 - _hour) / 8.5).clamp(0.0, 1.0);
  }

  bool get _isTransition =>
      (_hour >= 5.5 && _hour < 8.5) || (_hour > 16.5 && _hour <= 20.5);

  bool get _isDawn => _hour < 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = _interpolateSky(_hour);

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
            sunIntensity: _sunIntensity(),
            isTransition: _isTransition,
            isDawn: _isDawn,
          ),
        ),
      ),
    );
  }
}

class _DaySkyPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final double drift;
  final double sunIntensity; // 0.0 → 1.0
  final bool isTransition;
  final bool isDawn;

  const _DaySkyPainter({
    required this.clouds,
    required this.drift,
    required this.sunIntensity,
    required this.isTransition,
    required this.isDawn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sunIntensity > 0.0) {
      _drawSun(canvas, size);
    }
    for (final c in clouds) {
      final dx = ((c.x + drift * c.speed) % 1.0) * size.width;
      final dy = c.y * size.height;
      _drawCloud(canvas, size, dx, dy, c.scale, c.opacity);
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    // El sol siempre está centrado horizontalmente
    final cx = size.width * 0.50;

    // Radio: crece con la intensidad — de pequeño (amanecer) a grande (mediodía)
    // Está mayormente por debajo del borde inferior, solo asoma la parte superior
    final radius =
        size.width * (0.18 + sunIntensity * 0.08); // 38%–60% del ancho

    // Centro del círculo: empieza muy abajo y sube ligeramente con la intensidad
    // Con intensity=0 → centro en 1.15*height (invisible)
    // Con intensity=1 → centro en 0.92*height (asoma un buen trozo)
    final cy = size.height * (1.06 - sunIntensity * 0.08);

    final center = Offset(cx, cy);

    // Color del sol según transición o día pleno
    final Color coreColor;
    final Color glowColor;
    if (isTransition && isDawn) {
      coreColor = const Color(0xFFE8946A); // naranja suave amanecer
      glowColor = const Color(0xFFD06030);
    } else if (isTransition && !isDawn) {
      coreColor = const Color(0xFFD4885A); // coral suave atardecer
      glowColor = const Color(0xFFC05030);
    } else {
      coreColor = const Color(0xFFEED890); // amarillo crema mediodía
      glowColor = const Color(0xFFD4A830);
    }

    // ── Glow difuso exterior ──────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius * 1.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withOpacity(0.07 * sunIntensity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.4)),
    );

    // ── Disco principal ───────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          colors: [
            Color.lerp(
              Colors.white,
              coreColor,
              0.35,
            )!.withOpacity(0.45 * sunIntensity), // era 0.72
            coreColor.withOpacity(0.30 * sunIntensity), // era 0.55
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // ── Borde superior suave (limbo del sol) ──────────────────────────────
    // Línea de luz difusa justo donde el sol asoma por el horizonte
    if (sunIntensity > 0.20) {
      // era 0.05
      final limbY = cy - radius;
      canvas.drawOval(
        Rect.fromLTWH(
          cx - radius * 0.85,
          limbY - radius * 0.10,
          radius * 1.7,
          radius * 0.18,
        ),
        Paint()
          ..color = Colors.white
              .withOpacity(0.10 * sunIntensity) // era 0.18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
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
    for (final offsetX in [x, x - size.width, x + size.width]) {
      _paintCloudAt(canvas, offsetX, y, scale, paint);
    }
  }

  void _paintCloudAt(Canvas canvas, double x, double y, double s, Paint p) {
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
    canvas.drawRect(Rect.fromLTRB(x - 32 * s, y, x + 32 * s, y + 13 * s), p);
  }

  @override
  bool shouldRepaint(covariant _DaySkyPainter old) =>
      old.drift != drift || old.sunIntensity != sunIntensity;
}
