import 'dart:math' as math;
import 'package:app/features/events/widgets/visual_clock/dynamic_clock_message.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_logic.dart';
import 'package:flutter/material.dart';
import 'package:app/shared/models/event_type.dart';
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

class _VisualClockViewState extends State<VisualClockView> with SingleTickerProviderStateMixin {
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

    final range = VisualClockLogic.computeRange(
      events: widget.events,
      yesterdayEvents: widget.yesterdayEvents,
      selectedDate: widget.selectedDate,
      isDayMode: _isDayMode,
      forceNightMode: widget.forceNightMode,
      biologicalCycleEnd: widget.biologicalCycleEnd,
      sleepPrediction: widget.sleepPrediction,
    );

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
          final size = math.min(constraints.maxWidth - 50, 320.0);
          final scale = size / 280.0;
          final radius = size / 2;

          final arcStartX = radius + radius * math.cos(startAngle);
          final arcStartY = radius + radius * math.sin(startAngle);
          
          final arcEndX = radius + radius * math.cos(endAngle);
          final arcEndY = radius + radius * math.sin(endAngle);

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
                    napPredictions: VisualClockLogic.getNapPredictions(
                      widget.sleepPrediction,
                      widget.events,
                    ),
                    currentProgress: widget.forceNightMode != null
                        ? DateTime.now().difference(startTime).inMinutes / safeTotalMins
                        : null,
                    context: context,
                  ),
                ),
                Positioned(
                  left: arcStartX,
                  top: arcStartY + (22 * scale),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: TimeLabel(
                      VisualClockLogic.formatTime(startTime),
                      scale: scale,
                      color: widget.forceNightMode != null
                          ? (_isDayMode ? Colors.black54 : Colors.white54)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  left: arcEndX,
                  top: arcEndY + (22 * scale),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: TimeLabel(
                      VisualClockLogic.formatTime(endTime),
                      scale: scale,
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
                              _isDayMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                              size: 14 * scale,
                              color: ClockPalette.textMuted,
                            ),
                            SizedBox(width: 6 * scale),
                            Text(
                              VisualClockLogic.dayNightLabel(_isDayMode, widget.selectedDate),
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: ClockPalette.textMuted,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * scale),
                        Text(
                          '${VisualClockLogic.formatTime(startTime)}–${VisualClockLogic.formatTime(endTime)}',
                          style: TextStyle(
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.w700,
                            color: ClockPalette.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        ClockToggle(isDayMode: _isDayMode, onToggle: _setMode),
                      ] else ...[
                        DynamicClockMessage(
                          events: widget.events,
                          yesterdayEvents: widget.yesterdayEvents,
                          selectedDate: widget.selectedDate,
                          sleepPrediction: widget.sleepPrediction,
                          wakePrediction: widget.wakePrediction,
                          isDayMode: _isDayMode,
                          forceNightMode: widget.forceNightMode,
                          biologicalCycleEnd: widget.biologicalCycleEnd,
                          isLearning: widget.isLearning,
                          scale: scale,
                        ),
                      ],
                    ],
                  ),
                ),
                ...allEvents.map((event) {
                  final cat = event['category'];
                  final meta = (event['metadata'] as Map<String, dynamic>?) ?? {};
                  final eventType = EventType.fromBackend(cat, meta);
                  final evStart = DateTime.parse(event['start_time']).toLocal();

                  if (_isDayMode && cat == 'night_waking') return const SizedBox.shrink();
                  if (!_isDayMode && cat == 'nap') return const SizedBox.shrink();

                  DateTime displayTime = evStart;
                  final bool hasTemporalWindow = (_isDayMode && cat == 'nap') ||
                      (!_isDayMode && cat == 'night_waking') ||
                      (cat == 'feed' && meta['type'] == 'nursing');

                  if (hasTemporalWindow) {
                    final evEnd = event['end_time'] != null
                        ? DateTime.parse(event['end_time']).toLocal()
                        : DateTime.now();
                    final cs = evStart.isBefore(startTime) ? startTime : evStart;
                    final ce = evEnd.isAfter(endTime) ? endTime : evEnd;

                    if (!cs.isBefore(ce)) return const SizedBox.shrink();

                    final visibleMins = ce.difference(cs).inMinutes;
                    displayTime = cs.add(Duration(minutes: visibleMins ~/ 2));
                  } else {
                    if (evStart.isBefore(startTime) || evStart.isAfter(endTime)) {
                      return const SizedBox.shrink();
                    }
                    displayTime = evStart;
                  }

                  final fraction = displayTime.difference(startTime).inMinutes / safeTotalMins;
                  final angle = startAngle + (fraction * sweepAngle);
                  final double iconR = 17.0 * scale;
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
                      child: EventIcon(eventType: eventType, scale: scale),
                    ),
                  );
                }),
                if (_isDayMode)
                  ...VisualClockLogic.getNapPredictions(widget.sleepPrediction, widget.events).map((pred) {
                    final cs = pred.start.isBefore(startTime) ? startTime : pred.start;
                    final ce = pred.end!.isAfter(endTime) ? endTime : pred.end!;

                    if (!cs.isBefore(ce)) return const SizedBox.shrink();

                    final visibleMins = ce.difference(cs).inMinutes;
                    final displayTime = cs.add(Duration(minutes: visibleMins ~/ 2));
                    final fraction = displayTime.difference(startTime).inMinutes / safeTotalMins;
                    
                    if (fraction < 0 || fraction > 1) return const SizedBox.shrink();

                    final angle = startAngle + fraction * sweepAngle;
                    final double iconR = 17.0 * scale;
                    final x = radius + radius * math.cos(angle);
                    final y = radius + radius * math.sin(angle);

                    return Positioned(
                      left: x - iconR,
                      top: y - iconR,
                      child: GestureDetector(
                        onTap: widget.onTapPrediction,
                        child: EventIcon(eventType: EventType.nap, isPrediction: true, scale: scale),
                      ),
                    );
                  }),
                if (_isDayMode && VisualClockLogic.getBedtimePrediction(widget.sleepPrediction) != null)
                  Builder(
                    builder: (_) {
                      final pred = VisualClockLogic.getBedtimePrediction(widget.sleepPrediction)!;
                      final fraction = pred.start.difference(startTime).inMinutes / safeTotalMins;

                      if (fraction < 0 || fraction > 1.05) return const SizedBox.shrink();

                      final displayFraction = fraction.clamp(0.0, 1.0);
                      final angle = startAngle + displayFraction * sweepAngle;
                      final double iconR = 17.0 * scale;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: GestureDetector(
                          onTap: widget.onTapPrediction,
                          child: EventIcon(eventType: EventType.bedtime, isPrediction: true, scale: scale),
                        ),
                      );
                    },
                  ),
                if (!_isDayMode && widget.wakePrediction != null)
                  Builder(
                    builder: (_) {
                      final pred = widget.wakePrediction!;
                      final fraction = pred.start.difference(startTime).inMinutes / safeTotalMins;

                      if (fraction < 0 || fraction > 1.05) return const SizedBox.shrink();

                      final displayFraction = fraction.clamp(0.0, 1.0);
                      final angle = startAngle + displayFraction * sweepAngle;
                      final double iconR = 17.0 * scale;
                      final x = radius + radius * math.cos(angle);
                      final y = radius + radius * math.sin(angle);

                      return Positioned(
                        left: x - iconR,
                        top: y - iconR,
                        child: GestureDetector(
                          onTap: widget.onTapPrediction,
                          child: EventIcon(eventType: EventType.wokeUp, isPrediction: true, scale: scale),
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