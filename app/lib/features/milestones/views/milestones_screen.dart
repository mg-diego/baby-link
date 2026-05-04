import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/milestones_provider.dart';
import '../services/milestone_service.dart';
import 'widgets/polaroid_card.dart';
import 'widgets/milestone_creation_sheet.dart';
import 'widgets/slideshow_view.dart';
import 'package:app/features/babies/providers/baby_provider.dart';

class MilestonesScreen extends ConsumerStatefulWidget {
  final String babyId;
  const MilestonesScreen({super.key, required this.babyId});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(milestonesProvider.notifier).load(widget.babyId));
  }

  void _openCreation(DateTime babyDob) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MilestoneCreationSheet(
        babyId: widget.babyId,
        babyDob: babyDob,
        onCreated: (m) =>
            ref.read(milestonesProvider.notifier).add(m),
      ),
    );
  }

  void _openSlideshow(List<Milestone> milestones, DateTime babyDob) {
    if (milestones.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => SlideshowView(
          milestones: milestones,
          babyDob: babyDob,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F1222) : const Color(0xFFFAFBFF);
    final textPri =
        isDark ? const Color(0xFFE8EAF6) : const Color(0xFF2D3142);
    final textSec =
        isDark ? const Color(0xFF7986CB) : const Color(0xFF546E7A);

    final milestonesAsync = ref.watch(milestonesProvider);
    final babyAsync = ref.watch(babyProvider);

    final babyDob = babyAsync.asData?.value?['dob'] != null
        ? DateTime.parse(babyAsync.asData!.value!['dob'])
        : DateTime.now().subtract(const Duration(days: 180));

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ───────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: bgColor,
            floating: true,
            pinned: false,
            elevation: 0,
            title: Text(
              'Recuerdos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPri,
              ),
            ),
            actions: [
              milestonesAsync.when(
                data: (list) => list.isEmpty
                    ? const SizedBox()
                    : IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90D9).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.slideshow_rounded,
                              color: Color(0xFF4A90D9), size: 18),
                        ),
                        onPressed: () => _openSlideshow(list, babyDob),
                      ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Content ──────────────────────────────────────────────────
          milestonesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4A90D9), strokeWidth: 2.5),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e',
                    style: TextStyle(color: textSec)),
              ),
            ),
            data: (milestones) {
              if (milestones.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    isDark: isDark,
                    onTap: () => _openCreation(babyDob),
                  ),
                );
              }

              // Agrupar por mes
              final groups = _groupByMonth(milestones);
              final keys = groups.keys.toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, groupIndex) {
                    final key = keys[groupIndex];
                    final items = groups[key]!;
                    final monthLabel = _monthLabel(key, babyDob);

                    return _MonthGroup(
                      label: monthLabel,
                      milestones: items,
                      babyDob: babyDob,
                      isDark: isDark,
                      textSec: textSec,
                      onDelete: (id) =>
                          ref.read(milestonesProvider.notifier).remove(id),
                    );
                  },
                  childCount: keys.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ── FAB ────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreation(babyDob),
        backgroundColor: const Color(0xFF4A90D9),
        elevation: 4,
        child: const Icon(Icons.add_photo_alternate_rounded,
            color: Colors.white, size: 26),
      ),
    );
  }

  Map<String, List<Milestone>> _groupByMonth(List<Milestone> milestones) {
    final Map<String, List<Milestone>> result = {};
    for (final m in milestones) {
      final key =
          '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
      result.putIfAbsent(key, () => []).add(m);
    }
    return result;
  }

  String _monthLabel(String key, DateTime babyDob) {
    const months = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre',
    ];
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthDate = DateTime(year, month);
    int ageMonths = (monthDate.year - babyDob.year) * 12 +
        monthDate.month - babyDob.month;
    if (ageMonths < 0) ageMonths = 0;

    final ageStr = ageMonths == 0
        ? 'Recién nacido'
        : ageMonths < 12
            ? '${ageMonths == 1 ? '1 mes' : '$ageMonths meses'}'
            : '${ageMonths ~/ 12} ${ageMonths ~/ 12 == 1 ? 'año' : 'años'}';

    return '${months[month - 1]} $year · $ageStr';
  }
}

// ─── Month group ───────────────────────────────────────────────────────────────

class _MonthGroup extends StatelessWidget {
  final String label;
  final List<Milestone> milestones;
  final DateTime babyDob;
  final bool isDark;
  final Color textSec;
  final void Function(String) onDelete;

  const _MonthGroup({
    required this.label,
    required this.milestones,
    required this.babyDob,
    required this.isDark,
    required this.textSec,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Separador de mes ─────────────────────────────────────────
        _MonthSeparator(label: label, isDark: isDark),

        // ── Items alternados izq/der ──────────────────────────────────
        ...List.generate(milestones.length, (i) {
          final m = milestones[i];
          final isLeft = i.isEven;
          return _TimelineRow(
            milestone: m,
            babyDob: babyDob,
            isLeft: isLeft,
            isDark: isDark,
            isLast: i == milestones.length - 1,
            onDelete: () => onDelete(m.id),
          );
        }),
      ],
    );
  }
}

// ─── Month separator ───────────────────────────────────────────────────────────

class _MonthSeparator extends StatelessWidget {
  final String label;
  final bool isDark;

  const _MonthSeparator({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.07),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF242746)
                  : const Color(0xFFF0EEFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4A90D9).withOpacity(0.20),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A90D9),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.07),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline row ──────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final Milestone milestone;
  final DateTime babyDob;
  final bool isLeft, isDark, isLast;
  final VoidCallback onDelete;

  const _TimelineRow({
    required this.milestone,
    required this.babyDob,
    required this.isLeft,
    required this.isDark,
    required this.isLast,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final threadColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.10);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Izquierda ─────────────────────────────────────────────
          Expanded(
            child: isLeft
                ? GestureDetector(
                    onLongPress: () => _confirmDelete(context),
                    child: PolaroidCard(
                      milestone: milestone,
                      babyDob: babyDob,
                      isLeft: true,
                    ),
                  )
                : const SizedBox(),
          ),

          // ── Cordel central ────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hilo
                Positioned(
                  top: 0,
                  bottom: isLast ? null : 0,
                  child: Container(
                    width: 1.5,
                    height: isLast ? 40 : null,
                    color: threadColor,
                  ),
                ),
                // Nudo / punto
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4A90D9).withOpacity(0.70),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF0F1222)
                          : const Color(0xFFFAFBFF),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Derecha ───────────────────────────────────────────────
          Expanded(
            child: !isLeft
                ? GestureDetector(
                    onLongPress: () => _confirmDelete(context),
                    child: PolaroidCard(
                      milestone: milestone,
                      babyDob: babyDob,
                      isLeft: false,
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recuerdo'),
        content: const Text(
            '¿Seguro que quieres eliminar este hito? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm == true) onDelete();
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _EmptyState({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📷', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              'Aún no hay recuerdos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guarda los primeros hitos de tu bebé para que nunca los olvides.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withOpacity(0.45)
                    : Colors.black.withOpacity(0.40),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90D9).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  '✨ Añadir primer recuerdo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}