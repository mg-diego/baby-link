import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/views/nap_skip_actions.dart';
import 'package:app/features/events/widgets/forms/event_edit_form.dart';

/// Punto de entrada único para editar (o detener) un evento existente.
///
/// Lo usan tanto la pestaña Inicio como la pestaña Histórico, para que el
/// flujo de edición y borrado sea el mismo en ambas.
void launchEventEdit(
  BuildContext context,
  WidgetRef ref,
  String babyId,
  Map<String, dynamic> event, {
  bool stopNow = false,
}) {
  // Una siesta marcada como no hecha no se edita: solo se puede deshacer.
  if (event['category'] == skippedNapCategory) {
    showSkippedNapSheet(context, ref, babyId, event);
    return;
  }

  // Contexto estable de la pantalla que abre el sheet: el del sheet deja de
  // ser válido en cuanto se cierra, y los SnackBar se muestran después.
  final messenger = ScaffoldMessenger.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => EventEditSheet(
      babyId: babyId,
      event: event,
      stopNow: stopNow,
      onDelete: (e) => deleteEventWithFeedback(ref, messenger, babyId, e),
    ),
  );
}

/// Borra el evento y muestra el resultado en un SnackBar.
Future<void> deleteEventWithFeedback(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  String babyId,
  Map<String, dynamic> event,
) async {
  try {
    await ref.read(eventActionProvider).deleteEvent(
          babyId,
          event['id'].toString(),
          event['category'],
          event['end_time'],
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('Evento eliminado')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
