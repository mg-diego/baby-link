import 'package:flutter/material.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/widgets/forms/basic_notes_form.dart';
import 'package:app/features/events/widgets/forms/bed_time_form.dart';
import 'package:app/features/events/widgets/forms/bottle_form.dart';
import 'package:app/features/events/widgets/forms/diaper_form.dart';
import 'package:app/features/events/widgets/forms/growth_form.dart';
import 'package:app/features/events/widgets/forms/placeholder_form.dart';
import 'package:app/features/events/widgets/forms/solids_form.dart';
import 'package:app/features/events/widgets/forms/temperature_form.dart';
import 'package:app/features/events/widgets/forms/wake_up_form.dart';

/// Fuente única del mapeo `EventType -> formulario` para los formularios
/// "simples" (los que comparten la firma `initialTime`/`initialMetadata`/
/// `onSave(meta, time)`).
///
/// La usan tanto el alta ([EventCreationSheet]) como la edición
/// ([EventEditSheet]). Los tipos que requieren un tratamiento especial
/// —lactancia (inicio/fin) y los eventos de duración (siesta, despertar
/// nocturno, extracción)— devuelven `null`, de modo que cada pantalla los
/// resuelva con su propia lógica.
class EventFormFactory {
  const EventFormFactory._();

  /// Devuelve el formulario simple para [eventType], o `null` si el tipo
  /// necesita un tratamiento especial que debe resolver quien llama.
  ///
  /// [onSave] admite una firma `(meta, time)`; las pantallas de edición pueden
  /// pasar un callback con un tercer parámetro opcional `end` (es un subtipo
  /// válido) sin que afecte a estos formularios, que no lo usan.
  static Widget? buildSimpleForm({
    required EventType eventType,
    required Function(Map<String, dynamic>, DateTime) onSave,
    DateTime? initialTime,
    Map<String, dynamic>? initialMetadata,
    String? lastMilkType,
  }) {
    switch (eventType) {
      // Tratamiento especial en quien llama.
      case EventType.nursing:
      case EventType.nap:
      case EventType.nightWaking:
      case EventType.pumping:
        return null;

      case EventType.wokeUp:
        return WakeUpForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.bedtime:
        return BedtimeForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.bottle:
        return BottleForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          lastMilkType: lastMilkType,
          onSave: onSave,
        );
      case EventType.solids:
        return SolidsForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.diaper:
        return DiaperForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.temperature:
        return TemperatureForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.medicine:
      case EventType.bath:
        return BasicNotesForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
      case EventType.growth:
        return GrowthForm(
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );

      // Resto (p. ej. hito): formulario genérico.
      case EventType.milestone:
        return PlaceholderForm(
          title: eventType.uiLabel,
          initialTime: initialTime,
          initialMetadata: initialMetadata,
          onSave: onSave,
        );
    }
  }
}
