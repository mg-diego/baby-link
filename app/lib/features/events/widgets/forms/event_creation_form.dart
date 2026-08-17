import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/widgets/forms/basic_notes_form.dart';
import 'package:app/features/events/widgets/forms/bed_time_form.dart';
import 'package:app/features/events/widgets/forms/bottle_form.dart';
import 'package:app/features/events/widgets/forms/diaper_form.dart';
import 'package:app/features/events/widgets/forms/growth_form.dart';
import 'package:app/features/events/widgets/forms/nursing_form.dart';
import 'package:app/features/events/widgets/forms/placeholder_form.dart';
import 'package:app/features/events/widgets/forms/solids_form.dart';
import 'package:app/features/events/widgets/forms/temperature_form.dart';
import 'package:app/features/events/widgets/forms/wake_up_form.dart';

class EventCreationSheet extends ConsumerStatefulWidget {
  final String babyId;
  final EventType eventType;

  const EventCreationSheet({
    super.key,
    required this.babyId,
    required this.eventType,
  });

  @override
  ConsumerState<EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends ConsumerState<EventCreationSheet> {
  String? lastMilkType;

  @override
  void initState() {
    super.initState();
    _fetchLastMilkType();
  }

  void _fetchLastMilkType() {
    if (widget.eventType == EventType.bottle) {
      final now = DateTime.now();
      final todayArgs = (
        babyId: widget.babyId,
        date: DateTime(now.year, now.month, now.day),
      );
      final yesterdayArgs = (
        babyId: widget.babyId,
        date: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
      );

      final todayEvents = ref.read(dailyEventsProvider(todayArgs)).value ?? [];
      final yesterdayEvents = ref.read(dailyEventsProvider(yesterdayArgs)).value ?? [];

      final allEvents = [...todayEvents, ...yesterdayEvents]
        ..sort((a, b) => DateTime.parse(b['start_time']).compareTo(DateTime.parse(a['start_time'])));

      final lastBottleEvent = allEvents.where((e) => e['category'] == 'feed' && e['metadata']?['type'] == 'bottle').firstOrNull;

      if (lastBottleEvent != null) {
        lastMilkType = lastBottleEvent['metadata']?['milk_type'];
      }
    }
  }

  Future<void> _saveAndClose(Map<String, dynamic> meta, DateTime time) async {
    Navigator.pop(context);

    Map<String, dynamic> finalMeta = Map.from(meta);

    if (widget.eventType == EventType.bedtime) {
      final predictionsState = ref.read(sleepPredictionProvider(widget.babyId));
      final predictions = predictionsState.asData?.value;

      final bedTimePrediction = predictions?.where((p) => p.isBedtime).firstOrNull;

      if (bedTimePrediction != null) {
        finalMeta['predicted_start_time'] = bedTimePrediction.start.toUtc().toIso8601String();
      }
    }

    try {
      await ref.read(eventActionProvider).logEvent(
            widget.babyId,
            widget.eventType.backendCategory,
            finalMeta,
            time,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrado: ${widget.eventType.uiLabel}')),
        );
      }
    } catch (e) {
      log('Error al guardar evento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final scale = (size.width / 400).clamp(0.85, 1.2);
    final horizontalPadding = size.width > 600 ? (size.width - 600) / 2 : 0.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.9),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: viewInsets.bottom,
              left: 24 * scale,
              right: 24 * scale,
              top: 12 * scale,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDragHandle(scale),
                  SizedBox(height: 16 * scale),
                  _buildHeader(scale),
                  SizedBox(height: 24 * scale),
                  _buildForm(),
                  SizedBox(height: 32 * scale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(double scale) {
    return Center(
      child: Container(
        width: 48 * scale,
        height: 5 * scale,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeader(double scale) {
    final activeNursing = ref.watch(activeNursingProvider);
    final isStoppingNursing = widget.eventType == EventType.nursing && activeNursing != null;
    final accentColor = widget.eventType.getAccentColor(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Icon(
            widget.eventType.icon,
            color: accentColor,
            size: 24 * scale,
          ),
        ),
        SizedBox(width: 14 * scale),
        Expanded(
          child: Text(
            isStoppingNursing ? 'Detener ${widget.eventType.uiLabel}' : widget.eventType.uiLabel,
            style: TextStyle(
              fontSize: 22 * scale,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final activeNursing = ref.watch(activeNursingProvider);
    final isStoppingNursing = widget.eventType == EventType.nursing && activeNursing != null;

    if (isStoppingNursing) {
      return NursingForm(
        isEditing: true,
        initialStartTime: activeNursing.startTime,
        initialEndTime: DateTime.now(),
        onSave: (meta, time, [end]) async {
          Navigator.pop(context);
          try {
            await ref.read(eventActionProvider).stopNursingEvent(
                  widget.babyId,
                  activeNursing,
                  meta,
                  end!,
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Toma finalizada')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      );
    } 
    
    if (widget.eventType == EventType.wokeUp) {
      return WakeUpForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.bedtime) {
      return BedtimeForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.bottle) {
      return BottleForm(lastMilkType: lastMilkType, onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.nursing) {
      return NursingForm(
        onSave: (meta, time, [end]) async {
          Navigator.pop(context);
          try {
            await ref.read(eventActionProvider).startNursingEvent(widget.babyId, meta, time);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Toma iniciada')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      );
    } 
    if (widget.eventType == EventType.solids) {
      return SolidsForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.diaper) {
      return DiaperForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.temperature) {
      return TemperatureForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.medicine || widget.eventType == EventType.bath) {
      return BasicNotesForm(onSave: _saveAndClose);
    } 
    if (widget.eventType == EventType.growth) {
      return GrowthForm(onSave: _saveAndClose);
    }

    return PlaceholderForm(title: widget.eventType.uiLabel, onSave: _saveAndClose);
  }
}