import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/event_type.dart';
import 'package:app/api/api_service.dart';

import 'forms/bottle_form.dart';
import 'forms/diaper_form.dart';
import 'forms/placeholder_form.dart';
import 'forms/solids_form.dart';
import 'forms/temperature_form.dart';
import 'forms/wake_up_form.dart';
import 'forms/bed_time_form.dart';
import 'forms/basic_notes_form.dart';
import 'package:app/features/events/views/forms/growth_form.dart';
import 'package:app/features/events/views/forms/nursing_form.dart';

import '../utils/duration_event_handler.dart';
import '../../analytics/providers/daily_summary_provider.dart';
import '../../events/providers/events_provider.dart';

class EventLoggerSheet extends ConsumerWidget {
  final String babyId;

  const EventLoggerSheet({super.key, required this.babyId});

  Future<void> _logEvent(
    BuildContext context,
    WidgetRef ref,
    String category,
    Map<String, dynamic> metadata,
    DateTime eventTime,
  ) async {
    try {
      await ApiService.registerEvent(
        babyId,
        category,
        metadata,
        startTime: eventTime,
      );
      
      if (!context.mounted) return;

      _refreshLists(ref);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registrado: $category')));
      
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _startNursingEvent(
    BuildContext ctx,
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> meta,
    DateTime time,
  ) async {
    Navigator.pop(ctx);
    try {
      final response = await ApiService.registerEvent(
        babyId,
        EventType.nursing.backendCategory,
        meta,
        startTime: time,
      );

      final eventId = response['id'] ?? response['data']?['id'];

      ref
          .read(activeBreastfeedingProvider.notifier)
          .start(eventId.toString(), time);
      _refreshLists(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Toma iniciada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _stopNursingEvent(
    BuildContext ctx,
    BuildContext context,
    WidgetRef ref,
    ActiveEvent activeEvent,
    Map<String, dynamic> meta,
    DateTime endTime,
  ) async {
    Navigator.pop(ctx);

    if (endTime.isBefore(activeEvent.startTime)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La hora de fin no puede ser anterior al inicio'),
          ),
        );
      }
      return;
    }

    try {
      await ApiService.updateEvent(activeEvent.eventId, {
        'end_time': endTime.toUtc().toIso8601String(),
        'metadata': meta,
      });

      ref.read(activeBreastfeedingProvider.notifier).stop();
      _refreshLists(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toma finalizada correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _refreshLists(WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final currentDate = ref.read(selectedDateProvider);

    ref.invalidate(dailyEventsProvider((babyId: babyId, date: today)));
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: yesterday)));
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: currentDate)));
    
    ref.invalidate(dailySummaryProvider((babyId: babyId, date: currentDate)));
    
    ref.invalidate(lastEventsProvider(babyId));
    ref.invalidate(sleepPredictionProvider(babyId));
    ref.invalidate(wakePredictionProvider(babyId));
  }

  void _showEventForm(
    BuildContext context,
    WidgetRef ref,
    EventType eventType,
  ) {
    Navigator.pop(context);

    if (eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.pumping) {
      DurationEventHandler.handleAction(
        context: context,
        ref: ref,
        babyId: babyId,
        eventType: eventType,
        onSuccess: () => _refreshLists(ref),
      );
      return;
    }

    final activeNursing = ref.read(activeBreastfeedingProvider);
    final isStoppingNursing =
        eventType == EventType.nursing && activeNursing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 10,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16, top: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: eventType.getAccentColor(context).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      eventType.icon,
                      color: eventType.getAccentColor(context),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isStoppingNursing
                        ? 'Detener ${eventType.uiLabel}'
                        : eventType.uiLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (isStoppingNursing)
                NursingForm(
                  isEditing: true,
                  initialStartTime: activeNursing.startTime,
                  initialEndTime: DateTime.now(),
                  onSave: (meta, time, [end]) => _stopNursingEvent(
                    ctx,
                    context,
                    ref,
                    activeNursing,
                    meta,
                    end!,
                  ),
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.bedtime)
                BedtimeForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.bottle)
                BottleForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.nursing)
                NursingForm(
                  onSave: (meta, time, [end]) =>
                      _startNursingEvent(ctx, context, ref, meta, time),
                )
              else if (eventType == EventType.solids)
                SolidsForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.diaper)
                DiaperForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.temperature)
                TemperatureForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                BasicNotesForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else if (eventType == EventType.growth)
                GrowthForm(
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                )
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  onSave: (meta, time) =>
                      _closeAndLog(ctx, context, ref, eventType, meta, time),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _closeAndLog(
    BuildContext ctx,
    BuildContext context,
    WidgetRef ref,
    EventType type,
    Map<String, dynamic> meta,
    DateTime time,
  ) {
    Navigator.pop(ctx);
    _logEvent(context, ref, type.backendCategory, meta, time);
  }

  bool _showsTimePlaceholder(EventType type) {
    return type == EventType.wokeUp ||
        type == EventType.nap ||
        type == EventType.bedtime ||
        type == EventType.bottle ||
        type == EventType.nursing ||
        type == EventType.solids ||
        type == EventType.bath ||
        type == EventType.nightWaking ||
        type == EventType.diaper;
  }

  String _formatTime(String? isoString, {bool short = false}) {
    if (isoString == null) return '--';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '--';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) {
      final mins = diff.inMinutes.remainder(60);
      return (mins > 0 && !short)
          ? '${diff.inHours}h ${mins}m'
          : '${diff.inHours}h';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayArgs = (
      babyId: babyId,
      date: DateTime(now.year, now.month, now.day),
    );
    final yesterdayArgs = (
      babyId: babyId,
      date: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1)),
    );

    final todayEvents =
        ref.watch(dailyEventsProvider(todayArgs)).asData?.value ?? [];
    final yesterdayEvents =
        ref.watch(dailyEventsProvider(yesterdayArgs)).asData?.value ?? [];
    final lastEventsAsync = ref.watch(lastEventsProvider(babyId));

    final allEvents = [...todayEvents, ...yesterdayEvents]
      ..sort(
        (a, b) => DateTime.parse(
          b['start_time'],
        ).compareTo(DateTime.parse(a['start_time'])),
      );

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

    bool isEventActive(EventType type) {
      if (type != EventType.nap &&
          type != EventType.nightWaking &&
          type != EventType.nursing &&
          type != EventType.pumping) {
        return false;
      }

      return todayEvents.any((e) {
        final cat = e['category'];
        final meta = (e['metadata'] as Map<String, dynamic>?) ?? {};
        final evType = EventType.fromBackend(cat, meta);
        return evType == type && e['end_time'] == null;
      });
    }

    final isNapActive = isEventActive(EventType.nap);

    bool isLogicallyDisabled(EventType type) {
      if (isEventActive(type)) return true;

      if (isNightMode) {
        if (type == EventType.bedtime || type == EventType.nap) return true;
      } else {
        if (type == EventType.wokeUp || type == EventType.nightWaking) {
          return true;
        }
      }

      if (isNapActive) {
        if (type == EventType.bedtime ||
            type == EventType.wokeUp ||
            type == EventType.nightWaking) {
          return true;
        }
      }

      return false;
    }

    final orderedGroups = ['sleep', 'feeding', 'care', 'health'];
    final groupLabels = {
      'sleep': 'Sueño',
      'feeding': 'Alimentación',
      'care': 'Cuidado e Higiene',
      'health': 'Salud y Crecimiento',
    };

    final Map<String, List<EventType>> groupedEvents = {};
    for (var event in EventType.values) {
      groupedEvents.putIfAbsent(event.uiGroup, () => []).add(event);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 65) / 4; 

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12, top: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Registrar Actividad',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              children: orderedGroups.map((groupKey) {
                final events = groupedEvents[groupKey];
                if (events == null || events.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              groupLabels[groupKey]!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 12,
                          alignment: WrapAlignment.start,
                          children: events.map((eventType) {
                            final isDisabled = isLogicallyDisabled(eventType);
                            final showTime = _showsTimePlaceholder(eventType);

                            return Opacity(
                              opacity: isDisabled ? 0.35 : 1.0,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isDisabled
                                      ? null
                                      : () => _showEventForm(
                                          context,
                                          ref,
                                          eventType,
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: itemWidth,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: eventType.getBackgroundColor(context),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: eventType.getAccentColor(context).withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            eventType.icon,
                                            color: eventType.getAccentColor(context),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          eventType.uiLabel,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (showTime && !isDisabled) ...[
                                          const SizedBox(height: 2),
                                          SizedBox(
                                            height: 12,
                                            child: lastEventsAsync.when(
                                              data: (eventsMap) {
                                                if (eventType == EventType.diaper) {
                                                  final wetTime = _formatTime(
                                                    eventsMap['diaper_wet'],
                                                    short: true,
                                                  );
                                                  final dirtyTime = _formatTime(
                                                    eventsMap['diaper_dirty'],
                                                    short: true,
                                                  );

                                                  return Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration: const BoxDecoration(
                                                          color: Color.fromARGB(255, 233, 224, 54),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        wetTime,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration: BoxDecoration(
                                                          color: Colors.brown.shade400,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        dirtyTime,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                final key = eventType == EventType.bottle
                                                    ? 'bottle'
                                                    : eventType == EventType.nursing
                                                        ? 'breast'
                                                        : eventType == EventType.solids
                                                            ? 'solids'
                                                            : eventType.backendCategory;

                                                return Text(
                                                  _formatTime(eventsMap[key], short: true),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              },
                                              loading: () => const Center(
                                                child: SizedBox(
                                                  height: 8,
                                                  width: 8,
                                                  child: CircularProgressIndicator(strokeWidth: 1),
                                                ),
                                              ),
                                              error: (_, __) => Text(
                                                '--',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}