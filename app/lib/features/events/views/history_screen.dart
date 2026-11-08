import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/event_edit_launcher.dart';
import 'package:app/features/events/views/historical_view.dart';

/// Pestaña "Histórico" del menú principal: consulta de días pasados en modo
/// reloj o lista, con edición y borrado de eventos.
class HistoryScreen extends ConsumerWidget {
  final String babyId;
  const HistoryScreen({super.key, required this.babyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HistoricalView(
      babyId: babyId,
      onRefresh: () async {
        ref.read(eventActionProvider).refreshLists(babyId);
      },
      onDelete: (event) => deleteEventWithFeedback(
        ref,
        ScaffoldMessenger.of(context),
        babyId,
        event,
      ),
      onTap: (event, {bool stopNow = false}) =>
          launchEventEdit(context, ref, babyId, event, stopNow: stopNow),
    );
  }
}
