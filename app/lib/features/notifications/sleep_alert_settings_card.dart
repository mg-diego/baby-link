import 'package:app/features/notifications/sleep_alert_service.dart';
import 'package:app/features/notifications/sleep_alert_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ajustes de los avisos previos a siestas y a la hora de dormir.
class SleepAlertSettingsCard extends ConsumerWidget {
  const SleepAlertSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sleepAlertSettingsProvider);
    final settings = async.asData?.value;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final notifier = ref.read(sleepAlertSettingsProvider.notifier);

    /// Al activar un aviso se pide el permiso de notificaciones; si se
    /// deniega, el interruptor no se enciende.
    Future<void> toggle(bool on, SleepAlertSettings Function() apply) async {
      if (on && !await SleepAlertService.requestPermission()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activa las notificaciones de BabyLink en los ajustes del móvil'),
          ));
        }
        return;
      }
      await notifier.save(apply());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _AlertRow(
            icon: Icons.wb_sunny_outlined,
            title: 'Antes de cada siesta',
            enabled: settings.napsEnabled,
            lead: settings.napLeadMinutes,
            onToggle: (on) => toggle(on, () => settings.copyWith(napsEnabled: on)),
            onLead: (m) => notifier.save(settings.copyWith(napLeadMinutes: m)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _AlertRow(
            icon: Icons.bedtime_outlined,
            title: 'Antes de dormir',
            enabled: settings.bedtimeEnabled,
            lead: settings.bedtimeLeadMinutes,
            onToggle: (on) => toggle(on, () => settings.copyWith(bedtimeEnabled: on)),
            onLead: (m) => notifier.save(settings.copyWith(bedtimeLeadMinutes: m)),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final int lead;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onLead;

  const _AlertRow({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.lead,
    required this.onToggle,
    required this.onLead,
  });

  @override
  Widget build(BuildContext context) {
    final options = {...SleepAlertSettings.leadOptions, lead}.toList()..sort();
    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(enabled ? 'Aviso $lead min antes de la hora prevista' : 'Desactivado'),
          value: enabled,
          onChanged: onToggle,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in options)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: m == lead,
                    onSelected: (_) => onLead(m),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
