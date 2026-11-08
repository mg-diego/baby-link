import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/milestones_provider.dart';
import 'widgets/milestone_creation_sheet.dart';
import 'widgets/milestone_edit_sheet.dart';
import 'widgets/milestone_media.dart';

/// Acciones sobre hitos compartidas por la galería y el detalle.

void showMilestoneCreation(
  BuildContext context, {
  required String babyId,
  required DateTime? babyDob,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MilestoneCreationSheet(babyId: babyId, babyDob: babyDob),
  );
}

void showMilestoneEditor(
  BuildContext context, {
  required Milestone milestone,
  required DateTime? babyDob,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MilestoneEditSheet(milestone: milestone, babyDob: babyDob),
  );
}

/// Pide confirmación y elimina el hito (de forma optimista).
///
/// [onConfirmed] se ejecuta justo después de confirmar y antes de borrar, p. ej.
/// para cerrar la pantalla de detalle sin esperar a la red.
Future<void> deleteMilestoneWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Milestone milestone, {
  VoidCallback? onConfirmed,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('¿Eliminar recuerdo?'),
      content: Text('"${milestone.title}" se eliminará de forma permanente.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(d).colorScheme.error,
          ),
          child: const Text(
            'Eliminar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Se capturan antes de [onConfirmed]: puede desmontar el widget que llama.
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(milestonesProvider(milestone.babyId).notifier);
  onConfirmed?.call();

  try {
    await notifier.delete(milestone.id);
    messenger.showSnackBar(const SnackBar(content: Text('Recuerdo eliminado')));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo eliminar el recuerdo')),
    );
  }
}

/// Menú contextual (pulsación larga) con las acciones de un hito.
void showMilestoneQuickActions(
  BuildContext context,
  WidgetRef ref, {
  required Milestone milestone,
  required DateTime? babyDob,
}) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      final cs = Theme.of(sheetCtx).colorScheme;

      void run(VoidCallback action) {
        Navigator.pop(sheetCtx);
        action();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                milestone.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  sheetCtx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (milestone.hasMedia)
              ListTile(
                leading: Icon(
                  milestone.isVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.fullscreen_rounded,
                  color: cs.primary,
                ),
                title: Text(
                  milestone.isVideo ? 'Ver vídeo' : 'Ver a pantalla completa',
                ),
                onTap: () =>
                    run(() => openMilestoneMediaViewer(context, milestone)),
              ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: cs.secondary),
              title: const Text('Editar'),
              onTap: () => run(
                () => showMilestoneEditor(
                  context,
                  milestone: milestone,
                  babyDob: babyDob,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: Text('Eliminar', style: TextStyle(color: cs.error)),
              onTap: () => run(
                () => deleteMilestoneWithConfirmation(context, ref, milestone),
              ),
            ),
          ],
        ),
      );
    },
  );
}
