import 'dart:math' as math;
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/milestones_provider.dart';
import 'milestone_actions.dart';
import 'widgets/milestone_media.dart';

/// Detalle de un recuerdo: foto grande, toda su información y acciones visibles.
class MilestoneDetailScreen extends ConsumerWidget {
  /// Versión con la que se abrió; se usa hasta que el provider la sustituye
  /// (p. ej. tras editarla).
  final Milestone initial;

  const MilestoneDetailScreen({super.key, required this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestone =
        ref.watch(
          milestonesProvider(initial.babyId).select(
            (s) => s.value?.where((m) => m.id == initial.id).firstOrNull,
          ),
        ) ??
        initial;
    final dob = ref.watch(babyDobProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1222) : const Color(0xFFFAFBFF);
    final size = MediaQuery.sizeOf(context);
    final cat = catFor(milestone.category);

    final headerHeight = milestone.hasMedia
        ? math.min(size.width, size.height * 0.55)
        : 220.0;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: headerHeight,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _OverlayButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Volver',
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              _OverlayButton(
                icon: Icons.edit_rounded,
                tooltip: 'Editar',
                onTap: () => showMilestoneEditor(
                  context,
                  milestone: milestone,
                  babyDob: dob,
                ),
              ),
              const SizedBox(width: 8),
              _OverlayButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                onTap: () => deleteMilestoneWithConfirmation(
                  context,
                  ref,
                  milestone,
                  onConfirmed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Semantics(
                button: milestone.hasMedia,
                label: milestone.hasMedia
                    ? (milestone.isVideo
                          ? 'Reproducir vídeo'
                          : 'Ver foto a pantalla completa')
                    : null,
                child: GestureDetector(
                  onTap: milestone.hasMedia
                      ? () => openMilestoneMediaViewer(context, milestone)
                      : null,
                  child: Hero(
                    tag: milestone.heroTag,
                    child: MilestoneThumbnail(
                      milestone: milestone,
                      emojiSize: 96,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryChip(label: '${cat.emoji} ${cat.label}'),
                  const SizedBox(height: 14),
                  Text(
                    milestone.title,
                    style: GoogleFonts.caveat(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    text: _capitalize(
                      DateFormat(
                        "EEEE, d 'de' MMMM 'de' y",
                        'es',
                      ).format(milestone.date),
                    ),
                  ),
                  if (dob != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.child_care_rounded,
                      text: 'Tenía ${milestone.ageLabel(dob)}',
                      emphasized: true,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (milestone.description?.trim().isNotEmpty ?? false)
                    Text(
                      milestone.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.85),
                        height: 1.55,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => showMilestoneEditor(
                        context,
                        milestone: milestone,
                        babyDob: dob,
                      ),
                      icon: const Icon(Icons.notes_rounded, size: 18),
                      label: const Text('Añadir una nota a este recuerdo'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasized;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = emphasized ? cs.primary : cs.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
