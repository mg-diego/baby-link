import 'package:app/core/models/event_type.dart';
import 'package:app/core/widgets/custom_top_bar.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/events/views/forms/basic_notes_form.dart';
import 'package:app/features/events/views/forms/bed_time_form.dart';
import 'package:app/features/events/views/forms/bottle_form.dart';
import 'package:app/features/events/views/forms/diaper_form.dart';
import 'package:app/features/events/views/forms/duration_edit_form.dart';
import 'package:app/features/events/views/forms/growth_form.dart';
import 'package:app/features/events/views/forms/nursing_form.dart';
import 'package:app/features/events/views/forms/placeholder_form.dart';
import 'package:app/features/events/views/forms/solids_form.dart';
import 'package:app/features/events/views/forms/temperature_form.dart';
import 'package:app/features/events/views/forms/wake_up_form.dart';
import 'package:app/features/events/views/widgets/visual_clock/visual_clock_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/api/api_service.dart';
import '../providers/events_provider.dart';
import '../../analytics/providers/daily_summary_provider.dart';

// Importa tus nuevos widgets separados
import 'widgets/date_selector.dart';
import 'widgets/event_list_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _viewMode = 0;

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
      _invalidateAll();
    }
  }

  // ── LÓGICA PARA CALCULAR LA EDAD ──
  String _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      // Obtener los días del mes anterior
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

  Future<void> _invalidateAll() async {
    final selectedDate = ref.read(selectedDateProvider);
    ref.invalidate(
      dailyEventsProvider((babyId: widget.babyId, date: selectedDate)),
    );
    ref.invalidate(
      dailyEventsProvider((
        babyId: widget.babyId,
        date: selectedDate.subtract(const Duration(days: 1)),
      )),
    );
    ref.invalidate(
      dailySummaryProvider((babyId: widget.babyId, date: selectedDate)),
    );
    ref.invalidate(sleepPredictionProvider(widget.babyId));
    ref.invalidate(wakePredictionProvider(widget.babyId));
  }

  Future<void> _handleDelete(Map<String, dynamic> event) async {
    try {
      await ApiService.deleteEvent(event['id'].toString());
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _handleTap(Map<String, dynamic> event) {
    final eventId = event['id'].toString();
    final metadata = event['metadata'] as Map<String, dynamic>? ?? {};
    final startTime = DateTime.parse(event['start_time']).toLocal();
    final endTimeStr = event['end_time'];
    final endTime = endTimeStr != null
        ? DateTime.parse(endTimeStr).toLocal()
        : null;
    final category = event['category'];

    final eventType = EventType.fromBackend(category, metadata);

    final isDurationEvent =
        eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.pumping;

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

        await ApiService.updateEvent(eventId, payload);

        _invalidateAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento actualizado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorText = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorText)));
        }
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
                    'Editar ${eventType.uiLabel}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              else if (isDurationEvent)
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

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final args = (babyId: widget.babyId, date: selectedDate);
    final argsYday = (
      babyId: widget.babyId,
      date: selectedDate.subtract(const Duration(days: 1)),
    );

    final eventsAsync = ref.watch(dailyEventsProvider(args));
    final eventsYdayAsync = ref.watch(dailyEventsProvider(argsYday));
    final sleepPredictionAsync = ref.watch(
      sleepPredictionProvider(widget.babyId),
    );
    final wakePredictionAsync = ref.watch(
      wakePredictionProvider(widget.babyId),
    );

    // Obtenemos los datos del bebé desde el provider
    final babyAsync = ref.watch(babyProvider);

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isToday = selectedDate == today;

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: CustomTopBar(
        centerContent: babyAsync.when(
          data: (baby) {
            if (baby == null) {
              return const Text(
                'Mi Bebé',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              );
            }

            final dob = DateTime.parse(baby['dob']);
            final ageStr = _calculateAge(dob);
            final name = baby['name'];
            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  // Si tu API devuelve una foto, puedes usar backgroundImage: NetworkImage(baby['photo_url']),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      ageStr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.55),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const CupertinoActivityIndicator(),
          error: (_, __) => const Text(
            'Mi Bebé',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _invalidateAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. SELECTOR DE FECHAS ──
          DateSelector(babyId: widget.babyId),

          // ── 2. TOGGLE DE VISTA (Estilo iOS) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _viewMode,
                thumbColor: primaryColor,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                padding: const EdgeInsets.all(4),
                children: {
                  0: _buildSegmentContent(0, 'Reloj', Icons.av_timer_rounded),
                  1: _buildSegmentContent(
                    1,
                    'Lista',
                    Icons.format_list_bulleted_rounded,
                  ),
                },
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() => _viewMode = value);
                  }
                },
              ),
            ),
          ),

          if (_viewMode == 1) const Divider(height: 1),

          // ── 4. ÁREA DE CONTENIDO ──
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final yesterdayEvents = eventsYdayAsync.asData?.value ?? [];
                final sleepPrediction = sleepPredictionAsync.asData?.value;
                final wakePrediction = wakePredictionAsync.asData?.value;

                final isLearning = sleepPrediction == null;

                if (_viewMode == 0) {
                  return VisualClockView(
                    key: ValueKey('clock_${events.hashCode}'),
                    events: List<Map<String, dynamic>>.from(events),
                    yesterdayEvents: List<Map<String, dynamic>>.from(
                      yesterdayEvents,
                    ),
                    selectedDate: selectedDate,
                    sleepPrediction: sleepPrediction,
                    wakePrediction: wakePrediction,
                    isLearning: isLearning,
                  );
                }

                return EventListView(
                  key: ValueKey('list_${events.hashCode}'),
                  initialEvents: List<Map<String, dynamic>>.from(events),
                  yesterdayEvents: List<Map<String, dynamic>>.from(
                    eventsYdayAsync.asData?.value ?? [],
                  ),
                  isToday: isToday,
                  onRefresh: _invalidateAll,
                  onDelete: _handleDelete,
                  onTap: _handleTap,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para construir el interior de cada segmento del selector iOS
  Widget _buildSegmentContent(int index, String text, IconData icon) {
    final isSelected = _viewMode == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
