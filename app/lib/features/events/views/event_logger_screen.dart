import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/event_type.dart';
import 'package:app/core/widgets/custom_time_picker.dart';

import 'package:app/features/events/views/forms/bottle_form.dart';
import 'package:app/features/events/views/forms/diaper_form.dart';
import 'package:app/features/events/views/forms/placeholder_form.dart';
import 'package:app/features/events/views/forms/solids_form.dart';
import 'package:app/features/events/views/forms/temperature_form.dart';
import 'package:app/features/events/views/forms/wake_up_form.dart';
import 'package:app/features/events/views/forms/bed_time_form.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/api_service.dart';
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
      await ApiService.registerEvent(
        babyId,
        category,
        metadata,
        startTime: eventTime,
      );

      final currentDate = ref.read(selectedDateProvider);
      ref.invalidate(dailyEventsProvider((babyId: babyId, date: currentDate)));
      ref.invalidate(dailySummaryProvider((babyId: babyId, date: currentDate)));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registrado: $category')));
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>?
  _getProviderForEventType(EventType type) {
    if (type == EventType.nap) return activeNapProvider;
    if (type == EventType.nightWaking) return activeNightWakingProvider;
    if (type == EventType.nursing) return activeBreastfeedingProvider;
    if (type == EventType.pumping) return activePumpingProvider;
    return null;
  }

  Future<void> _handleDurationEventAction(
    BuildContext context,
    WidgetRef ref,
    EventType eventType,
  ) async {
    final provider = _getProviderForEventType(eventType);
    if (provider == null) return;

    final activeEvent = ref.read(provider);
    final isActive = activeEvent != null;

    if (!isActive) {
      // ── FLUJO: INICIAR EVENTO ──
      final selectedStartTime = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          DateTime tempTime = DateTime.now();
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 10,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20, top: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      'Iniciar ${eventType.uiLabel}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTimePicker(
                      time: tempTime,
                      onTimeChanged: (newTime) =>
                          setModalState(() => tempTime = newTime),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, tempTime),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar inicio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );

      if (selectedStartTime == null) return;

      try {
        Map<String, dynamic> metadata = {};
        if (eventType == EventType.nursing) metadata = {'type': 'breast'};

        final response = await ApiService.registerEvent(
          babyId,
          eventType.backendCategory,
          metadata,
          startTime: selectedStartTime,
        );

        final eventId = response['id'] ?? response['data']?['id'];
        ref
            .read(provider.notifier)
            .start(eventId.toString(), selectedStartTime);
        _refreshLists(ref);
      } catch (e) {
        _showError(context, eventType, e);
      }
    } else {
      // ── FLUJO: DETENER EVENTO (CON EDICIÓN) ──
      final selectedEndTime = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          DateTime tempEndTime = DateTime.now();
          // Evitar que la hora de fin por defecto sea anterior a la de inicio
          if (tempEndTime.isBefore(activeEvent.startTime)) {
            tempEndTime = activeEvent.startTime.add(const Duration(minutes: 1));
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 10,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                final duration = tempEndTime.difference(activeEvent.startTime);
                final isValid = !tempEndTime.isBefore(activeEvent.startTime);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20, top: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      'Detener ${eventType.uiLabel}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Mostrar resumen del evento
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: eventType.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inicio: ${_formatTimeOnly(activeEvent.startTime)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Duración: ${_formatDuration(duration)}',
                                  style: TextStyle(
                                    color: isValid
                                        ? eventType.accentColor
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(eventType.icon, color: eventType.accentColor),
                          ],
                        ),
                      ),
                    ),

                    CustomTimePicker(
                      time: tempEndTime,
                      onTimeChanged: (newTime) =>
                          setModalState(() => tempEndTime = newTime),
                    ),

                    if (!isValid)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          'La hora de fin no puede ser anterior al inicio',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isValid
                            ? () => Navigator.pop(ctx, tempEndTime)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Finalizar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );

      if (selectedEndTime == null) return;

      try {
        await ApiService.updateEvent(activeEvent.eventId, {
          'end_time': selectedEndTime.toUtc().toIso8601String(),
        });
        ref.read(provider.notifier).stop();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${eventType.uiLabel} finalizada correctamente'),
            ),
          );
        }
        _refreshLists(ref);
      } catch (e) {
        _showError(context, eventType, e);
      }
    }
  }

  // Helpers para mantener el código limpio:
  void _refreshLists(WidgetRef ref) {
    final currentDate = ref.read(selectedDateProvider);
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: currentDate)));
    ref.invalidate(dailySummaryProvider((babyId: babyId, date: currentDate)));
  }

  void _showError(BuildContext context, EventType eventType, Object e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error con ${eventType.uiLabel}: $e')),
      );
    }
  }

  String _formatTimeOnly(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "Invalido";
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  void _showEventForm(
    BuildContext context,
    WidgetRef ref,
    EventType eventType,
  ) {
    if (eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.nursing ||
        eventType == EventType.pumping) {
      _handleDurationEventAction(context, ref, eventType);
      return;
    }

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
              // Handle
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
              // Header con color del tipo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: eventType.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      eventType.icon,
                      color: eventType.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    eventType.uiLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (eventType == EventType.wokeUp)
                WakeUpForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.bedtime)
                BedtimeForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.bottle)
                BottleForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.solids)
                SolidsForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.diaper)
                DiaperForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.temperature)
                TemperatureForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                _BasicNotesForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
                )
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(
                      context,
                      ref,
                      eventType.backendCategory,
                      meta,
                      time,
                    );
                  },
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
    final activeNap = ref.watch(activeNapProvider);
    final activeNightWaking = ref.watch(activeNightWakingProvider);
    final activeNursing = ref.watch(activeBreastfeedingProvider);
    final activePumping = ref.watch(activePumpingProvider);

    bool isEventActive(EventType type) {
      if (type == EventType.nap) return activeNap != null;
      if (type == EventType.nightWaking) return activeNightWaking != null;
      if (type == EventType.nursing) return activeNursing != null;
      if (type == EventType.pumping) return activePumping != null;
      return false;
    }

    // Mantener el orden de grupos definido en el enum
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
      appBar: AppBar(
        title: const Text(
          'Registrar Actividad',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: orderedGroups.map((groupKey) {
          final events = groupedEvents[groupKey];
          if (events == null || events.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(
                  groupLabels[groupKey]!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final eventType = events[index];
                  final isActive = isEventActive(eventType);

                  return _EventButton(
                    eventType: eventType,
                    isActive: isActive,
                    onTap: () => _showEventForm(context, ref, eventType),
                  );
                },
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN DE EVENTO
// ─────────────────────────────────────────────────────────────────────────────
class _EventButton extends StatelessWidget {
  final EventType eventType;
  final bool isActive;
  final VoidCallback onTap;

  const _EventButton({
    required this.eventType,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = eventType.accentColor;
    // Cuando está activo usamos rojo para el "detener"
    final Color activeAccent = Colors.red.shade400;

    final Color bgColor = isActive
        ? activeAccent.withOpacity(0.08)
        : accent.withOpacity(0.08);

    final Color borderColor = isActive
        ? activeAccent.withOpacity(0.5)
        : accent.withOpacity(0.25);

    final Color iconColor = isActive ? activeAccent : accent;
    final Color textColor = isActive
        ? activeAccent
        : Theme.of(context).colorScheme.onSurface;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Icono con fondo de color
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.stop_circle_outlined : eventType.icon,
                  size: 17,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isActive ? 'Detener' : eventType.uiLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Indicador de en curso
              if (isActive) _PulseDot(color: activeAccent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUNTO PULSANTE (para botones activos)
// ─────────────────────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO BÁSICO (medicina / baño)
// ─────────────────────────────────────────────────────────────────────────────
class _BasicNotesForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;

  const _BasicNotesForm({required this.onSave});

  @override
  State<_BasicNotesForm> createState() => _BasicNotesFormState();
}

class _BasicNotesFormState extends State<_BasicNotesForm> {
  DateTime _time = DateTime.now();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notas',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => widget.onSave({'notes': _notes.text}, _time),
            child: const Text('Guardar', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
