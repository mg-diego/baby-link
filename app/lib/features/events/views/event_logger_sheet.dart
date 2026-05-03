import 'package:app/core/utils/duration_event_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/widgets/forms/bottle_form.dart';
import 'package:app/features/events/widgets/forms/diaper_form.dart';
import 'package:app/features/events/widgets/forms/placeholder_form.dart';
import 'package:app/features/events/widgets/forms/solids_form.dart';
import 'package:app/features/events/widgets/forms/temperature_form.dart';
import 'package:app/features/events/widgets/forms/wake_up_form.dart';
import 'package:app/features/events/widgets/forms/bed_time_form.dart';
import 'package:app/features/events/widgets/forms/basic_notes_form.dart';
import 'package:app/features/events/widgets/forms/growth_form.dart';
import 'package:app/features/events/widgets/forms/nursing_form.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/widgets/event_sheet/event_grid_button.dart';

class EventLoggerSheet extends ConsumerWidget {
  final String babyId;

  const EventLoggerSheet({super.key, required this.babyId});

  void _showEventForm(
    BuildContext context,
    WidgetRef ref,
    EventType eventType,
  ) {
    // 1. CAPTURAS SEGURAS: Extraemos el servicio y el messenger antes de que los modales mueran.
    final actionService = ref.read(eventActionProvider);
    final messenger = ScaffoldMessenger.of(context);

    // Eventos de duración (Siesta, Pecho, Sacaleches)
    if (eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.pumping) {
      DurationEventHandler.handleAction(
        context: context,
        ref: ref,
        babyId: babyId,
        eventType: eventType,
        onSuccess: () {
          // Solo cerramos el menú Grid cuando la acción haya terminado con éxito
          Navigator.pop(context);
          actionService.refreshLists(babyId);
        },
      );
      return;
    }

    final activeNursing = ref.read(activeNursingProvider);
    final isStoppingNursing =
        eventType == EventType.nursing && activeNursing != null;

    // Helper unificado para guardar, cerrar ambas capas (Formulario y Grid) y notificar
    void executeAndClose(
      BuildContext formCtx,
      Future<void> Function() action,
      String successMessage,
    ) async {
      Navigator.pop(formCtx); // Cierra el formulario activo
      Navigator.pop(context); // Cierra el menú Grid que quedó debajo

      try {
        await action();
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    // Mostramos el formulario por encima de la cuadrícula
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
                      color: eventType
                          .getAccentColor(context)
                          .withOpacity(0.12),
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
                  onSave: (meta, time, [end]) => executeAndClose(
                    ctx,
                    () => actionService.stopNursingEvent(
                      babyId,
                      activeNursing,
                      meta,
                      end!,
                    ),
                    'Toma finalizada',
                  ),
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Despertar registrado',
                  ),
                )
              else if (eventType == EventType.bedtime)
                BedtimeForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'A dormir registrado',
                  ),
                )
              else if (eventType == EventType.bottle)
                BottleForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Biberón registrado',
                  ),
                )
              else if (eventType == EventType.nursing)
                NursingForm(
                  onSave: (meta, time, [end]) => executeAndClose(
                    ctx,
                    () => actionService.startNursingEvent(babyId, meta, time),
                    'Toma iniciada',
                  ),
                )
              else if (eventType == EventType.solids)
                SolidsForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Comida registrada',
                  ),
                )
              else if (eventType == EventType.diaper)
                DiaperForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Pañal registrado',
                  ),
                )
              else if (eventType == EventType.temperature)
                TemperatureForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Temperatura registrada',
                  ),
                )
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                BasicNotesForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    '${eventType.uiLabel} registrado/a',
                  ),
                )
              else if (eventType == EventType.growth)
                GrowthForm(
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    'Crecimiento registrado',
                  ),
                )
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  onSave: (meta, time) => executeAndClose(
                    ctx,
                    () => actionService.logEvent(
                      babyId,
                      eventType.backendCategory,
                      meta,
                      time,
                    ),
                    '${eventType.uiLabel} registrado/a',
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

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
                              onTap: () =>
                                  _showEventForm(context, ref, eventType),
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
