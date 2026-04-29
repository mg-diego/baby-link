import 'dart:math' as math;
import 'package:app/core/models/event_type.dart';
import 'package:flutter/material.dart';
import 'package:app/features/events/providers/events_provider.dart';

import 'clock_palette.dart';
import 'clock_components.dart';
import 'clock_painter.dart';

class VisualClockView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> yesterdayEvents;
  final List<SleepPrediction>? sleepPrediction;
  final SleepPrediction? wakePrediction;
  final DateTime selectedDate;

  const VisualClockView({
    super.key,
    required this.events,
    required this.yesterdayEvents,
    required this.selectedDate,
    this.sleepPrediction,
    this.wakePrediction,
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

  SleepPrediction? _getBedtimePrediction() {
    final preds = widget.sleepPrediction;
    if (preds == null) return null;
    for (final p in preds) {
      if (p.isBedtime) return p;
    }
    return null;
  }

  List<SleepPrediction> _getNapPredictions() =>
      widget.sleepPrediction?.where((p) => p.isNap && p.end != null).toList() ??
      [];

  void _checkInitialMode() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
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

  ({DateTime start, DateTime end}) _computeRange() {
    final todayAsc = List<Map<String, dynamic>>.from(widget.events)
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));
    final ydayDesc = List<Map<String, dynamic>>.from(widget.yesterdayEvents)
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    final d = widget.selectedDate;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isToday = widget.selectedDate == today;

    if (_isDayMode) {
      DateTime? wokeUp, bedTime;
      for (var e in todayAsc) {
        if (e['category'] == 'woke_up' && wokeUp == null) {
          wokeUp = DateTime.parse(e['start_time']).toLocal();
        }
        if (e['category'] == 'bed_time' && bedTime == null) {
          bedTime = DateTime.parse(e['start_time']).toLocal();
        }
      }
      final predictedBedtime = _getBedtimePrediction()?.start;
      final fallback = predictedBedtime ?? DateTime(d.year, d.month, d.day, 20, 30);
      final start = wokeUp ?? DateTime(d.year, d.month, d.day, 7, 0);
      var end = bedTime ?? fallback;
      if (end.isBefore(start)) end = fallback;
      return (start: start, end: end);
    } else {
      DateTime? bedTime, woke;
      if (isToday) {
        for (var e in todayAsc) {
          if (e['category'] == 'bed_time') {
            bedTime = DateTime.parse(e['start_time']).toLocal();
            break;
          }
        }
        final start = bedTime ?? DateTime(d.year, d.month, d.day, 20, 0);
        final end = widget.wakePrediction?.start ?? start.add(const Duration(hours: 11));
        return (start: start, end: end);
      } else {
        for (var e in ydayDesc) {
          if (e['category'] == 'bed_time') {
            bedTime = DateTime.parse(e['start_time']).toLocal();
            break;
          }
        }
        for (var e in todayAsc) {
          if (e['category'] == 'woke_up') {
            woke = DateTime.parse(e['start_time']).toLocal();
            break;
          }
        }
        final start = bedTime ??
            DateTime(d.year, d.month, d.day, 20, 30).subtract(const Duration(days: 1));
        var end = woke ?? DateTime(d.year, d.month, d.day, 8, 0);
        if (end.isBefore(start)) {
          end = start.add(const Duration(hours: 11, minutes: 30));
        }
        return (start: start, end: end);
      }
    }
  }

  Widget _buildDynamicMessage() {
    final now = DateTime.now();
    String label = "";
    String timeString = "";

    if (_isDayMode) {
      final hasWokeUp = widget.events.any((e) => e['category'] == 'woke_up');
      if (hasWokeUp) {
        final preds = widget.sleepPrediction
                ?.where((p) => p.start.isAfter(now))
                .toList() ??
            [];
        if (preds.isNotEmpty) {
          preds.sort((a, b) => a.start.compareTo(b.start));
          final nextPred = preds.first;
          final diff = nextPred.start.difference(now);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          
          label = nextPred.isNap ? "Siguiente siesta en" : "Hora de irse a dormir en";
          timeString = h == 0 ? '$m min' : '${h}h ${m}min';
        }
      }
    } else {
      final allDesc = [...widget.yesterdayEvents, ...widget.events]
        ..sort((a, b) => b['start_time'].compareTo(a['start_time']));
      final activeWaking = allDesc
          .where((e) => e['category'] == 'night_waking' && e['end_time'] == null)
          .firstOrNull;

      if (activeWaking != null) {
        final start = DateTime.parse(activeWaking['start_time']).toLocal();
        final diff = now.difference(start);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        
        label = "Despierto durante";
        timeString = h == 0 ? '$m min' : '${h}h ${m}min';
      } else {
        final lastBed =
            allDesc.where((e) => e['category'] == 'bed_time').firstOrNull;
        if (lastBed != null) {
          final start = DateTime.parse(lastBed['start_time']).toLocal();
          final diff = now.difference(start);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          
          label = "Dormido durante";
          timeString = h == 0 ? '$m min' : '${h}h ${m}min';
        }
      }
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ClockPalette.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          timeString,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: ClockPalette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const EmptyClockState(isToday: true);
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isToday = widget.selectedDate == today;

    final range = _computeRange();
    final startTime = range.start;
    final endTime = range.end;
    final totalMins = endTime.difference(startTime).inMinutes;
    final safeTotalMins = totalMins > 0 ? totalMins : 1;

    final allEvents = [...widget.yesterdayEvents, ...widget.events]
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));

    const double startAngle = 2 * math.pi / 3;
    const double sweepAngle = 5 * math.pi / 3;
    final double endAngle = startAngle + sweepAngle;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth - 60, 330.0);
          final radius = size / 2;

          final double labelR = radius + 28;
          final startX = radius + labelR * math.cos(startAngle);
          final startY = radius + labelR * math.sin(startAngle);
          final endX = radius + labelR * math.cos(endAngle);
          final endY = radius + labelR * math.sin(endAngle);

          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(size, size),
                  painter: ClockPainter(
                    events: allEvents,
                    startTime: startTime,
                    endTime: endTime,
                    totalMinutes: safeTotalMins,
                    startAngle: startAngle,
                    sweepAngle: sweepAngle,
                    isDayMode: _isDayMode,
                    napPredictions: _getNapPredictions(),
                  ),
                ),

                Positioned(
                  left: startX - 26,
                  top: startY - 10,
                  child: TimeLabel(_formatTime(startTime)),
                ),
                Positioned(
                  left: endX - 26,
                  top: endY - 10,
                  child: TimeLabel(_formatTime(endTime)),
                ),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isToday) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isDayMode
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nights_stay_outlined,
                              size: 13,
                              color: ClockPalette.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isDayMode ? 'Día' : 'Noche',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ClockPalette.textMuted,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(startTime)}–${_formatTime(endTime)}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: ClockPalette.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClockToggle(isDayMode: _isDayMode, onToggle: _setMode),
                      ] else ...[
                        _buildDynamicMessage(),
                      ]
                    ],
                  ),
                ),

                ...allEvents.map((event) {
                  final cat = event['category'];
                  final meta = (event['metadata'] as Map<String, dynamic>?) ?? {};
                  final eventType = EventType.fromBackend(cat, meta);
                  final eventStart =
                      DateTime.parse(event['start_time']).toLocal();

                  if (eventStart.isBefore(startTime) ||
                      eventStart.isAfter(endTime)) {
                    return const SizedBox.shrink();
                  }
                  if (_isDayMode && cat == 'night_waking') {
                    return const SizedBox.shrink();
                  }
                  if (!_isDayMode && cat == 'nap') {
                    return const SizedBox.shrink();
                  }

                  final fraction =
                      eventStart.difference(startTime).inMinutes / safeTotalMins;
                  final angle = startAngle + (fraction * sweepAngle);

                  const double iconR = 17.0;
                  final x = radius + radius * math.cos(angle);
                  final y = radius + radius * math.sin(angle);

                  return Positioned(
                    left: x - iconR,
                    top: y - iconR,
                    child: EventIcon(eventType: eventType),
                  );
                }),

                if (_isDayMode)
                  ..._getNapPredictions().map((pred) {
                    final fraction =
                        pred.start.difference(startTime).inMinutes / safeTotalMins;
                    if (fraction < 0 || fraction > 1) {
                      return const SizedBox.shrink();
                    }
                    final angle = startAngle + fraction * sweepAngle;

                    const double iconR = 17.0;
                    final x = radius + radius * math.cos(angle);
                    final y = radius + radius * math.sin(angle);

                    return Positioned(
                      left: x - iconR,
                      top: y - iconR,
                      child: Opacity(
                        opacity: 0.4,
                        child: EventIcon(eventType: EventType.nap),
                      ),
                    );
                  }),

                if (_isDayMode && _getBedtimePrediction() != null)
                  Builder(
                    builder: (_) {
                      final pred = _getBedtimePrediction()!;
                      final fraction =
                          pred.start.difference(startTime).inMinutes /
                              safeTotalMins;

                      if (fraction < 0 || fraction > 1.05) {
                        return const SizedBox.shrink();
                      }

                      final displayFraction = fraction.clamp(0.0, 1.0);
                      final angle =
                          startAngle + displayFraction * sweepAngle;

                      const double iconR = 17.0;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: const Opacity(
                          opacity: 0.4,
                          child: EventIcon(eventType: EventType.bedtime),
                        ),
                      );
                    },
                  ),

                if (!_isDayMode && widget.wakePrediction != null)
                  Builder(
                    builder: (_) {
                      final pred = widget.wakePrediction!;
                      final fraction =
                          pred.start.difference(startTime).inMinutes /
                              safeTotalMins;

                      if (fraction < 0 || fraction > 1.05) {
                        return const SizedBox.shrink();
                      }

                      final displayFraction = fraction.clamp(0.0, 1.0);
                      final angle =
                          startAngle + displayFraction * sweepAngle;

                      const double iconR = 17.0;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: const Opacity(
                          opacity: 0.4,
                          child: EventIcon(eventType: EventType.wokeUp),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}