import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:app/core/network/api_service.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/shared/models/event_type.dart';

/// Marcar una siesta prevista como "no hecha" (y deshacerlo).
///
/// Se guarda como un evento `nap_skipped` a la hora prevista de la siesta: la
/// API la cuenta como hecha su turno sin sueño y replanifica el resto del día.
/// Deshacer es borrar ese evento, así que también se puede hacer desde el
/// Histórico.

const skippedNapCategory = 'nap_skipped';

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Solo se puede marcar la próxima siesta pendiente, y solo cuando ya le ha
/// llegado la hora (atrasada o supuesta): antes aún puede hacerla.
bool canSkipNap(SleepPrediction p, List<SleepPrediction> schedule, DateTime now) {
  if (!p.isNap) return false;
  final next = schedule.where((s) => s.isNap).firstOrNull;
  if (next == null || next.index != p.index) return false;
  return p.overdue || p.assumed || !p.start.isAfter(now);
}

/// Hora a la que estaba prevista: la calculada, no "ahora" si iba con retraso.
DateTime _plannedStart(SleepPrediction p) {
  final base = p.feedback?['base_start'];
  final parsed = base is String ? DateTime.tryParse(base)?.toLocal() : null;
  return parsed ?? p.start;
}

Future<void> skipPredictedNap(
  BuildContext context,
  WidgetRef ref,
  String babyId,
  SleepPrediction p,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final planned = _plannedStart(p);
  try {
    final response = await ApiService.registerEvent(
      babyId,
      skippedNapCategory,
      {
        if (p.index != null) 'nap_index': p.index,
        'predicted_start_time': planned.toUtc().toIso8601String(),
      },
      startTime: planned,
    );
    ref.read(eventActionProvider).refreshLists(babyId);

    final eventId = (response['data'] as Map?)?['id']?.toString();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Siesta de las ${_hm(planned)} marcada como no hecha'),
        action: eventId == null
            ? null
            : SnackBarAction(
                label: 'Deshacer',
                onPressed: () => _undo(ref, messenger, babyId, eventId),
              ),
      ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _undo(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  String babyId,
  String eventId,
) async {
  try {
    await ApiService.deleteEvent(eventId);
    ref.read(eventActionProvider).refreshLists(babyId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Hecho: la siesta vuelve a contar')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

/// Detalle de una siesta marcada como no hecha, con la opción de deshacerlo.
void showSkippedNapSheet(
  BuildContext context,
  WidgetRef ref,
  String babyId,
  Map<String, dynamic> event,
) {
  final messenger = ScaffoldMessenger.of(context);
  final eventId = event['id'].toString();
  final planned = DateTime.parse(event['start_time']).toLocal();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final muted = scheme.onSurface.withValues(alpha: 0.6);
      final accent = EventType.napSkipped.getAccentColor(ctx);

      return SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(MdiIcons.sleepOff, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Siesta no hecha',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Estaba prevista a las ${_hm(planned)}',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Las predicciones de hoy cuentan con que no durmió. Si en realidad sí '
                'la hizo, deshazlo y registra la siesta con su hora.',
                style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _undo(ref, messenger, babyId, eventId);
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Deshacer: sí la hizo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
