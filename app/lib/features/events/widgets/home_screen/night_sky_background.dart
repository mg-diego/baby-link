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
  late AnimationController _shootingStarController;
  final List<_Star> _stars = [];
  _ShootingStar? _shootingStar;
  final math.Random _rng = math.Random(7);

  @override
  void initState() {
    super.initState();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180),
    )..repeat();

    _shootingStarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Pausa aleatoria entre 8 y 22 segundos antes del siguiente
          Future.delayed(
            Duration(seconds: 8 + _rng.nextInt(14)),
            () {
              if (mounted) {
                _shootingStar = _ShootingStar.random(_rng);
                _shootingStarController.forward(from: 0);
              }
            },
          );
        }
      });

    // Primera estrella fugaz tras 5 s
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _shootingStar = _ShootingStar.random(_rng);
        _shootingStarController.forward(from: 0);
      }
    });

    // Estrellas: más densas y concentradas en la mitad superior
    for (int i = 0; i < 160; i++) {
      final colorRoll = _rng.nextInt(12);
      final Color color;
      if (colorRoll == 0) {
        color = const Color(0xFFBBDEFB); // azul frío
      } else if (colorRoll == 1) {
        color = const Color(0xFFFFF9C4); // amarillo cálido
      } else if (colorRoll == 2) {
        color = const Color(0xFFFFCDD2); // rosado
      } else {
        color = Colors.white;
      }

      // y sesgado hacia arriba (raíz cuadrada invierte la distribución)
      final rawY = _rng.nextDouble();
      final y = rawY * rawY * 0.85; // casi todas en el 85% superior

      _stars.add(_Star(
        x: _rng.nextDouble(),
        y: y,
        size: _rng.nextDouble() * 1.6 + 0.25,
        phaseOffset: _rng.nextDouble(), // twinkle desfasado por estrella
        twinkleSpeed: _rng.nextDouble() * 0.6 + 0.3,
        depth: _rng.nextDouble() * 0.4 + 0.05,
        color: color,
      ));
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _driftController.dispose();
    _shootingStarController.dispose();
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
          colors: [
            Color(0xFF03040C), // negro casi puro arriba
            Color(0xFF0A0D1E), // azul muy oscuro
            Color(0xFF0F1222), // azul noche en el fondo
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _twinkleController,
          _driftController,
          _shootingStarController,
        ]),
        builder: (context, _) => CustomPaint(
          painter: _NightSkyPainter(
            stars: _stars,
            twinkle: _twinkleController.value,
            drift: _driftController.value,
            shootingStar: _shootingStar,
            shootingT: _shootingStarController.value,
          ),
        ),
      ),
    );
  }
}

// ─── Models ────────────────────────────────────────────────────────────────────

class _Star {
  final double x, y, size, phaseOffset, twinkleSpeed, depth;
  final Color color;
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phaseOffset,
    required this.twinkleSpeed,
    required this.depth,
    required this.color,
  });
}

class _ShootingStar {
  final double startX, startY, angle, length;

  const _ShootingStar({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.length,
  });

  factory _ShootingStar.random(math.Random rng) {
    return _ShootingStar(
      startX: rng.nextDouble() * 0.7 + 0.1,
      startY: rng.nextDouble() * 0.35,
      angle: math.pi / 5 + rng.nextDouble() * math.pi / 8, // diagonal suave
      length: 0.18 + rng.nextDouble() * 0.12,
    );
  }
}

// ─── Painter ───────────────────────────────────────────────────────────────────

class _NightSkyPainter extends CustomPainter {
  final List<_Star> stars;
  final double twinkle;
  final double drift;
  final _ShootingStar? shootingStar;
  final double shootingT;

  const _NightSkyPainter({
    required this.stars,
    required this.twinkle,
    required this.drift,
    required this.shootingStar,
    required this.shootingT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawNebula(canvas, size);
    _drawMoon(canvas, size);
    _drawStars(canvas, size);
    if (shootingStar != null && shootingT > 0) {
      _drawShootingStar(canvas, size);
    }
  }

  // ── Nebulosa sutil — mancha de luz difusa en el cielo ─────────────────────
  void _drawNebula(Canvas canvas, Size size) {
    final spots = [
      (0.25, 0.20, 0.40, const Color(0xFF1A2060), 0.55),
      (0.70, 0.15, 0.35, const Color(0xFF201540), 0.45),
      (0.50, 0.35, 0.28, const Color(0xFF0D1830), 0.40),
    ];
    for (final (cx, cy, r, color, opacity) in spots) {
      canvas.drawCircle(
        Offset(cx * size.width, cy * size.height),
        r * size.width,
        Paint()
          ..color = color.withOpacity(opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.18),
      );
    }
  }

  // ── Luna emergiendo desde abajo como el sol ───────────────────────────────
  void _drawMoon(Canvas canvas, Size size) {
    // Centro fijo, ligeramente a la derecha
    final cx = size.width * 0.72;
    final radius = size.width * 0.32;
    // Centro siempre debajo del borde — solo asoma la corona
    final cy = size.height + radius * 0.55;
    final center = Offset(cx, cy);

    // Glow exterior muy suave
    canvas.drawCircle(
      center,
      radius * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB8C8E8).withOpacity(0.07),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5)),
    );

    // Disco lunar
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [
            const Color(0xFFDDE8F8).withOpacity(0.22),
            const Color(0xFF9BACC8).withOpacity(0.14),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Borde limbo — brillo suave en el arco superior
    final limbY = cy - radius;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, limbY + radius * 0.06),
        width: radius * 1.6,
        height: radius * 0.18,
      ),
      Paint()
        ..color = const Color(0xFFCCDDFF).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  // ── Estrellas ─────────────────────────────────────────────────────────────
  void _drawStars(Canvas canvas, Size size) {
    for (final star in stars) {
      // Twinkle con phase offset individual → no parpadean sincronizadas
      final phase = (twinkle + star.phaseOffset) % 1.0;
      final bri = (math.sin(phase * math.pi * 2 * star.twinkleSpeed) + 1) / 2;
      final opacity = (bri * 0.65 + 0.35).clamp(0.0, 1.0);

      final cx = ((star.x - drift * star.depth) % 1.0) * size.width;
      final cy = star.y * size.height;
      final center = Offset(cx, cy);

      // Glow para estrellas más grandes
      if (star.size > 1.1) {
        canvas.drawCircle(
          center,
          star.size * 3.0,
          Paint()
            ..color = star.color.withOpacity(opacity * 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
        );
      }

      // Core
      canvas.drawCircle(
        center,
        star.size,
        Paint()..color = star.color.withOpacity(opacity * 0.88),
      );

      // Brillo puntual en estrellas grandes
      if (star.size > 1.3) {
        canvas.drawCircle(
          center,
          star.size * 0.38,
          Paint()..color = Colors.white.withOpacity(opacity * 0.70),
        );
      }
    }
  }

  // ── Estrella fugaz ────────────────────────────────────────────────────────
  void _drawShootingStar(Canvas canvas, Size size) {
    final s = shootingStar!;

    // Curva ease: aparece rápido, desvanece al final
    final progress = Curves.easeIn.transform(shootingT);
    // Head avanza, tail sigue con retraso
    final headT = math.min(1.0, progress * 1.4);
    final tailT = math.max(0.0, progress - 0.25);

    final startX = s.startX * size.width;
    final startY = s.startY * size.height;
    final dx = math.cos(s.angle) * s.length * size.width;
    final dy = math.sin(s.angle) * s.length * size.height;

    final headX = startX + dx * headT;
    final headY = startY + dy * headT;
    final tailX = startX + dx * tailT;
    final tailY = startY + dy * tailT;

    // Opacidad: sube al principio, cae al final
    final opacity = (math.sin(progress * math.pi)).clamp(0.0, 1.0);

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(opacity * 0.85),
        ],
      ).createShader(Rect.fromPoints(
        Offset(tailX, tailY),
        Offset(headX, headY),
      ))
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), paint);

    // Punto brillante en la cabeza
    canvas.drawCircle(
      Offset(headX, headY),
      2.0,
      Paint()..color = Colors.white.withOpacity(opacity * 0.90),
    );
  }

  @override
  bool shouldRepaint(covariant _NightSkyPainter old) =>
      old.twinkle != twinkle ||
      old.drift != drift ||
      old.shootingT != shootingT;
}