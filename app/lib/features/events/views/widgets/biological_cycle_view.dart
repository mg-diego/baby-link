import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:app/core/models/event_type.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/analytics/providers/daily_summary_provider.dart'; // <-- Añadido para el lastEventsProvider
import 'package:app/features/events/views/widgets/visual_clock/visual_clock_view.dart';

import 'day_sky_background.dart';
import 'night_sky_background.dart';

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
    final now = DateTime.now();
    final todayArgs = (babyId: babyId, date: DateTime(now.year, now.month, now.day));
    final yesterdayArgs = (babyId: babyId, date: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)));

    final todayEventsAsync = ref.watch(dailyEventsProvider(todayArgs));
    final yesterdayEventsAsync = ref.watch(dailyEventsProvider(yesterdayArgs));
    final sleepPredictionAsync = ref.watch(sleepPredictionProvider(babyId));
    final wakePredictionAsync = ref.watch(wakePredictionProvider(babyId));
    final babyAsync = ref.watch(babyProvider);
    
    // Obtenemos el último evento de cada tipo
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
      ..sort((a, b) => DateTime.parse(b['start_time']).compareTo(DateTime.parse(a['start_time'])));

    DateTime? lastWokeUp;
    DateTime? lastBedTime;

    for (var ev in allEvents) {
      if (ev['category'] == 'woke_up' && lastWokeUp == null) {
        lastWokeUp = DateTime.parse(ev['start_time']).toLocal();
      }
      if (ev['category'] == 'bed_time' && lastBedTime == null) {
        lastBedTime = DateTime.parse(ev['start_time']).toLocal();
      }
    }

    bool isNightMode = false;
    if (lastBedTime != null && lastWokeUp != null) {
      isNightMode = lastBedTime.isAfter(lastWokeUp);
    } else if (lastBedTime != null) {
      isNightMode = true;
    }

    final pillBg = isNightMode ? const Color(0xFF242746).withOpacity(0.7) : Colors.white.withOpacity(0.65);
    final pillText = isNightMode ? const Color(0xFF8C9EFF) : const Color(0xFF1565C0);
    final textColorSec = isNightMode ? Colors.white54 : const Color(0xFF455A64);

    String pillLabel;
    if (isNightMode) {
      final nightStart = lastBedTime ?? now;
      pillLabel = '${toBeginningOfSentenceCase(DateFormat('EEEE').format(nightStart))} – ${toBeginningOfSentenceCase(DateFormat('EEEE').format(nightStart.add(const Duration(days: 1))))}';
    } else {
      pillLabel = toBeginningOfSentenceCase(DateFormat('EEEE d').format(now)) ?? '';
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
      return e['end_time'] == null && (cat == 'nursing' || cat == 'nap' || cat == 'night_waking' || cat == 'pumping');
    }).toList();

    final isNapActive = ongoingEvents.any((e) => e['category'] == 'nap');
    final isWakingActive = ongoingEvents.any((e) => e['category'] == 'night_waking');

    // Helper para extraer la fecha exacta del último evento desde la API
    DateTime? getLastTimeFor(EventType type) {
      if (lastEventsAsync.isLoading || lastEventsAsync.hasError) return null;
      final eventsMap = lastEventsAsync.asData?.value ?? {};

      String? isoString;
      if (type == EventType.diaper) {
        final wet = eventsMap['diaper_wet'] as String?;
        final dirty = eventsMap['diaper_dirty'] as String?;
        DateTime? wetDate = wet != null ? DateTime.tryParse(wet) : null;
        DateTime? dirtyDate = dirty != null ? DateTime.tryParse(dirty) : null;
        DateTime? latest = wetDate;
        if (dirtyDate != null && (latest == null || dirtyDate.isAfter(latest))) {
          latest = dirtyDate;
        }
        isoString = latest?.toIso8601String();
      } else {
        final key = type == EventType.bottle ? 'bottle' 
                  : type == EventType.nursing ? 'breast' 
                  : type == EventType.solids ? 'solids' 
                  : type.backendCategory;
        isoString = eventsMap[key] as String?;
      }

      if (isoString == null) return null;
      return DateTime.tryParse(isoString)?.toLocal();
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.person_outline_rounded, color: textColorSec, size: 28),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {},
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (babyName.isNotEmpty)
                            Text(
                              babyName,
                              style: TextStyle(
                                color: isNightMode ? Colors.white : const Color(0xFF2D3142),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          if (babyAge.isNotEmpty)
                            Text(
                              babyAge,
                              style: TextStyle(
                                color: isNightMode ? Colors.white54 : const Color(0xFF546E7A),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: Icon(Icons.calendar_today_rounded, color: textColorSec, size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onOpenHistorical,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isNightMode ? Icons.nights_stay : Icons.wb_sunny_rounded, color: pillText, size: 16),
                      const SizedBox(width: 8),
                      Text(pillLabel, style: TextStyle(color: pillText, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),

                ...ongoingEvents.map((e) => OngoingEventBanner(
                  event: e,
                  isNightMode: isNightMode,
                  onTap: () => onTapEvent(e),
                  onStop: () => onStopEvent(e),
                )),
                
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
                
                Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isNightMode 
                              ? const Color(0xFF1A1C29).withValues(alpha: 0.65) 
                              : Colors.white..withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isNightMode ? Colors.white10 : Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isNightMode 
                          ? [
                              BiologicalActionButton(eventType: EventType.bottle, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.bottle), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.bottle)),
                              BiologicalActionButton(eventType: EventType.diaper, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.diaper), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.diaper)),
                              BiologicalActionButton(eventType: EventType.nightWaking, isNight: isNightMode, isDisabled: isWakingActive, lastEventTime: getLastTimeFor(EventType.nightWaking), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.nightWaking)),
                              BiologicalActionButton(eventType: EventType.wokeUp, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.wokeUp), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.wokeUp)),
                            ]
                          : [
                              BiologicalActionButton(eventType: EventType.bottle, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.bottle), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.bottle)),
                              BiologicalActionButton(eventType: EventType.diaper, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.diaper), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.diaper)),
                              BiologicalActionButton(eventType: EventType.nap, isNight: isNightMode, isDisabled: isNapActive, lastEventTime: getLastTimeFor(EventType.nap), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.nap)),
                              BiologicalActionButton(eventType: EventType.bedtime, isNight: isNightMode, lastEventTime: getLastTimeFor(EventType.bedtime), isLoading: lastEventsAsync.isLoading, onTap: () => onTriggerAction(EventType.bedtime)),
                            ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ... EL ONGOING EVENT BANNER SE MANTIENE IGUAL ...
class OngoingEventBanner extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isNightMode;
  final VoidCallback onTap;
  final VoidCallback onStop;

  const OngoingEventBanner({
    super.key,
    required this.event,
    required this.isNightMode,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cat = event['category'];
    final meta = (event['metadata'] as Map<String, dynamic>?) ?? {};
    final type = EventType.fromBackend(cat, meta);
    final startTime = DateTime.parse(event['start_time']).toLocal();

    final textColor = isNightMode ? Colors.white : const Color(0xFF2D3142);
    final subTextColor = isNightMode ? Colors.white70 : const Color(0xFF546E7A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isNightMode ? type.getAccentColor(context).withOpacity(0.2) : type.getAccentColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: type.getAccentColor(context).withOpacity(isNightMode ? 0.4 : 0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: type.getAccentColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(type.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${type.uiLabel} en curso',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(minutes: 1)),
                        builder: (context, _) {
                          final diff = DateTime.now().difference(startTime);
                          final h = diff.inHours;
                          final m = diff.inMinutes % 60;
                          final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';
                          return Text(
                            'Iniciado hace $timeStr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subTextColor,
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: type.getAccentColor(context),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: type.getAccentColor(context).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    ),
                    child: const Text(
                      'Detener',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BiologicalActionButton extends StatelessWidget {
  final EventType eventType;
  final bool isNight;
  final bool isDisabled;
  final DateTime? lastEventTime;
  final bool isLoading;
  final VoidCallback onTap;

  const BiologicalActionButton({
    super.key,
    required this.eventType,
    required this.isNight,
    this.isDisabled = false,
    this.lastEventTime,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventColor = eventType.getAccentColor(context);

    return Opacity(
      opacity: isDisabled ? 0.35 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: eventColor.withValues(alpha: 0.75), 
                    width: 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), 
                      blurRadius: 4, 
                      offset: const Offset(0, 2)
                    )
                  ],
                ),
                child: Icon(eventType.icon, color: eventColor, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildTimeLabel(eventColor),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(Color color) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );

    if (isLoading) return Text('...', style: textStyle);
    if (lastEventTime == null) return Text('--', style: textStyle);

    return StreamBuilder(
      stream: Stream.periodic(const Duration(minutes: 1)),
      builder: (context, _) {
        final diff = DateTime.now().difference(lastEventTime!);
        String timeStr = 'Ahora';
        if (diff.inDays > 0) {
          timeStr = '${diff.inDays}d';
        } else if (diff.inHours > 0) {
          final mins = diff.inMinutes.remainder(60);
          timeStr = mins > 0 ? '${diff.inHours}h ${mins}m' : '${diff.inHours}h';
        } else if (diff.inMinutes > 0) {
          timeStr = '${diff.inMinutes}m';
        }
        return Text(timeStr, style: textStyle);
      }
    );
  }
}