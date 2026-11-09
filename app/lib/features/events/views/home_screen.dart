import 'package:app/features/events/widgets/home_screen/prediction_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/daycare_scan/daycare_scan_flow.dart';
import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/event_edit_launcher.dart';
import 'package:app/features/events/views/event_form_launcher.dart';
import 'package:app/features/events/views/nap_skip_actions.dart';
import 'package:app/features/events/widgets/home_screen/biological_cycle_view.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/notifications/sleep_alert_service.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';

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
    // Escaneo de la hoja de la guardería interrumpido porque Android cerró la
    // app con la cámara abierta: se retoma con la foto recuperada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recoverLostDaycareScan(context, widget.babyId);
    });
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

  void _showPredictionInfo(SleepPrediction prediction) {
    final schedule = ref.read(sleepPredictionProvider(widget.babyId)).asData?.value ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PredictionInfoSheet(
        prediction: prediction,
        onSkip: canSkipNap(prediction, schedule, DateTime.now())
            ? () => skipPredictedNap(context, ref, widget.babyId, prediction)
            : null,
      ),
    );
  }

  /// Reprograma los avisos de sueño con la agenda y los ajustes actuales. Se
  /// ignoran los estados de carga para no programar con predicciones viejas.
  void _syncSleepAlerts() {
    final settings = ref.read(sleepAlertSettingsProvider).asData?.value;
    final predictions = ref.read(predictionsProvider(widget.babyId)).asData?.value;
    if (settings == null || predictions == null) return;
    SleepAlertService.sync(predictions.schedule, settings);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(predictionsProvider(widget.babyId), (_, next) {
      if (next.asData != null) _syncSleepAlerts();
    });
    ref.listen(sleepAlertSettingsProvider, (_, next) {
      if (next.asData != null) _syncSleepAlerts();
    });

    return BiologicalCycleView(
      babyId: widget.babyId,
      onTriggerAction: _showEventForm,
      onTapEvent: _handleTap,
      onStopEvent: (e) => _handleTap(e, stopNow: true),
      onTapPrediction: _showPredictionInfo,
    );
  }
}
