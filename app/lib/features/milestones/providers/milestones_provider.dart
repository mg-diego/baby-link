import 'dart:async';

import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/milestone_service.dart';

final milestoneServiceProvider = Provider<MilestoneService>(
  (ref) => MilestoneService(),
);

/// Fecha de nacimiento del bebé activo, si se conoce.
final babyDobProvider = Provider<DateTime?>((ref) {
  final dob = ref.watch(babyProvider).value?['dob'] as String?;
  return dob != null ? DateTime.tryParse(dob) : null;
});

/// Hitos de un bebé en orden cronológico (más antiguo primero).
///
/// No es autoDispose: la lista se conserva al cambiar de pestaña, de modo que
/// volver a "Recuerdos" pinta los datos al instante en lugar de recargar.
final milestonesProvider =
    AsyncNotifierProvider.family<MilestonesNotifier, List<Milestone>, String>(
      MilestonesNotifier.new,
    );

class MilestonesNotifier extends AsyncNotifier<List<Milestone>> {
  MilestonesNotifier(this.babyId);

  final String babyId;

  MilestoneService get _service => ref.read(milestoneServiceProvider);

  /// Vídeos para los que ya se intentó generar miniatura en esta sesión.
  final _thumbnailAttempted = <String>{};

  @override
  Future<List<Milestone>> build() async {
    final list = await ref.watch(milestoneServiceProvider).fetchAll(babyId);
    final missing = [
      for (final m in list)
        if (m.isVideo &&
            m.thumbnailUrl == null &&
            _thumbnailAttempted.add(m.id))
          m,
    ];
    if (missing.isNotEmpty) unawaited(_backfillThumbnails(missing));
    return list;
  }

  /// Vídeos subidos antes de existir las miniaturas: se les genera una en
  /// segundo plano, de uno en uno, y se actualiza la lista según llegan.
  Future<void> _backfillThumbnails(List<Milestone> videos) async {
    try {
      await future; // que el build haya fijado ya la lista en el estado
    } catch (_) {
      return;
    }
    for (final m in videos) {
      try {
        final updated = await _service.ensureThumbnail(m);
        if (!ref.mounted) return;
        if (updated.thumbnailUrl != null) {
          _setList([
            for (final x in _current) x.id == updated.id ? updated : x,
          ]);
        }
      } catch (e) {
        debugPrint('[milestones] Miniatura de ${m.id} no generada: $e');
      }
    }
  }

  Future<Milestone> create(
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async {
    final created = await _service.create(
      babyId,
      input,
      onProgress: onProgress,
    );
    _setList([..._current, created]);
    return created;
  }

  Future<Milestone> edit(
    Milestone original,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async {
    final updated = await _service.update(
      original,
      input,
      onProgress: onProgress,
    );
    _setList([for (final m in _current) m.id == updated.id ? updated : m]);
    return updated;
  }

  /// Borrado optimista: si falla el servidor, se restaura la lista y se
  /// relanza el error para que la UI lo comunique.
  Future<void> delete(String id) async {
    final previous = _current;
    final target = previous.where((m) => m.id == id).firstOrNull;
    if (target == null) return;
    _setList(previous.where((m) => m.id != id).toList());
    try {
      await _service.delete(target);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  List<Milestone> get _current => state.value ?? const [];

  void _setList(List<Milestone> list) {
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });
    state = AsyncData(list);
  }
}
