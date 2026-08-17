import 'package:flutter/material.dart';
import 'package:app/features/events/providers/events_provider.dart';

import 'clock_palette.dart';
import 'visual_clock_logic.dart';

class DynamicClockMessage extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> yesterdayEvents;
  final DateTime selectedDate;
  final List<SleepPrediction>? sleepPrediction;
  final SleepPrediction? wakePrediction;
  final bool isDayMode;
  final bool? forceNightMode;
  final DateTime? biologicalCycleEnd;
  final bool isLearning;
  final double scale;

  const DynamicClockMessage({
    super.key,
    required this.events,
    required this.yesterdayEvents,
    required this.selectedDate,
    required this.sleepPrediction,
    required this.wakePrediction,
    required this.isDayMode,
    required this.forceNightMode,
    required this.biologicalCycleEnd,
    required this.isLearning,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label = "";
    String timeString = "";
    String? bottomPillText;

    final allDesc = [...yesterdayEvents, ...events]
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    DateTime getAwakeStart() {
      final lastWokeUp = allDesc.where((e) => e['category'] == 'woke_up').firstOrNull;
      final lastEndedNap = allDesc.where((e) => e['category'] == 'nap' && e['end_time'] != null).firstOrNull;
      
      DateTime? awakeStart;
      if (lastWokeUp != null) awakeStart = DateTime.parse(lastWokeUp['start_time']).toLocal();
      
      if (lastEndedNap != null) {
        final napEnd = DateTime.parse(lastEndedNap['end_time']).toLocal();
        if (awakeStart == null || napEnd.isAfter(awakeStart)) {
          awakeStart = napEnd;
        }
      }
      
      return awakeStart ?? VisualClockLogic.computeRange(
        events: events,
        yesterdayEvents: yesterdayEvents,
        selectedDate: selectedDate,
        isDayMode: isDayMode,
        forceNightMode: forceNightMode,
        biologicalCycleEnd: biologicalCycleEnd,
        sleepPrediction: sleepPrediction,
      ).start;
    }

    DateTime? getSleepStart() {
      final lastBed = allDesc.where((e) => e['category'] == 'bed_time').firstOrNull;
      final lastEndedWaking = allDesc.where((e) => e['category'] == 'night_waking' && e['end_time'] != null).firstOrNull;
      
      DateTime? sleepStart;
      if (lastBed != null) sleepStart = DateTime.parse(lastBed['start_time']).toLocal();
      
      if (lastEndedWaking != null) {
        final wakingEnd = DateTime.parse(lastEndedWaking['end_time']).toLocal();
        if (sleepStart == null || wakingEnd.isAfter(sleepStart)) {
          sleepStart = wakingEnd;
        }
      }
      
      return sleepStart;
    }

    if (isDayMode) {
      final activeNap = allDesc.where((e) => e['category'] == 'nap' && e['end_time'] == null).firstOrNull;
      
      if (activeNap != null) {
        final start = DateTime.parse(activeNap['start_time']).toLocal();
        final diff = now.difference(start);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        
        label = "Durmiendo";
        timeString = h == 0 && m == 0 ? 'Ahora' : h == 0 ? '$m min' : '${h}h ${m}m';
      } else {
        final awakeStart = getAwakeStart();
        final awakeDiff = now.difference(awakeStart);
        final awakeH = awakeDiff.inHours;
        final awakeM = awakeDiff.inMinutes % 60;

        SleepPrediction? nextSleep;
        final naps = VisualClockLogic.getNapPredictions(sleepPrediction, events);
        
        if (naps.isNotEmpty) {
          nextSleep = naps.first;
        } else {
          nextSleep = VisualClockLogic.getBedtimePrediction(sleepPrediction);
        }

        if (nextSleep != null) {
          final diff = nextSleep.start.difference(now);
          final isLateSleep = diff.isNegative;
          final absDiff = diff.abs();
          
          final h = absDiff.inHours;
          final m = absDiff.inMinutes % 60;

          label = isLateSleep 
              ? (nextSleep.isNap ? "Siesta atrasada" : "Dormir atrasado")
              : (nextSleep.isNap ? "Próxima siesta en" : "Hora de dormir en");
              
          timeString = h == 0 && m == 0 ? 'Ahora' : h == 0 ? '$m min' : '${h}h ${m}m';
          bottomPillText = "Lleva despierto ${awakeH > 0 ? '${awakeH}h ${awakeM}min' : '${awakeM}min'}";
        } else {
          label = "Lleva despierto";
          timeString = awakeH == 0 && awakeM == 0 ? 'Ahora' : awakeH == 0 ? '$awakeM min' : '${awakeH}h ${awakeM}m';
        }
      }
    } else {
      final activeWaking = allDesc.where((e) => e['category'] == 'night_waking' && e['end_time'] == null).firstOrNull;
      
      if (activeWaking != null) {
        final start = DateTime.parse(activeWaking['start_time']).toLocal();
        final diff = now.difference(start);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        
        label = "Lleva despierto";
        timeString = h == 0 && m == 0 ? 'Ahora' : h == 0 ? '$m min' : '${h}h ${m}m';
      } else {
        final sleepStart = getSleepStart();
        
        if (sleepStart != null) {
          final diff = now.difference(sleepStart);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          
          label = "Durmiendo";
          timeString = h == 0 && m == 0 ? 'Ahora' : h == 0 ? '$m min' : '${h}h ${m}m';
        }
      }
    }

    if (label.isNotEmpty) {
      final Color labelColor;
      final Color timeColor;
      final Color pillColor;
      final Color pillTextColor;

      if (forceNightMode != null) {
        if (isDayMode) {
          final double dayDarkness = VisualClockLogic.getDayDarkness();
          labelColor = Color.lerp(Colors.black54, Colors.white54, dayDarkness)!;
          timeColor = Color.lerp(const Color(0xFF2D3142), Colors.white, dayDarkness)!;
          pillColor = Colors.black.withOpacity(0.05 + dayDarkness * 0.10);
          pillTextColor = labelColor;
        } else {
          labelColor = Colors.white54;
          timeColor = Colors.white;
          pillColor = Colors.white.withOpacity(0.08);
          pillTextColor = Colors.white70;
        }
      } else {
        labelColor = ClockPalette.textMuted;
        timeColor = ClockPalette.textPrimary;
        pillColor = Colors.black.withOpacity(0.05);
        pillTextColor = ClockPalette.textMuted;
      }

      final double dayShadow = 0.06 + VisualClockLogic.getDayDarkness() * 0.36;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13 * scale,
              fontWeight: FontWeight.w500,
              color: labelColor,
              letterSpacing: 1.0 * scale,
              shadows: forceNightMode != null && isDayMode
                  ? [Shadow(color: Colors.black.withOpacity(dayShadow), blurRadius: 6 * scale)]
                  : null,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 40 * scale,
              fontWeight: FontWeight.w800,
              color: timeColor,
              letterSpacing: -1.0 * scale,
              height: 1.0,
              shadows: forceNightMode != null && isDayMode
                  ? [Shadow(color: Colors.black.withOpacity(dayShadow), blurRadius: 8 * scale)]
                  : null,
            ),
          ),
          if (bottomPillText != null) ...[
            SizedBox(height: 8 * scale),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Text(
                bottomPillText!,
                style: TextStyle(
                  color: pillTextColor,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (isLearning && forceNightMode == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: ClockPalette.textMuted, size: 20 * scale),
          SizedBox(height: 6 * scale),
          Text(
            "BabyCare aún está aprendiendo\nlos patrones de tu bebé\npara darte predicciones.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12 * scale,
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
}