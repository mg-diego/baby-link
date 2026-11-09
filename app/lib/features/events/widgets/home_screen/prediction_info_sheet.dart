import 'package:flutter/material.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/shared/models/event_type.dart';

import 'prediction_explanation.dart';

/// Detalle de una predicción: a qué hora, con qué margen y de dónde sale.
class PredictionInfoSheet extends StatelessWidget {
  final SleepPrediction prediction;

  /// Si se indica, se ofrece marcar la siesta como no hecha.
  final VoidCallback? onSkip;

  const PredictionInfoSheet({super.key, required this.prediction, this.onSkip});

  EventType get _eventType => switch (prediction.type) {
        'nap' => EventType.nap,
        'bedtime' => EventType.bedtime,
        _ => EventType.wokeUp,
      };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final accent = _eventType.getAccentColor(context);
    final info = PredictionExplanation.of(prediction);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(_eventType.icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          if (info.subtitle != null)
                            Text(info.subtitle!, style: TextStyle(fontSize: 13, color: muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  info.time,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
                ),
                if (info.range != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.range!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Así acierta más o menos la mitad de los días. Cuanto más regular es, más estrecho.',
                          style: TextStyle(fontSize: 12, color: muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
                if (info.reasons.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'DE DÓNDE SALE ESTA HORA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: muted),
                  ),
                  const SizedBox(height: 8),
                  for (final reason in info.reasons) _ReasonRow(reason: reason, accent: accent),
                ],
                if (info.footer != null) ...[
                  const SizedBox(height: 16),
                  Text(info.footer!, style: TextStyle(fontSize: 12, color: muted, height: 1.4)),
                ],
                const SizedBox(height: 20),
                if (onSkip != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onSkip!();
                      },
                      icon: const Icon(Icons.do_not_disturb_on_outlined),
                      label: const Text('No ha hecho esta siesta'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
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
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final PredictionReason reason;
  final Color accent;

  const _ReasonRow({required this.reason, required this.accent});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final percent = reason.weightPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(reason.icon, size: 18, color: onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(reason.text, style: TextStyle(fontSize: 14, height: 1.35, color: onSurface.withValues(alpha: 0.85))),
          ),
          if (percent != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(
                '$percent %',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
