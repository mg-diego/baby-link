import 'package:app/core/network/api_service.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/notifications/sleep_alert_planner.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Programa en el propio dispositivo los avisos previos a siestas y a la hora
/// de dormir. Es Dart "plano" (sin Riverpod) para poder usarlo también desde el
/// isolate en segundo plano del widget de acciones rápidas.
///
/// Cada sincronización cancela los avisos anteriores y crea los nuevos a partir
/// de la agenda actual, así que basta con llamarla cada vez que cambien las
/// predicciones (al registrar o editar un evento) o los ajustes.
class SleepAlertService {
  SleepAlertService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _init;
  static Future<void> _queue = Future.value();

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sleep_alerts',
      'Avisos de sueño',
      channelDescription: 'Aviso antes de la próxima siesta o de la hora de dormir',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> _ensureInitialized() => _init ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Los permisos se piden al activar los avisos, no al arrancar la app
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      )
      .then((_) {});

  /// Pide permiso para mostrar notificaciones. Devuelve si está concedido.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Reprograma los avisos a partir de [schedule]. Las llamadas se encolan para
  /// que dos sincronizaciones seguidas no se pisen.
  static Future<void> sync(List<SleepPrediction> schedule, SleepAlertSettings settings) {
    if (!_supported) return Future.value();
    return _queue = _queue.then((_) => _sync(schedule, settings)).catchError((Object e) {
      debugPrint('Error programando avisos de sueño: $e');
    });
  }

  /// Variante para segundo plano: lee ajustes y predicciones por su cuenta.
  static Future<void> syncFromApi(String babyId) async {
    final settings = await SleepAlertSettings.load();
    if (!settings.anyEnabled) return sync(const [], settings);
    final raw = await ApiService.getPredictions(babyId);
    final schedule = raw.schedule
        .cast<Map<String, dynamic>>()
        .map(SleepPrediction.fromJson)
        .toList();
    await sync(schedule, settings);
  }

  static Future<void> cancelAll() => sync(const [], const SleepAlertSettings());

  static Future<void> _sync(List<SleepPrediction> schedule, SleepAlertSettings settings) async {
    await _ensureInitialized();
    for (var i = 0; i < sleepAlertMaxCount; i++) {
      await _plugin.cancel(id: sleepAlertBaseId + i);
    }

    final alerts = planSleepAlerts(schedule, settings, DateTime.now());
    if (alerts.isEmpty) return;

    final mode = await _scheduleMode();
    for (final alert in alerts) {
      await _plugin.zonedSchedule(
        id: alert.id,
        // Instante absoluto en UTC: no depende de la zona horaria del dispositivo
        scheduledDate: tz.TZDateTime.from(alert.fireAt.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: mode,
        title: alert.title,
        body: alert.body,
      );
    }
  }

  /// Alarmas exactas si el sistema lo permite; si no, inexactas (Android puede
  /// retrasarlas unos minutos en reposo).
  static Future<AndroidScheduleMode> _scheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
