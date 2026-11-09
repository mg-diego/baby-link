import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';

/// Una notificación a programar.
class PlannedAlert {
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;

  const PlannedAlert({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
  });
}

/// Rango de ids reservado para los avisos de sueño: al resincronizar se
/// cancelan todos y se vuelven a crear a partir de la agenda actual.
const sleepAlertBaseId = 7100;
const sleepAlertMaxCount = 12;

/// Convierte la agenda prevista en avisos "X minutos antes".
///
/// No se avisa si la hora del aviso ya ha pasado (p. ej. una siesta "atrasada",
/// que la API sitúa en `now`, o una que empieza antes del margen elegido): un
/// aviso a destiempo solo molesta. Durante la noche la agenda viene vacía, así
/// que tampoco hay avisos.
List<PlannedAlert> planSleepAlerts(
  List<SleepPrediction> schedule,
  SleepAlertSettings settings,
  DateTime now,
) {
  final alerts = <PlannedAlert>[];
  for (final item in schedule) {
    if (alerts.length >= sleepAlertMaxCount) break;

    final int lead;
    final String title;
    if (item.isNap && settings.napsEnabled) {
      lead = settings.napLeadMinutes;
      title = '${item.isCatnap ? 'Siesta corta' : 'Siesta'} en $lead min';
    } else if (item.isBedtime && settings.bedtimeEnabled) {
      lead = settings.bedtimeLeadMinutes;
      title = 'Hora de dormir en $lead min';
    } else {
      continue;
    }

    final fireAt = item.start.subtract(Duration(minutes: lead));
    if (!fireAt.isAfter(now)) continue;

    alerts.add(PlannedAlert(
      id: sleepAlertBaseId + alerts.length,
      fireAt: fireAt,
      title: title,
      body: 'Prevista a las ${_hhmm(item.start.toLocal())}',
    ));
  }
  return alerts;
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
