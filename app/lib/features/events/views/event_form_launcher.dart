import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/utils/duration_event_handler.dart';
import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/features/events/widgets/forms/event_creation_form.dart';

/// Punto de entrada único para registrar un evento.
///
/// Lo usan tanto los botones rápidos de la pestaña Inicio como la lista del
/// botón "+" central, de modo que exista una sola fuente de verdad para el
/// mapeo evento -> formulario y para el guardado.
void launchEventForm(
  BuildContext context,
  WidgetRef ref,
  String babyId,
  EventType eventType,
) {
  // Eventos de duración (Siesta, Despertar nocturno, Extracción): tienen su
  // propio flujo de inicio/fin gestionado por DurationEventHandler.
  if (eventType == EventType.nap ||
      eventType == EventType.nightWaking ||
      eventType == EventType.pumping) {
    DurationEventHandler.handleAction(
      context: context,
      ref: ref,
      babyId: babyId,
      eventType: eventType,
      onSuccess: () => ref.read(eventActionProvider).refreshLists(babyId),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => EventCreationSheet(
      babyId: babyId,
      eventType: eventType,
    ),
  );
}
