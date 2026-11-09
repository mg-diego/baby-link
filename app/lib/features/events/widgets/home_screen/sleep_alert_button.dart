import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/notifications/sleep_alert_settings.dart';
import 'package:app/features/notifications/sleep_alerts_sheet.dart';

import 'home_header.dart';

/// Botón de la cabecera de Inicio para los avisos de sueño.
///
/// - Desactivados: campana vacía.
/// - Activados con un aviso pendiente: campana + hora del próximo aviso.
/// - Activados sin avisos pendientes (p. ej. de noche): campana activa.
///
/// Al pulsarlo se abren los ajustes de avisos.
class SleepAlertButton extends ConsumerStatefulWidget {
  final String babyId;
  final bool isNightMode;
  final Color dayTextPrimary;
  final Color dayTextSecondary;

  const SleepAlertButton({
    super.key,
    required this.babyId,
    required this.isNightMode,
    required this.dayTextPrimary,
    required this.dayTextSecondary,
  });

  @override
  ConsumerState<SleepAlertButton> createState() => _SleepAlertButtonState();
}

class _SleepAlertButtonState extends ConsumerState<SleepAlertButton> {
  Timer? _timer;
  DateTime? _timerTarget;

  /// Cuando suena el aviso mostrado hay que pasar al siguiente, aunque nada
  /// más en la pantalla haya cambiado.
  void _scheduleRefresh(DateTime? fireAt) {
    if (fireAt == _timerTarget) return;
    _timer?.cancel();
    _timerTarget = fireAt;
    if (fireAt == null) return;
    final delay = fireAt.difference(DateTime.now()) + const Duration(seconds: 1);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) setState(() => _timerTarget = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(sleepAlertSettingsProvider).asData?.value.anyEnabled ?? false;
    final next = nextSleepAlert(ref, widget.babyId);
    _scheduleRefresh(next?.fireAt);

    final night = widget.isNightMode;
    final textPri = night ? Colors.white : widget.dayTextPrimary;
    final textSec =
        night ? Colors.white.withValues(alpha: 0.65) : widget.dayTextSecondary;
    final iconColor = enabled
        ? (night ? Colors.white.withValues(alpha: 0.90) : widget.dayTextPrimary)
        : (night
            ? Colors.white.withValues(alpha: 0.70)
            : widget.dayTextPrimary.withValues(alpha: 0.70));

    final icon = Icon(
      enabled
          ? Icons.notifications_active_rounded
          : Icons.notifications_none_rounded,
      size: 22,
      color: iconColor,
    );

    final label = !enabled
        ? 'Avisos de sueño desactivados'
        : next == null
            ? 'Avisos de sueño activados, sin avisos pendientes'
            : 'Próximo aviso a las ${formatAlertTime(next.fireAt)}';

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => showSleepAlertsSheet(context, widget.babyId),
        behavior: HitTestBehavior.opaque,
        child: HeaderGlass(
          isNightMode: night,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: next == null
                ? Center(child: icon)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatAlertTime(next.fireAt),
                              style: TextStyle(
                                color: textPri,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              'Aviso',
                              style: TextStyle(
                                color: textSec,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
