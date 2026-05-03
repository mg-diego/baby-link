import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/api/api_service.dart';
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

import '../providers/events_provider.dart';
import '../../analytics/providers/daily_summary_provider.dart';
import '../utils/duration_event_handler.dart';

import 'widgets/date_selector.dart';
import 'widgets/event_list_view.dart';
import 'widgets/biological_cycle_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _isHistoricalMode = false;
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
    ref.invalidate(lastEventsProvider(widget.babyId));
  }

  Future<void> _logEvent(
    String category,
    Map<String, dynamic> metadata,
    DateTime eventTime,
  ) async {
    try {
      await ApiService.registerEvent(
        widget.babyId,
        category,
        metadata,
        startTime: eventTime,
      );
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registrado: $category')));
      }
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _startNursingEvent(
    Map<String, dynamic> meta,
    DateTime time,
  ) async {
    Navigator.pop(context);
    try {
      final response = await ApiService.registerEvent(
        widget.babyId,
        EventType.nursing.backendCategory,
        meta,
        startTime: time,
      );
      final eventId = response['id'] ?? response['data']?['id'];
      ref
          .read(activeBreastfeedingProvider.notifier)
          .start(eventId.toString(), time);
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Toma iniciada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _stopNursingEvent(
    ActiveEvent activeEvent,
    Map<String, dynamic> meta,
    DateTime endTime,
  ) async {
    Navigator.pop(context);
    if (endTime.isBefore(activeEvent.startTime)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error en hora')));
      }
      return;
    }
    try {
      await ApiService.updateEvent(activeEvent.eventId, {
        'end_time': endTime.toUtc().toIso8601String(),
        'metadata': meta,
      });
      ref.read(activeBreastfeedingProvider.notifier).stop();
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Toma finalizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        onSuccess: _invalidateAll,
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
                  onSave: (meta, time, [end]) =>
                      _stopNursingEvent(activeNursing, meta, end!),
                )
              else if (eventType == EventType.wokeUp)
                WakeUpForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.bedtime)
                BedtimeForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.bottle)
                BottleForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.nursing)
                NursingForm(
                  onSave: (meta, time, [end]) => _startNursingEvent(meta, time),
                )
              else if (eventType == EventType.solids)
                SolidsForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.diaper)
                DiaperForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.temperature)
                TemperatureForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.medicine ||
                  eventType == EventType.bath)
                BasicNotesForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else if (eventType == EventType.growth)
                GrowthForm(
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                )
              else
                PlaceholderForm(
                  title: eventType.uiLabel,
                  onSave: (meta, time) {
                    Navigator.pop(ctx);
                    _logEvent(eventType.backendCategory, meta, time);
                  },
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
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
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        await ApiService.updateEvent(eventId, payload);
        
        if (category == 'nursing' && newEnd != null) {
          ref.read(activeBreastfeedingProvider.notifier).stop();
        }

        _invalidateAll();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Actualizado')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }

    Future<void> processDelete() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar registro'),
          content: const Text('¿Estás seguro de que quieres eliminar este evento? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      if (mounted) Navigator.pop(context);

      try {
        await ApiService.deleteEvent(eventId);
        
        if (endTimeStr == null) {
          if (category == 'nap') ref.read(activeNapProvider.notifier).stop();
          if (category == 'night_waking') ref.read(activeNightWakingProvider.notifier).stop();
          if (category == 'nursing') ref.read(activeBreastfeedingProvider.notifier).stop();
          if (category == 'pumping') ref.read(activePumpingProvider.notifier).stop();
        }

        _invalidateAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
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
              Stack(
                alignment: Alignment.center,
                children: [
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
                        stopNow ? 'Detener ${eventType.uiLabel}' : 'Editar ${eventType.uiLabel}',
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

  void _showPredictionInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24, top: 12),
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
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 32),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      return _buildHistoricalView();
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

  Widget _buildHistoricalView() {
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
                'Histórico',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              );
            }
            final dob = DateTime.parse(baby['dob']);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(
                    baby['name'].isNotEmpty
                        ? baby['name'][0].toUpperCase()
                        : 'B',
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
                      baby['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      _calculateAge(dob),
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
            'Histórico',
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
          DateSelector(babyId: widget.babyId),
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
                  if (value != null) setState(() => _viewMode = value);
                },
              ),
            ),
          ),
          if (_viewMode == 1) const Divider(height: 1),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final yesterdayEvents = eventsYdayAsync.asData?.value ?? [];
                if (_viewMode == 0) {
                  return VisualClockView(
                    key: ValueKey('clock_${events.hashCode}'),
                    events: List<Map<String, dynamic>>.from(events),
                    yesterdayEvents: List<Map<String, dynamic>>.from(
                      yesterdayEvents,
                    ),
                    selectedDate: selectedDate,
                    sleepPrediction: sleepPredictionAsync.asData?.value,
                    wakePrediction: wakePredictionAsync.asData?.value,
                    isLearning: sleepPredictionAsync.asData?.value == null,
                  );
                }
                return EventListView(
                  key: ValueKey('list_${events.hashCode}'),
                  initialEvents: List<Map<String, dynamic>>.from(events),
                  yesterdayEvents: List<Map<String, dynamic>>.from(
                    yesterdayEvents,
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