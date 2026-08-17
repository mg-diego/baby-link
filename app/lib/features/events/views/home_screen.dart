import 'package:app/features/events/widgets/forms/event_creation_form.dart';
import 'package:app/features/events/widgets/forms/event_edit_form.dart';
import 'package:app/features/events/widgets/home_screen/prediction_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/utils/duration_event_handler.dart';
import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/historical_view.dart';
import 'package:app/features/events/widgets/home_screen/biological_cycle_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
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

      await ref.read(eventActionProvider).deleteEvent(widget.babyId, eventId, category, endTimeStr);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handleTap(Map<String, dynamic> event, {bool stopNow = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventEditSheet(
        babyId: widget.babyId,
        event: event,
        stopNow: stopNow,
        onDelete: _handleDelete,
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
        onSuccess: () => ref.read(eventActionProvider).refreshLists(widget.babyId),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventCreationSheet(
        babyId: widget.babyId,
        eventType: eventType,
      ),
    );
  }

  void _showPredictionInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PredictionInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isHistoricalMode) {
      return HistoricalView(
        babyId: widget.babyId,
        onBack: () => setState(() => _isHistoricalMode = false),
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