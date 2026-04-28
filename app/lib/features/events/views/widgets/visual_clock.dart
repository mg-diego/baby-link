import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/models/event_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETA — alineada con el dark theme de la app
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color accent      = Color(0xFFFF7643); // naranja de la app
  static const Color surface     = Color(0xFF1E1E1E); // surface del dark theme
  static const Color trackBg     = Color(0xFF2C2C2C); // track inactivo
  static const Color textPrimary = Colors.white;
  static const Color textMuted   = Color(0xFF9E9E9E);
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class VisualClockView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> ydayEvents;
  final DateTime selectedDate;

  const VisualClockView({
    super.key,
    required this.events,
    required this.ydayEvents,
    required this.selectedDate,
  });

  @override
  State<VisualClockView> createState() => _VisualClockViewState();
}

class _VisualClockViewState extends State<VisualClockView>
    with SingleTickerProviderStateMixin {
  bool _isDayMode = true;

  late AnimationController _toggleCtrl;

  @override
  void initState() {
    super.initState();
    _toggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _checkInitialMode();
  }

  @override
  void dispose() {
    _toggleCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VisualClockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) _checkInitialMode();
  }

  void _checkInitialMode() {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isToday = widget.selectedDate == today;
    final newMode = isToday
        ? !widget.events.any((e) => e['category'] == 'bed_time')
        : true;
    setState(() => _isDayMode = newMode);
    newMode ? _toggleCtrl.reverse() : _toggleCtrl.forward();
  }

  void _setMode(bool day) {
    setState(() => _isDayMode = day);
    day ? _toggleCtrl.reverse() : _toggleCtrl.forward();
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Rango (lógica original intacta) ──────────────────────────────────────
  ({DateTime start, DateTime end}) _computeRange() {
    final todayAsc = List<Map<String, dynamic>>.from(widget.events)
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));
    final ydayDesc = List<Map<String, dynamic>>.from(widget.ydayEvents)
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    final d = widget.selectedDate;

    if (_isDayMode) {
      DateTime? wokeUp, bedTime;
      for (var e in todayAsc) {
        if (e['category'] == 'woke_up' && wokeUp == null)
          wokeUp = DateTime.parse(e['start_time']).toLocal();
        if (e['category'] == 'bed_time' && bedTime == null)
          bedTime = DateTime.parse(e['start_time']).toLocal();
      }
      final start = wokeUp ?? DateTime(d.year, d.month, d.day, 7, 0);
      var end = bedTime ?? DateTime(d.year, d.month, d.day, 20, 30);
      if (end.isBefore(start)) end = DateTime(d.year, d.month, d.day, 20, 30);
      return (start: start, end: end);
    } else {
      DateTime? prevBed, woke;
      for (var e in ydayDesc) {
        if (e['category'] == 'bed_time') {
          prevBed = DateTime.parse(e['start_time']).toLocal();
          break;
        }
      }
      for (var e in todayAsc) {
        if (e['category'] == 'woke_up') {
          woke = DateTime.parse(e['start_time']).toLocal();
          break;
        }
      }
      final start = prevBed ??
          DateTime(d.year, d.month, d.day, 20, 30)
              .subtract(const Duration(days: 1));
      var end = woke ?? DateTime(d.year, d.month, d.day, 8, 0);
      if (end.isBefore(start))
        end = start.add(const Duration(hours: 11, minutes: 30));
      return (start: start, end: end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isToday = widget.selectedDate == today;

    final range         = _computeRange();
    final startTime     = range.start;
    final endTime       = range.end;
    final totalMins     = endTime.difference(startTime).inMinutes;
    final safeTotalMins = totalMins > 0 ? totalMins : 1;

    final allEvents = [...widget.ydayEvents, ...widget.events]
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));

    const double startAngle = 2 * math.pi / 3;
    const double sweepAngle = 5 * math.pi / 3;
    final double endAngle   = startAngle + sweepAngle;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size   = math.min(constraints.maxWidth - 60, 330.0);
          final radius = size / 2;

          final double labelR = radius + 28;
          final startX = radius + labelR * math.cos(startAngle);
          final startY = radius + labelR * math.sin(startAngle);
          final endX   = radius + labelR * math.cos(endAngle);
          final endY   = radius + labelR * math.sin(endAngle);

          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── ARCO ───────────────────────────────────────────────────
                CustomPaint(
                  size: Size(size, size),
                  painter: _ClockPainter(
                    events: allEvents,
                    startTime: startTime,
                    endTime: endTime,
                    totalMinutes: safeTotalMins,
                    startAngle: startAngle,
                    sweepAngle: sweepAngle,
                    isDayMode: _isDayMode,
                  ),
                ),

                // ── ETIQUETA INICIO ─────────────────────────────────────────
                Positioned(
                  left: startX - 26,
                  top:  startY - 10,
                  child: _TimeLabel(_formatTime(startTime)),
                ),

                // ── ETIQUETA FIN ────────────────────────────────────────────
                Positioned(
                  left: endX - 26,
                  top:  endY - 10,
                  child: _TimeLabel(_formatTime(endTime)),
                ),

                // ── CENTRO ──────────────────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Etiqueta de modo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDayMode
                                ? Icons.wb_sunny_outlined
                                : Icons.nights_stay_outlined,
                            size: 13,
                            color: _C.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isDayMode ? 'Día' : 'Noche',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.textMuted,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Rango horario
                      Text(
                        '${_formatTime(startTime)}–${_formatTime(endTime)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Toggle día / noche
                      if (!isToday || (isToday && _isDayMode))
                        _Toggle(
                          isDayMode: _isDayMode,
                          onToggle: _setMode,
                        ),
                    ],
                  ),
                ),

                // ── ICONOS DE EVENTOS ────────────────────────────────────────
                ...allEvents.map((event) {
                  final cat       = event['category'];
                  final meta      =
                      (event['metadata'] as Map<String, dynamic>?) ?? {};
                  final eventType = EventType.fromBackend(cat, meta);
                  final eventStart =
                      DateTime.parse(event['start_time']).toLocal();

                  if (eventStart.isBefore(startTime) ||
                      eventStart.isAfter(endTime)) {
                    return const SizedBox.shrink();
                  }
                  if (_isDayMode && cat == 'night_waking')
                    return const SizedBox.shrink();
                  if (!_isDayMode && cat == 'nap')
                    return const SizedBox.shrink();

                  final fraction = eventStart.difference(startTime).inMinutes /
                      safeTotalMins;
                  final angle = startAngle + (fraction * sweepAngle);

                  const double iconR = 17.0;
                  final x = radius + radius * math.cos(angle);
                  final y = radius + radius * math.sin(angle);

                  return Positioned(
                    left: x - iconR,
                    top:  y - iconR,
                    child: _EventIcon(eventType: eventType),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUBWIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Etiqueta de hora (inicio / fin del arco)
class _TimeLabel extends StatelessWidget {
  final String time;
  const _TimeLabel(this.time);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 52,
        child: Text(
          time,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: _C.textMuted,
          ),
        ),
      );
}

/// Icono circular de evento
class _EventIcon extends StatelessWidget {
  final EventType eventType;
  const _EventIcon({required this.eventType});

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _C.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: eventType.accentColor.withOpacity(0.75),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(eventType.icon, size: 16, color: eventType.accentColor),
      );
}

/// Toggle sol / luna
class _Toggle extends StatelessWidget {
  final bool isDayMode;
  final void Function(bool) onToggle;
  const _Toggle({required this.isDayMode, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        width: 96,
        decoration: BoxDecoration(
          color: _C.trackBg,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Stack(
          children: [
            // Thumb animado
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment:
                  isDayMode ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _C.accent.withOpacity(0.5),
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
                        color: isDayMode ? _C.accent : _C.textMuted,
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
                        color: !isDayMode ? _C.accent : _C.textMuted,
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

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _ClockPainter extends CustomPainter {
  final List<Map<String, dynamic>> events;
  final DateTime startTime;
  final DateTime endTime;
  final int      totalMinutes;
  final double   startAngle;
  final double   sweepAngle;
  final bool     isDayMode;

  _ClockPainter({
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.totalMinutes,
    required this.startAngle,
    required this.sweepAngle,
    required this.isDayMode,
  });

  static const double _strokeW = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // ── 1. TRACK INACTIVO ─────────────────────────────────────────────────────
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color       = _C.trackBg
        ..style       = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap   = StrokeCap.round,
    );

    // ── 2. ARCO PRINCIPAL — naranja fijo, sin degradado ───────────────────────
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color       = _C.accent
        ..style       = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap   = StrokeCap.round,
    );

    // ── 3. SEGMENTOS DE DURACIÓN (nap / night_waking) ─────────────────────────
    //   Se superponen al arco naranja con el color propio del evento.
    //   Opacidad moderada para que sean legibles sin tapar el arco base.
    for (var event in events) {
      final cat       = event['category'];
      final eventType = EventType.fromBackend(cat, event['metadata'] ?? {});

      final bool isRelevant =
          (isDayMode  && cat == 'nap'          && event['end_time'] != null) ||
          (!isDayMode && cat == 'night_waking' && event['end_time'] != null);
      if (!isRelevant) continue;

      final evStart = DateTime.parse(event['start_time']).toLocal();
      final evEnd   = DateTime.parse(event['end_time']).toLocal();

      if (!evStart.isBefore(endTime) || !evEnd.isAfter(startTime)) continue;

      final cs = evStart.isBefore(startTime) ? startTime : evStart;
      final ce = evEnd.isAfter(endTime)       ? endTime   : evEnd;

      final sf = cs.difference(startTime).inMinutes / totalMinutes;
      final ef = ce.difference(startTime).inMinutes / totalMinutes;

      canvas.drawArc(
        rect,
        startAngle + (sf * sweepAngle),
        (ef - sf) * sweepAngle,
        false,
        Paint()
          ..color       = eventType.accentColor.withOpacity(0.60)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = _strokeW
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.isDayMode != isDayMode ||
      old.startTime != startTime ||
      old.endTime   != endTime   ||
      old.events    != events;
}