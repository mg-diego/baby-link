import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'milestone_media.dart';

const _frameRadius = BorderRadius.all(Radius.circular(4));

/// Recuerdo en formato polaroid para la cuadrícula de la galería.
///
/// El marco es siempre blanco (como una foto impresa), también en modo oscuro.
class PolaroidCard extends StatelessWidget {
  final Milestone milestone;
  final DateTime? babyDob;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PolaroidCard({
    super.key,
    required this.milestone,
    required this.babyDob,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final dateLabel = DateFormat('d MMM y', 'es').format(milestone.date);
    final ageLabel = babyDob != null ? milestone.ageLabel(babyDob!) : null;

    return Semantics(
      button: true,
      label: [milestone.title, dateLabel, ?ageLabel].join(', '),
      excludeSemantics: true,
      child: Transform.rotate(
        angle: milestone.tilt,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _frameRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 14,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: _frameRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Hero(
                          tag: milestone.heroTag,
                          child: LayoutBuilder(
                            builder: (_, c) => MilestoneThumbnail(
                              milestone: milestone,
                              memCacheWidth: (c.maxWidth * dpr).round(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                      child: Column(
                        children: [
                          Text(
                            milestone.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.caveat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D2D2D),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ageLabel ?? dateLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A90D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador de carga con la misma silueta que [PolaroidCard].
class PolaroidSkeleton extends StatelessWidget {
  final Animation<double> pulse;

  const PolaroidSkeleton({super.key, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frame = isDark ? const Color(0xFF1A1D2E) : Colors.white;
    final fill = isDark ? const Color(0xFF242746) : const Color(0xFFF0EEFF);

    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );

    return FadeTransition(
      opacity: pulse,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(color: frame, borderRadius: _frameRadius),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            bar(0.7, 12),
            const SizedBox(height: 8),
            bar(0.4, 8),
          ],
        ),
      ),
    );
  }
}
