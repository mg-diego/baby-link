import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/widgets/event_sheet/event_grid_button.dart';

/// Lista agrupada con todos los eventos posibles (botón "+" central).
///
/// Es un selector puro: al pulsar un evento delega en [onSelect]. El mapeo
/// evento -> formulario y el guardado viven en `launchEventForm`, compartido
/// con los botones rápidos de Inicio.
class EventLoggerSheet extends ConsumerWidget {
  final String babyId;
  final void Function(EventType eventType) onSelect;

  const EventLoggerSheet({
    super.key,
    required this.babyId,
    required this.onSelect,
  });

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
          type != EventType.pumping)
        return false;
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
        if (type == EventType.wokeUp || type == EventType.nightWaking) return true;
      }

      if (isNapActive) {
        if (type == EventType.bedtime || type == EventType.wokeUp || type == EventType.nightWaking) return true;
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
                if (events == null || events.isEmpty)
                  return const SizedBox.shrink();

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
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
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
                            return EventGridButton(
                              eventType: eventType,
                              isDisabled: isLogicallyDisabled(eventType),
                              isActive: isEventActive(eventType),
                              lastEventsAsync: lastEventsAsync,
                              onTap: () => onSelect(eventType),
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