import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/services/event_action_service.dart';
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

class EventEditSheet extends ConsumerStatefulWidget {
  final String babyId;
  final Map<String, dynamic> event;
  final bool stopNow;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const EventEditSheet({
    super.key,
    required this.babyId,
    required this.event,
    required this.stopNow,
    required this.onDelete,
  });

  @override
  ConsumerState<EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends ConsumerState<EventEditSheet> {
  late final String eventId;
  late final Map<String, dynamic> metadata;
  late final DateTime startTime;
  late final String category;
  late final EventType eventType;
  DateTime? endTime;

  @override
  void initState() {
    super.initState();
    eventId = widget.event['id'].toString();
    metadata = widget.event['metadata'] as Map<String, dynamic>? ?? {};
    startTime = DateTime.parse(widget.event['start_time']).toLocal();
    final endTimeStr = widget.event['end_time'];
    endTime = endTimeStr != null ? DateTime.parse(endTimeStr).toLocal() : null;

    if (widget.stopNow && endTime == null) {
      endTime = DateTime.now();
    }

    category = widget.event['category'];
    eventType = EventType.fromBackend(category, metadata);
  }

  Future<void> _processUpdate(
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

      await ref.read(eventActionProvider).updateEvent(
            widget.babyId,
            eventId,
            payload,
            categoryToStop: category,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _processDelete() async {
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
    if (mounted) {
      Navigator.pop(context);
    }
    widget.onDelete(widget.event);
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
    final accentColor = eventType.getAccentColor(context);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Icon(
            eventType.icon,
            color: accentColor,
            size: 24 * scale,
          ),
        ),
        SizedBox(width: 14 * scale),
        Expanded(
          child: Text(
            widget.stopNow
                ? 'Detener ${eventType.uiLabel}'
                : 'Editar ${eventType.uiLabel}',
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
        IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red, size: 24 * scale),
          onPressed: _processDelete,
        ),
      ],
    );
  }

  Widget _buildForm() {
    if (eventType == EventType.nursing) {
      return NursingForm(
        isEditing: true,
        initialStartTime: startTime,
        initialEndTime: endTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.nap ||
        eventType == EventType.nightWaking ||
        eventType == EventType.pumping) {
      return DurationEditForm(
        initialStartTime: startTime,
        initialEndTime: endTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.wokeUp) {
      return WakeUpForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.bedtime) {
      return BedtimeForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.bottle) {
      return BottleForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.solids) {
      return SolidsForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.diaper) {
      return DiaperForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.temperature) {
      return TemperatureForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.medicine || eventType == EventType.bath) {
      return BasicNotesForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else if (eventType == EventType.growth) {
      return GrowthForm(
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    } else {
      return PlaceholderForm(
        title: eventType.uiLabel,
        initialTime: startTime,
        initialMetadata: metadata,
        onSave: _processUpdate,
      );
    }
  }
}