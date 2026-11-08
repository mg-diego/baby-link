import 'package:app/features/events/widgets/home_screen/prediction_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/event_edit_launcher.dart';
import 'package:app/features/events/views/event_form_launcher.dart';
import 'package:app/features/events/widgets/home_screen/biological_cycle_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
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

  void _handleTap(Map<String, dynamic> event, {bool stopNow = false}) {
    launchEventEdit(context, ref, widget.babyId, event, stopNow: stopNow);
  }

  void _showEventForm(EventType eventType) {
    launchEventForm(context, ref, widget.babyId, eventType);
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
    return BiologicalCycleView(
      babyId: widget.babyId,
      onTriggerAction: _showEventForm,
      onTapEvent: _handleTap,
      onStopEvent: (e) => _handleTap(e, stopNow: true),
      onTapPrediction: _showPredictionInfo,
    );
  }
}
