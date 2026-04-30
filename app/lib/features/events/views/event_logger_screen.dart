import 'package:app/core/widgets/custom_top_bar.dart';
import 'package:app/features/events/views/forms/growth_form.dart';
import 'package:app/features/events/views/forms/nursing_form.dart';
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

import '../utils/duration_event_handler.dart';
import '../../analytics/providers/daily_summary_provider.dart';
import '../../events/providers/events_provider.dart';

class EventLoggerScreen extends ConsumerWidget {
  final String babyId;

  const EventLoggerScreen({super.key, required this.babyId});

  Future<void> _logEvent(
    BuildContext context,
    WidgetRef ref,
    String category,
    Map<String, dynamic> metadata,
    DateTime eventTime,
  ) async {
    try {
      await ApiService.registerEvent(babyId, category, metadata, startTime: eventTime);
      _refreshLists(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registrado: $category')));
      }
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

      ref.read(activeBreastfeedingProvider.notifier).start(eventId.toString(), time);
      _refreshLists(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toma iniciada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          const SnackBar(content: Text('La hora de fin no puede ser anterior al inicio')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _refreshLists(WidgetRef ref) {
    final currentDate = ref.read(selectedDateProvider);
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: currentDate)));
    ref.invalidate(dailySummaryProvider((babyId: babyId, date: currentDate)));
    ref.invalidate(lastEventsProvider(babyId));
  }

  void _showEventForm(BuildContext context, WidgetRef ref, EventType eventType) {
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
    final isStoppingNursing = eventType == EventType.nursing && activeNursing != null;

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
          left: 20, right: 20, top: 10,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16, top: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: eventType.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(eventType.icon, color: eventType.accentColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isStoppingNursing ? 'Detener ${eventType.uiLabel}' : eventType.uiLabel,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (isStoppingNursing)
                NursingForm(
                  isEditing: true,
                  initialStartTime: activeNursing.startTime,
                  initialEndTime: DateTime.now(),
                  onSave: (meta, time, [end]) => _stopNursingEvent(ctx, context, ref, activeNursing, meta, end!),
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.bedtime)
                BedtimeForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.bottle)
                BottleForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.nursing)
                NursingForm(onSave: (meta, time, [end]) => _startNursingEvent(ctx, context, ref, meta, time))
              else if (eventType == EventType.solids)
                SolidsForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.diaper)
                DiaperForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.temperature)
                TemperatureForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.medicine || eventType == EventType.bath)
                BasicNotesForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else if (eventType == EventType.growth)
                GrowthForm(onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time))
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  onSave: (meta, time) => _closeAndLog(ctx, context, ref, eventType, meta, time),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _closeAndLog(BuildContext ctx, BuildContext context, WidgetRef ref, EventType type, Map<String, dynamic> meta, DateTime time) {
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
      return (mins > 0 && !short) ? '${diff.inHours}h ${mins}m' : '${diff.inHours}h';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNap = ref.watch(activeNapProvider);
    final activeNightWaking = ref.watch(activeNightWakingProvider);
    final activeNursing = ref.watch(activeBreastfeedingProvider);
    final activePumping = ref.watch(activePumpingProvider);
    final lastEventsAsync = ref.watch(lastEventsProvider(babyId));

    bool isEventActive(EventType type) {
      if (type == EventType.nap) return activeNap != null;
      if (type == EventType.nightWaking) return activeNightWaking != null;
      if (type == EventType.nursing) return activeNursing != null;
      if (type == EventType.pumping) return activePumping != null;
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      appBar: CustomTopBar(
        centerContent: const Text('Registrar Actividad', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: orderedGroups.map((groupKey) {
          final events = groupedEvents[groupKey];
          if (events == null || events.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: events.map((eventType) {
                        final isActive = isEventActive(eventType);
                        final showTime = _showsTimePlaceholder(eventType);

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showEventForm(context, ref, eventType),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 105,
                                height: 130,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isActive 
                                      ? eventType.accentColor.withOpacity(0.1) 
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isActive 
                                        ? eventType.accentColor 
                                        : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                                    width: isActive ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      eventType.icon, 
                                      color: eventType.accentColor, 
                                      size: 28,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          eventType.uiLabel,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12, 
                                            fontWeight: FontWeight.w600, 
                                            height: 1.15,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 16,
                                      child: showTime 
                                          ? lastEventsAsync.when(
                                              data: (eventsMap) {
                                                if (eventType == EventType.diaper) {
                                                  final wetTime = _formatTime(eventsMap['diaper_wet'], short: true);
                                                  final dirtyTime = _formatTime(eventsMap['diaper_dirty'], short: true);

                                                  return Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: const Color.fromARGB(255, 233, 224, 54),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        wetTime,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: Colors.brown.shade400,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        dirtyTime,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                final key = eventType == EventType.bottle ? 'bottle' 
                                                          : eventType == EventType.nursing ? 'breast' 
                                                          : eventType == EventType.solids ? 'solids' 
                                                          : eventType.backendCategory;
                                                
                                                return Text(
                                                  _formatTime(eventsMap[key]),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              },
                                              loading: () => const Center(
                                                child: SizedBox(
                                                  height: 12,
                                                  width: 12,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                              error: (_, __) => Text(
                                                '--',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}