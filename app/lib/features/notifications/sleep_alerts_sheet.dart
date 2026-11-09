import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/notifications/sleep_alert_planner.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';
import 'package:app/features/notifications/sleep_alert_settings_card.dart';

/// Próximo aviso de sueño que va a sonar con la agenda y los ajustes actuales,
/// o `null` si no hay ninguno (avisos desactivados, de noche, cargando…).
PlannedAlert? nextSleepAlert(WidgetRef ref, String babyId) {
  final settings = ref.watch(sleepAlertSettingsProvider).asData?.value;
  final schedule = ref.watch(sleepPredictionProvider(babyId)).asData?.value;
  if (settings == null || schedule == null || !settings.anyEnabled) return null;
  final alerts = planSleepAlerts(schedule, settings, DateTime.now());
  return alerts.isEmpty ? null : alerts.first;
}

String formatAlertTime(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

void showSleepAlertsSheet(BuildContext context, String babyId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SleepAlertsSheet(babyId: babyId),
  );
}

/// Ajustes rápidos de los avisos de sueño, accesibles desde Inicio.
class SleepAlertsSheet extends ConsumerWidget {
  final String babyId;

  const SleepAlertsSheet({super.key, required this.babyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final settings = ref.watch(sleepAlertSettingsProvider).asData?.value;
    final next = nextSleepAlert(ref, babyId);

    final String status;
    if (settings == null || !settings.anyEnabled) {
      status = 'Activa un aviso y te avisaremos antes de la siesta o de la hora '
          'de dormir que prevé BabyLink.';
    } else if (next == null) {
      status = 'No hay avisos pendientes por ahora. Se programan solos cuando '
          'hay nuevas predicciones.';
    } else {
      status = 'Próximo aviso a las ${formatAlertTime(next.fireAt)}: '
          '${next.title.toLowerCase()}.';
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: SingleChildScrollView(
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
                        color: scheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Avisos de sueño',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(status, style: TextStyle(fontSize: 13, color: muted, height: 1.35)),
                const SizedBox(height: 16),
                const SleepAlertSettingsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
