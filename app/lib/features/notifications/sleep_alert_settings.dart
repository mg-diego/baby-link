import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de los avisos de sueño. Se guardan en el dispositivo (no en
/// Supabase): las notificaciones son locales, así que la configuración también.
class SleepAlertSettings {
  final bool napsEnabled;
  final int napLeadMinutes;
  final bool bedtimeEnabled;
  final int bedtimeLeadMinutes;

  const SleepAlertSettings({
    this.napsEnabled = false,
    this.napLeadMinutes = 15,
    this.bedtimeEnabled = false,
    this.bedtimeLeadMinutes = 30,
  });

  /// Opciones de antelación que ofrece la pantalla de ajustes.
  static const leadOptions = [10, 15, 20, 30, 45, 60];

  bool get anyEnabled => napsEnabled || bedtimeEnabled;

  SleepAlertSettings copyWith({
    bool? napsEnabled,
    int? napLeadMinutes,
    bool? bedtimeEnabled,
    int? bedtimeLeadMinutes,
  }) => SleepAlertSettings(
    napsEnabled: napsEnabled ?? this.napsEnabled,
    napLeadMinutes: napLeadMinutes ?? this.napLeadMinutes,
    bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
    bedtimeLeadMinutes: bedtimeLeadMinutes ?? this.bedtimeLeadMinutes,
  );

  static const _kNaps = 'sleep_alerts.naps_enabled';
  static const _kNapLead = 'sleep_alerts.nap_lead_min';
  static const _kBed = 'sleep_alerts.bedtime_enabled';
  static const _kBedLead = 'sleep_alerts.bedtime_lead_min';

  /// Lee las preferencias. Usa [SharedPreferencesAsync] (sin caché) para que el
  /// isolate del widget en segundo plano vea siempre lo último que guardó la app.
  static Future<SleepAlertSettings> load() async {
    const d = SleepAlertSettings();
    try {
      final prefs = SharedPreferencesAsync();
      return SleepAlertSettings(
        napsEnabled: await prefs.getBool(_kNaps) ?? d.napsEnabled,
        napLeadMinutes: await prefs.getInt(_kNapLead) ?? d.napLeadMinutes,
        bedtimeEnabled: await prefs.getBool(_kBed) ?? d.bedtimeEnabled,
        bedtimeLeadMinutes: await prefs.getInt(_kBedLead) ?? d.bedtimeLeadMinutes,
      );
    } catch (_) {
      return d;
    }
  }

  Future<void> save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kNaps, napsEnabled);
    await prefs.setInt(_kNapLead, napLeadMinutes);
    await prefs.setBool(_kBed, bedtimeEnabled);
    await prefs.setInt(_kBedLead, bedtimeLeadMinutes);
  }
}

class SleepAlertSettingsNotifier extends AsyncNotifier<SleepAlertSettings> {
  @override
  Future<SleepAlertSettings> build() => SleepAlertSettings.load();

  Future<void> save(SleepAlertSettings settings) async {
    state = AsyncData(settings);
    await settings.save();
  }
}

final sleepAlertSettingsProvider =
    AsyncNotifierProvider<SleepAlertSettingsNotifier, SleepAlertSettings>(
      SleepAlertSettingsNotifier.new,
    );
