import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_view.dart';

import 'day_sky_background.dart';
import 'night_sky_background.dart';
import 'header_icon_button.dart';
import 'biological_action_bar.dart';
import 'ongoing_event_banner.dart';

class BiologicalCycleView extends ConsumerWidget {
  final String babyId;
  final VoidCallback onOpenHistorical;
  final Function(EventType) onTriggerAction;
  final Function(Map<String, dynamic>) onTapEvent;
  final Function(Map<String, dynamic>) onStopEvent;
  final VoidCallback onTapPrediction;

  const BiologicalCycleView({
    super.key,
    required this.babyId,
    required this.onOpenHistorical,
    required this.onTriggerAction,
    required this.onTapEvent,
    required this.onStopEvent,
    required this.onTapPrediction,
  });

  double _skyPhase() {
    final now = DateTime.now();
    final h = now.hour + now.minute / 60.0;
    return ((h - 5.0) / 16.0).clamp(0.0, 1.0);
  }

  double _dayDarkness() {
    final now = DateTime.now();
    final h = now.hour + now.minute / 60.0;
    if (h < 16.5) return 0.0;
    if (h > 18.5) return 1.0;
    return ((h - 16.5) / 2.0).clamp(0.0, 1.0);
  }

  Color _dayTextPrimary() {
    final t = _dayDarkness();
    return Color.lerp(const Color(0xFF2D3142), Colors.white, t)!;
  }

  Color _dayTextSecondary() {
    final t = _dayDarkness();
    return Color.lerp(
      const Color(0xFF546E7A),
      Colors.white.withOpacity(0.75),
      t,
    )!;
  }

  double _dayTextShadow() {
    return 0.06 + _dayDarkness() * 0.36;
  }

  String _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      final previousMonth = DateTime(now.year, now.month, 0);
      days += previousMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final yStr = years == 1 ? '1 año' : '$years años';
    final mStr = months == 1 ? '1 mes' : '$months meses';
    final dStr = days == 1 ? '1 día' : '$days días';

    if (years > 0) return '$yStr, $mStr, $dStr';
    if (months > 0) return '$mStr, $dStr';
    return dStr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Intl.defaultLocale = 'es';
    final size = MediaQuery.sizeOf(context);
    final now = DateTime.now();
    final todayArgs = (
      babyId: babyId,
      date: DateTime(now.year, now.month, now.day),
    );
    final yesterdayArgs = (
      babyId: babyId,
      date: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
    );

    final todayEventsAsync = ref.watch(dailyEventsProvider(todayArgs));
    final yesterdayEventsAsync = ref.watch(dailyEventsProvider(yesterdayArgs));
    final sleepPredictionAsync = ref.watch(sleepPredictionProvider(babyId));
    final wakePredictionAsync = ref.watch(wakePredictionProvider(babyId));
    final babyAsync = ref.watch(babyProvider);
    final lastEventsAsync = ref.watch(lastEventsProvider(babyId));

    if (todayEventsAsync.isLoading || yesterdayEventsAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1222),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final todayEvents = todayEventsAsync.asData?.value ?? [];
    final yesterdayEvents = yesterdayEventsAsync.asData?.value ?? [];
    final allEvents = [...todayEvents, ...yesterdayEvents]
      ..sort(
        (a, b) => DateTime.parse(b['start_time']).compareTo(DateTime.parse(a['start_time'])),
      );

    DateTime? lastWokeUp;
    DateTime? lastBedTime;

    for (var ev in allEvents) {
      final cat = ev['category'];
      if (cat == 'woke_up' && lastWokeUp == null) {
        lastWokeUp = DateTime.parse(ev['start_time']).toLocal();
      }
      if ((cat == 'bedtime' || cat == 'bed_time') && lastBedTime == null) {
        lastBedTime = DateTime.parse(ev['start_time']).toLocal();
      }
    }

    bool isNightMode = false;
    if (lastBedTime != null && lastWokeUp != null) {
      isNightMode = lastBedTime.isAfter(lastWokeUp);
    } else if (lastBedTime != null) {
      isNightMode = true;
    }

    DateTime cycleStart = isNightMode
        ? (lastBedTime ?? now.subtract(const Duration(hours: 8)))
        : (lastWokeUp ?? now.subtract(const Duration(hours: 2)));
    DateTime cycleEnd;

    if (isNightMode) {
      final wakePred = wakePredictionAsync.asData?.value;
      cycleEnd = wakePred?.start ?? cycleStart.add(const Duration(hours: 11));
    } else {
      final preds = sleepPredictionAsync.asData?.value;
      final bedPred = preds?.where((p) => p.isBedtime).firstOrNull;
      cycleEnd = bedPred?.start ?? cycleStart.add(const Duration(hours: 12));
    }

    if (now.isAfter(cycleEnd)) {
      cycleEnd = now.add(const Duration(minutes: 30));
    }

    String babyName = '';
    String babyAge = '';
    if (babyAsync.asData?.value != null) {
      final baby = babyAsync.asData!.value!;
      babyName = baby['name'] ?? '';
      if (baby['dob'] != null) {
        babyAge = _calculateAge(DateTime.parse(baby['dob']));
      }
    }

    final ongoingEvents = allEvents.where((e) {
      final cat = e['category'];
      final metadata = e['metadata'] as Map<String, dynamic>? ?? {};

      return e['end_time'] == null &&
          ((cat == 'feed' && metadata['type'] == 'nursing') ||
              cat == 'nap' ||
              cat == 'night_waking' ||
              cat == 'pumping');
    }).toList();

    final isNapActive = ongoingEvents.any((e) => e['category'] == 'nap');
    final isWakingActive = ongoingEvents.any((e) => e['category'] == 'night_waking');

    DateTime? getLastTimeFor(EventType type) {
      if (lastEventsAsync.isLoading || lastEventsAsync.hasError) return null;
      final eventsMap = lastEventsAsync.asData?.value ?? {};

      String? isoString;

      if (type == EventType.diaper) {
        final wet = eventsMap['diaper_wet'] as String?;
        final dirty = eventsMap['diaper_dirty'] as String?;
        final wetDate = wet != null ? DateTime.tryParse(wet) : null;
        final dirtyDate = dirty != null ? DateTime.tryParse(dirty) : null;

        DateTime? latest = wetDate;
        if (dirtyDate != null && (latest == null || dirtyDate.isAfter(latest))) {
          latest = dirtyDate;
        }
        isoString = latest?.toIso8601String();
      } else {
        String key;
        switch (type) {
          case EventType.bottle:
            key = 'bottle';
            break;
          case EventType.nursing:
            key = 'nursing';
            break;
          case EventType.solids:
            key = 'solids';
            break;
          default:
            key = type.backendCategory;
        }
        isoString = eventsMap[key] as String?;
      }

      return isoString == null ? null : DateTime.tryParse(isoString)?.toLocal();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          isNightMode ? const NightSkyBackground() : const DaySkyBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.05,
                    vertical: size.height * 0.02,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HeaderIconButton(
                          icon: Icons.person_outline_rounded,
                          isNightMode: isNightMode,
                          dayIconColor: _dayTextPrimary().withOpacity(0.75),
                          onTap: () {},
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.04,
                              vertical: size.height * 0.008,
                            ),
                            decoration: BoxDecoration(
                              color: isNightMode
                                  ? Colors.black.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isNightMode
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.55),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (babyName.isNotEmpty)
                                  Text(
                                    babyName,
                                    style: TextStyle(
                                      color: isNightMode ? Colors.white : _dayTextPrimary(),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(
                                            isNightMode ? 0.40 : _dayTextShadow(),
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (babyAge.isNotEmpty)
                                  Text(
                                    babyAge,
                                    style: TextStyle(
                                      color: isNightMode
                                          ? Colors.white.withOpacity(0.65)
                                          : _dayTextSecondary(),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(
                                            isNightMode ? 0.30 : _dayTextShadow() * 0.7,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: HeaderIconButton(
                          icon: Icons.calendar_today_rounded,
                          isNightMode: isNightMode,
                          dayIconColor: _dayTextPrimary().withOpacity(0.75),
                          onTap: onOpenHistorical,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: VisualClockView(
                    events: List<Map<String, dynamic>>.from(todayEvents),
                    yesterdayEvents: List<Map<String, dynamic>>.from(yesterdayEvents),
                    selectedDate: DateTime(now.year, now.month, now.day),
                    sleepPrediction: sleepPredictionAsync.asData?.value,
                    wakePrediction: wakePredictionAsync.asData?.value,
                    isLearning: sleepPredictionAsync.asData?.value == null,
                    forceNightMode: isNightMode,
                    biologicalCycleEnd: cycleEnd,
                    onTapEvent: onTapEvent,
                    onTapPrediction: onTapPrediction,
                  ),
                ),
                BiologicalActionBar(
                  isNightMode: isNightMode,
                  isNapActive: isNapActive,
                  isWakingActive: isWakingActive,
                  isLoading: lastEventsAsync.isLoading,
                  getLastTimeFor: getLastTimeFor,
                  onTriggerAction: onTriggerAction,
                ),
                if (ongoingEvents.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: size.height * 0.25),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ongoingEvents
                            .map(
                              (e) => OngoingEventBanner(
                                event: e,
                                isNightMode: isNightMode,
                                onTap: () => onTapEvent(e),
                                onStop: () => onStopEvent(e),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                SizedBox(height: size.height * 0.02),
              ],
            ),
          ),
        ],
      ),
    );
  }
}