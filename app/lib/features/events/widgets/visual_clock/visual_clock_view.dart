import 'dart:math' as math;
import 'package:app/shared/models/event_type.dart';
import 'package:flutter/material.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:intl/intl.dart';

import 'clock_palette.dart';
import 'clock_components.dart';
import 'clock_painter.dart';

class VisualClockView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> yesterdayEvents;
  final List<SleepPrediction>? sleepPrediction;
  final SleepPrediction? wakePrediction;
  final DateTime selectedDate;
  final bool isLearning;

  final bool? forceNightMode;
  final DateTime? biologicalCycleEnd;
  final Function(Map<String, dynamic>)? onTapEvent;
  final VoidCallback? onTapPrediction;

  final AlignmentGeometry alignment;

  const VisualClockView({
    super.key,
    required this.events,
    required this.yesterdayEvents,
    required this.selectedDate,
    this.sleepPrediction,
    this.wakePrediction,
    this.isLearning = false,
    this.forceNightMode,
    this.biologicalCycleEnd,
    this.onTapEvent,
    this.onTapPrediction,
    this.alignment = Alignment.center,
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
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.forceNightMode != widget.forceNightMode) {
      _checkInitialMode();
    }
  }

  String _dayNightLabel() {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    if (_isDayMode) {
      final d = widget.selectedDate;
      return 'Día de ${d.day} ${months[d.month - 1]}';
    } else {
      final d = widget.selectedDate;
      return 'Noche a ${d.day} ${months[d.month - 1]}';
    }
  }

  SleepPrediction? _getBedtimePrediction() {
    final preds = widget.sleepPrediction;
    if (preds == null) return null;
    for (final p in preds) {
      if (p.isBedtime) return p;
    }
    return null;
  }

  List<SleepPrediction> _getNapPredictions() {
    final preds =
        widget.sleepPrediction
            ?.where((p) => p.isNap && p.end != null)
            .toList() ??
        [];
    final realNapsCount = widget.events
        .where((e) => e['category'] == 'nap')
        .length;

    return preds.where((p) {
      if (p.index != null) {
        return p.index! > realNapsCount;
      }
      return true;
    }).toList();
  }

  void _checkInitialMode() {
    if (widget.forceNightMode != null) {
      setState(() => _isDayMode = !widget.forceNightMode!);
      _isDayMode ? _toggleCtrl.reverse() : _toggleCtrl.forward();
      return;
    }

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
    if (widget.forceNightMode != null) return;
    setState(() => _isDayMode = day);
    day ? _toggleCtrl.reverse() : _toggleCtrl.forward();
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  ({DateTime start, DateTime end}) _computeRange() {
    final todayAsc = List<Map<String, dynamic>>.from(widget.events)
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));
    
    // Lista combinada para buscar de forma más segura el último bedtime
    final allEventsDesc = [...widget.yesterdayEvents, ...widget.events]
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    final d = widget.selectedDate;

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

      if (widget.forceNightMode != null &&
          wokeUp == null &&
          widget.events.isNotEmpty) {
        wokeUp = DateTime.parse(widget.events.first['start_time']).toLocal();
      }

      final predictedBedtime = _getBedtimePrediction()?.start;
      final fallback =
          predictedBedtime ?? DateTime(d.year, d.month, d.day, 20, 30);
      final start = wokeUp ?? DateTime(d.year, d.month, d.day, 7, 0);
      var end = widget.biologicalCycleEnd ?? bedTime ?? fallback;
      if (end.isBefore(start)) end = fallback;
      return (start: start, end: end);
    } else {
      DateTime? bedTime, woke;

      // Buscar el bed_time más reciente (en todos los eventos combinados)
      for (var e in allEventsDesc) {
        if (e['category'] == 'bed_time') {
          bedTime = DateTime.parse(e['start_time']).toLocal();
          break;
        }
      }

      // woke_up viene de today
      for (var e in todayAsc) {
        if (e['category'] == 'woke_up') {
          woke = DateTime.parse(e['start_time']).toLocal();
          break;
        }
      }

      final start = bedTime ?? DateTime(d.year, d.month, d.day - 1, 20, 30);
      var end = woke ?? DateTime(d.year, d.month, d.day, 8, 0);

      if (end.isBefore(start)) {
        end = start.add(const Duration(hours: 11, minutes: 30));
      }

      return (start: start, end: end);
    }
  }

  Widget _buildDynamicMessage() {
    final now = DateTime.now();
    String label = "";
    String timeString = "";
    bool isLateSleep = false;

    final allDesc = [...widget.yesterdayEvents, ...widget.events]
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    if (_isDayMode) {
      final activeNap = allDesc
          .where((e) => e['category'] == 'nap' && e['end_time'] == null)
          .firstOrNull;

      if (activeNap != null) {
        final start = DateTime.parse(activeNap['start_time']).toLocal();
        final diff = now.difference(start);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;

        label = "Durmiendo";
        timeString = h == 0 && m == 0
            ? 'Ahora'
            : h == 0
            ? '$m min'
            : '${h}h ${m}m';
      } else {
        SleepPrediction? nextSleep;
        final naps = _getNapPredictions();
        if (naps.isNotEmpty) {
          nextSleep = naps.first;
        } else {
          nextSleep = _getBedtimePrediction();
        }

        if (nextSleep != null) {
          final diff = nextSleep.start.difference(now);
          isLateSleep = diff.isNegative;
          final absDiff = diff.abs();

          final h = absDiff.inHours;
          final m = absDiff.inMinutes % 60;

          if (isLateSleep) {
            label = nextSleep.isNap ? "Siesta atrasada" : "Dormir atrasado";
          } else {
            label = nextSleep.isNap ? "Próxima siesta en" : "Hora de dormir en";
          }

          timeString = h == 0 && m == 0
              ? 'Ahora'
              : h == 0
              ? '$m min'
              : '${h}h ${m}m';
        } else {
          final lastWokeUp = allDesc
              .where((e) => e['category'] == 'woke_up')
              .firstOrNull;
          final lastEndedNap = allDesc
              .where((e) => e['category'] == 'nap' && e['end_time'] != null)
              .firstOrNull;

          DateTime? awakeStart;
          if (lastWokeUp != null)
            awakeStart = DateTime.parse(lastWokeUp['start_time']).toLocal();

          if (lastEndedNap != null) {
            final napEnd = DateTime.parse(lastEndedNap['end_time']).toLocal();
            if (awakeStart == null || napEnd.isAfter(awakeStart)) {
              awakeStart = napEnd;
            }
          }

          awakeStart ??= _computeRange().start;

          final diff = now.difference(awakeStart);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;

          label = "Despierto durante";
          timeString = h == 0 && m == 0
              ? 'Ahora'
              : h == 0
              ? '$m min'
              : '${h}h ${m}m';
        }
      }
    } else {
      final activeWaking = allDesc
          .where(
            (e) => e['category'] == 'night_waking' && e['end_time'] == null,
          )
          .firstOrNull;

      if (activeWaking != null) {
        final start = DateTime.parse(activeWaking['start_time']).toLocal();
        final diff = now.difference(start);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;

        label = "Despierto durante";
        timeString = h == 0 && m == 0
            ? 'Ahora'
            : h == 0
            ? '$m min'
            : '${h}h ${m}m';
      } else {
        final lastBed = allDesc
            .where((e) => e['category'] == 'bed_time')
            .firstOrNull;
        final lastEndedWaking = allDesc
            .where(
              (e) => e['category'] == 'night_waking' && e['end_time'] != null,
            )
            .firstOrNull;

        DateTime? sleepStart;
        if (lastBed != null)
          sleepStart = DateTime.parse(lastBed['start_time']).toLocal();

        if (lastEndedWaking != null) {
          final wakingEnd = DateTime.parse(
            lastEndedWaking['end_time'],
          ).toLocal();
          if (sleepStart == null || wakingEnd.isAfter(sleepStart)) {
            sleepStart = wakingEnd;
          }
        }

        if (sleepStart != null) {
          final diff = now.difference(sleepStart);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;

          label = "Durmiendo";
          timeString = h == 0 && m == 0
              ? 'Ahora'
              : h == 0
              ? '$m min'
              : '${h}h ${m}m';
        }
      }
    }

    if (label.isNotEmpty) {
      Color labelColor = widget.forceNightMode != null
          ? (_isDayMode ? Colors.black54 : Colors.white54)
          : ClockPalette.textMuted;

      Color timeColor = widget.forceNightMode != null
          ? (_isDayMode ? const Color(0xFF2D3142) : Colors.white)
          : ClockPalette.textPrimary;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: labelColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: timeColor,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
          if (widget.forceNightMode != null &&
              widget.biologicalCycleEnd != null &&
              !isLateSleep) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isDayMode
                    ? Colors.black.withOpacity(0.05)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isDayMode
                    ? 'Dormir a las ${DateFormat('HH:mm').format(widget.biologicalCycleEnd!)}'
                    : 'Previsto: ${widget.biologicalCycleEnd!.difference(_computeRange().start).inHours}h',
                style: TextStyle(
                  color: _isDayMode ? Colors.black54 : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (widget.isLearning && widget.forceNightMode == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: ClockPalette.textMuted, size: 20),
          SizedBox(height: 6),
          Text(
            "BabyCare aún está aprendiendo\nlos patrones de tu bebé\npara darte predicciones.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ClockPalette.textMuted,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty && widget.forceNightMode == null) {
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

    return Align(
      alignment: widget.alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth - 60, 280.0);
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
                    currentProgress: widget.forceNightMode != null
                        ? DateTime.now().difference(startTime).inMinutes /
                              safeTotalMins
                        : null,
                    context: context,
                  ),
                ),

                Positioned(
                  left: startX,
                  top: startY,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: TimeLabel(
                      _formatTime(startTime),
                      color: widget.forceNightMode != null
                          ? (_isDayMode ? Colors.black54 : Colors.white54)
                          : null,
                    ),
                  ),
                ),

                Positioned(
                  left: endX,
                  top: endY,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: TimeLabel(
                      _formatTime(endTime),
                      color: widget.forceNightMode != null
                          ? (_isDayMode ? Colors.black54 : Colors.white54)
                          : null,
                    ),
                  ),
                ),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isToday && widget.forceNightMode == null) ...[
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
                              _dayNightLabel(),
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
                      ],
                    ],
                  ),
                ),

                ...allEvents.map((event) {
                  final cat = event['category'];
                  final meta =
                      (event['metadata'] as Map<String, dynamic>?) ?? {};
                  final eventType = EventType.fromBackend(cat, meta);
                  final evStart = DateTime.parse(event['start_time']).toLocal();

                  if (_isDayMode && cat == 'night_waking') {
                    return const SizedBox.shrink();
                  }
                  if (!_isDayMode && cat == 'nap') {
                    return const SizedBox.shrink();
                  }

                  DateTime displayTime = evStart;

                  final bool hasTemporalWindow =
                      (_isDayMode && cat == 'nap') ||
                      (!_isDayMode && cat == 'night_waking') ||
                      (cat == 'feed' && meta['type'] == 'nursing');

                  if (hasTemporalWindow) {
                    final evEnd = event['end_time'] != null
                        ? DateTime.parse(event['end_time']).toLocal()
                        : DateTime.now();

                    final cs = evStart.isBefore(startTime)
                        ? startTime
                        : evStart;
                    final ce = evEnd.isAfter(endTime) ? endTime : evEnd;

                    if (!cs.isBefore(ce)) return const SizedBox.shrink();

                    final visibleMins = ce.difference(cs).inMinutes;
                    displayTime = cs.add(Duration(minutes: visibleMins ~/ 2));
                  } else {
                    if (evStart.isBefore(startTime) ||
                        evStart.isAfter(endTime)) {
                      return const SizedBox.shrink();
                    }
                    displayTime = evStart;
                  }

                  final fraction =
                      displayTime.difference(startTime).inMinutes /
                      safeTotalMins;
                  final angle = startAngle + (fraction * sweepAngle);

                  const double iconR = 17.0;
                  final x = radius + radius * math.cos(angle);
                  final y = radius + radius * math.sin(angle);

                  return Positioned(
                    left: x - iconR,
                    top: y - iconR,
                    child: GestureDetector(
                      onTap: () {
                        if (widget.onTapEvent != null) {
                          widget.onTapEvent!(event);
                        }
                      },
                      child: EventIcon(eventType: eventType),
                    ),
                  );
                }),

                if (_isDayMode)
                  ..._getNapPredictions().map((pred) {
                    final cs = pred.start.isBefore(startTime)
                        ? startTime
                        : pred.start;
                    final ce = pred.end!.isAfter(endTime) ? endTime : pred.end!;

                    if (!cs.isBefore(ce)) return const SizedBox.shrink();

                    final visibleMins = ce.difference(cs).inMinutes;
                    final displayTime = cs.add(
                      Duration(minutes: visibleMins ~/ 2),
                    );

                    final fraction =
                        displayTime.difference(startTime).inMinutes /
                        safeTotalMins;
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
                      child: GestureDetector(
                        onTap: widget.onTapPrediction,
                        child: EventIcon(
                          eventType: EventType.nap,
                          isPrediction: true,
                        ),
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
                      final angle = startAngle + displayFraction * sweepAngle;

                      const double iconR = 17.0;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: GestureDetector(
                          onTap: widget.onTapPrediction,
                          child: EventIcon(
                            eventType: EventType.bedtime,
                            isPrediction: true,
                          ),
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
                      final angle = startAngle + displayFraction * sweepAngle;

                      const double iconR = 17.0;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: GestureDetector(
                          onTap: widget.onTapPrediction,
                          child: EventIcon(
                            eventType: EventType.wokeUp,
                            isPrediction: true,
                          ),
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

class TimeLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const TimeLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? ClockPalette.textPrimary,
      ),
    );
  }
}