import 'package:app/core/utils/duration_event_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/widgets/forms/basic_notes_form.dart';
import 'package:app/features/events/widgets/forms/bed_time_form.dart';
import 'package:app/features/events/widgets/forms/bottle_form.dart';
import 'package:app/features/events/widgets/forms/diaper_form.dart';
import 'package:app/features/events/widgets/forms/duration_edit_form.dart';
import 'package:app/features/events/widgets/forms/growth_form.dart';
import 'package:app/features/events/widgets/forms/nursing_form.dart';
import 'package:app/features/events/widgets/forms/placeholder_form.dart';
import 'package:app/features/events/widgets/forms/solids_form.dart';
import 'package:app/features/events/widgets/forms/temperature_form.dart';
import 'package:app/features/events/widgets/forms/wake_up_form.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/historical_view.dart';
import 'package:app/features/events/widgets/home_screen/biological_cycle_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _isHistoricalMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(eventActionProvider).refreshLists(widget.babyId);
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> event) async {
    try {
      final eventId = event['id'].toString();
      final category = event['category'];
      final endTimeStr = event['end_time'];

      await ref
          .read(eventActionProvider)
          .deleteEvent(widget.babyId, eventId, category, endTimeStr);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _handleTap(Map<String, dynamic> event, {bool stopNow = false}) {
    final eventId = event['id'].toString();
    final metadata = event['metadata'] as Map<String, dynamic>? ?? {};
    final startTime = DateTime.parse(event['start_time']).toLocal();
    final endTimeStr = event['end_time'];
    DateTime? endTime = endTimeStr != null
        ? DateTime.parse(endTimeStr).toLocal()
        : null;

    if (stopNow && endTime == null) {
      endTime = DateTime.now();
    }

    final category = event['category'];
    final eventType = EventType.fromBackend(category, metadata);

    Future<void> processUpdate(
      Map<String, dynamic> updatedMeta,
      DateTime newStart, [
      DateTime? newEnd,
    ]) async {
      Navigator.pop(context);
      try {
        final payload = <String, dynamic>{
          'start_time': newStart.toUtc().toIso8601String(),
          'metadata': updatedMeta,
        };
        if (newEnd != null) {
          payload['end_time'] = newEnd.toUtc().toIso8601String();
        }

        await ref
            .read(eventActionProvider)
            .updateEvent(
              widget.babyId,
              eventId,
              payload,
              categoryToStop: category,
            );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Actualizado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    Future<void> processDelete() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar registro'),
          content: const Text(
            '¿Estás seguro de que quieres eliminar este evento? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'Eliminar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      if (mounted) Navigator.pop(context);
      _handleDelete(event);
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
              Stack(
                alignment: Alignment.center,
                children: [
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
                        stopNow
                            ? 'Detener ${eventType.uiLabel}'
                            : 'Editar ${eventType.uiLabel}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: processDelete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (eventType == EventType.nursing)
                NursingForm(
                  isEditing: true,
                  initialStartTime: startTime,
                  initialEndTime: endTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.nap ||
                  eventType == EventType.nightWaking ||
                  eventType == EventType.pumping)
                DurationEditForm(
                  initialStartTime: startTime,
                  initialEndTime: endTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.bedtime)
                BedtimeForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.bottle)
                BottleForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.solids)
                SolidsForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.diaper)
                DiaperForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.temperature)
                TemperatureForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                BasicNotesForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else if (eventType == EventType.growth)
                GrowthForm(
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                )
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  initialTime: startTime,
                  initialMetadata: metadata,
                  onSave: processUpdate,
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventForm(EventType eventType) {
    if (eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.pumping) {
      DurationEventHandler.handleAction(
        context: context,
        ref: ref,
        babyId: widget.babyId,
        eventType: eventType,
        onSuccess: () =>
            ref.read(eventActionProvider).refreshLists(widget.babyId),
      );
      return;
    }

    final activeNursing = ref.read(activeBreastfeedingProvider);
    final isStoppingNursing =
        eventType == EventType.nursing && activeNursing != null;

    void saveAndClose(Map<String, dynamic> meta, DateTime time) async {
      Navigator.pop(context);
      try {
        await ref
            .read(eventActionProvider)
            .logEvent(widget.babyId, eventType.backendCategory, meta, time);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registrado: ${eventType.uiLabel}')),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
                  onSave: (meta, time, [end]) async {
                    Navigator.pop(context);
                    try {
                      await ref
                          .read(eventActionProvider)
                          .stopNursingEvent(
                            widget.babyId,
                            activeNursing,
                            meta,
                            end!,
                          );
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Toma finalizada')),
                        );
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(onSave: saveAndClose)
              else if (eventType == EventType.bedtime)
                BedtimeForm(onSave: saveAndClose)
              else if (eventType == EventType.bottle)
                BottleForm(onSave: saveAndClose)
              else if (eventType == EventType.nursing)
                NursingForm(
                  onSave: (meta, time, [end]) async {
                    Navigator.pop(context);
                    try {
                      await ref
                          .read(eventActionProvider)
                          .startNursingEvent(widget.babyId, meta, time);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Toma iniciada')),
                        );
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                )
              else if (eventType == EventType.solids)
                SolidsForm(onSave: saveAndClose)
              else if (eventType == EventType.diaper)
                DiaperForm(onSave: saveAndClose)
              else if (eventType == EventType.temperature)
                TemperatureForm(onSave: saveAndClose)
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                BasicNotesForm(onSave: saveAndClose)
              else if (eventType == EventType.growth)
                GrowthForm(onSave: saveAndClose)
              else
                PlaceholderForm(title: eventType.uiLabel, onSave: saveAndClose),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showPredictionInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(
          bottom: 40,
          left: 24,
          right: 24,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.amber,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Predicciones de IA',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Los iconos con destellos (✨) representan estimaciones creadas por nuestro algoritmo basadas en el ritmo biológico de tu bebé y su historial.\n\nSon guías para ayudarte a anticipar sus ventanas de sueño.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isHistoricalMode) {
      return HistoricalView(
        babyId: widget.babyId,
        onRefresh: () async {
          ref.read(eventActionProvider).refreshLists(widget.babyId);
        },
        onDelete: _handleDelete,
        onTap: _handleTap,
      );
    }

    return BiologicalCycleView(
      babyId: widget.babyId,
      onOpenHistorical: () => setState(() => _isHistoricalMode = true),
      onTriggerAction: _showEventForm,
      onTapEvent: _handleTap,
      onStopEvent: (e) => _handleTap(e, stopNow: true),
      onTapPrediction: _showPredictionInfo,
    );
  }
}
