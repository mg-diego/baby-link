import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/milestones_provider.dart';
import 'milestone_actions.dart';
import 'milestone_detail_screen.dart';
import 'widgets/polaroid_card.dart';
import 'widgets/slideshow_view.dart';

const _gridPadding = EdgeInsets.fromLTRB(20, 4, 20, 24);
const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 220, // 2 columnas en móvil, más en tablet
  mainAxisSpacing: 20,
  crossAxisSpacing: 16,
  childAspectRatio: 0.74,
);

/// Galería de recuerdos agrupada por mes (más recientes primero).
class MilestonesScreen extends ConsumerStatefulWidget {
  final String babyId;
  const MilestonesScreen({super.key, required this.babyId});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  /// Categoría filtrada; `null` = todas.
  String? _category;

  Future<void> _refresh() async {
    try {
      final provider = milestonesProvider(widget.babyId);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron actualizar los recuerdos'),
        ),
      );
    }
  }

  void _openDetail(Milestone m) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MilestoneDetailScreen(initial: m)),
    );
  }

  void _openSlideshow(List<Milestone> chronological, DateTime? dob) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) =>
            SlideshowView(milestones: chronological, babyDob: dob),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1222) : const Color(0xFFFAFBFF);

    final async = ref.watch(milestonesProvider(widget.babyId));
    final dob = ref.watch(babyDobProvider);
    // Con extendBody en MainScreen, este padding incluye la barra flotante.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Se usan los datos previos aunque haya un refresco o error en curso.
    final all = async.value;

    final presentCategories = [
      for (final c in kMilestoneCategories)
        if (all?.any((m) => m.category == c.key) ?? false) c,
    ];
    final filter = presentCategories.any((c) => c.key == _category)
        ? _category
        : null;
    final visible = filter == null
        ? all
        : all?.where((m) => m.category == filter).toList();

    void openCreation() =>
        showMilestoneCreation(context, babyId: widget.babyId, babyDob: dob);

    final List<Widget> content;
    if (all == null) {
      content = async.hasError
          ? [
              _MessageState(
                bottomInset: bottomInset,
                emoji: '😕',
                title: 'No se pudieron cargar los recuerdos',
                message: 'Revisa tu conexión e inténtalo de nuevo.',
                actionLabel: 'Reintentar',
                actionIcon: Icons.refresh_rounded,
                onAction: () =>
                    ref.invalidate(milestonesProvider(widget.babyId)),
              ),
            ]
          : const [_SkeletonGallery()];
    } else if (all.isEmpty) {
      content = [
        _MessageState(
          bottomInset: bottomInset,
          emoji: '📷',
          title: 'Aún no hay recuerdos',
          message:
              'Guarda la primera sonrisa, el primer baño o sus primeros '
              'pasos para que nunca se te olviden.',
          actionLabel: 'Añadir primer recuerdo',
          actionIcon: Icons.add_photo_alternate_rounded,
          onAction: openCreation,
        ),
      ];
    } else {
      content = [
        SliverToBoxAdapter(
          child: _FilterBar(
            count: visible!.length,
            categories: presentCategories,
            selected: filter,
            onSelected: (key) => setState(() => _category = key),
          ),
        ),
        for (final section in _groupByMonth(visible.reversed))
          _MonthSection(
            section: section,
            babyDob: dob,
            background: bg,
            onTap: _openDetail,
            onLongPress: (m) => showMilestoneQuickActions(
              context,
              ref,
              milestone: m,
              babyDob: dob,
            ),
          ),
      ];
    }

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              titleSpacing: 20,
              title: const Text(
                'Recuerdos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              actions: [
                if (visible != null && visible.isNotEmpty)
                  IconButton(
                    tooltip: 'Ver presentación',
                    icon: const Icon(Icons.slideshow_rounded),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _openSlideshow(visible, dob),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 16),
                  child: FilledButton.tonalIcon(
                    onPressed: openCreation,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Añadir'),
                  ),
                ),
              ],
            ),
            ...content,
            if (all == null || all.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        ),
      ),
    );
  }
}

// ─── Agrupación por mes ────────────────────────────────────────────────────────

class _MonthGroup {
  final DateTime month;
  final List<Milestone> items;
  _MonthGroup(this.month, this.items);
}

/// Agrupa respetando el orden de entrada (los hitos llegan ya ordenados).
List<_MonthGroup> _groupByMonth(Iterable<Milestone> milestones) {
  final groups = <_MonthGroup>[];
  for (final m in milestones) {
    final month = DateTime(m.date.year, m.date.month);
    if (groups.isEmpty || groups.last.month != month) {
      groups.add(_MonthGroup(month, []));
    }
    groups.last.items.add(m);
  }
  return groups;
}

String? _monthAgeLabel(DateTime month, DateTime? dob) {
  if (dob == null) return null;
  final months = (month.year - dob.year) * 12 + month.month - dob.month;
  if (months < 0) return null;
  if (months == 0) return 'Recién nacido';
  if (months < 12) return months == 1 ? '1 mes' : '$months meses';
  final y = months ~/ 12;
  final m = months % 12;
  final years = y == 1 ? '1 año' : '$y años';
  return m == 0 ? years : '$years y ${m == 1 ? '1 mes' : '$m meses'}';
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─── Sección de un mes ─────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final _MonthGroup section;
  final DateTime? babyDob;
  final Color background;
  final ValueChanged<Milestone> onTap;
  final ValueChanged<Milestone> onLongPress;

  const _MonthSection({
    required this.section,
    required this.babyDob,
    required this.background,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final items = section.items;
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _MonthHeaderDelegate(
            label: _capitalize(
              DateFormat('MMMM y', 'es').format(section.month),
            ),
            age: _monthAgeLabel(section.month, babyDob),
            background: background,
          ),
        ),
        SliverPadding(
          padding: _gridPadding,
          sliver: SliverGrid.builder(
            gridDelegate: _gridDelegate,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final m = items[i];
              return PolaroidCard(
                key: ValueKey(m.id),
                milestone: m,
                babyDob: babyDob,
                onTap: () => onTap(m),
                onLongPress: () => onLongPress(m),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const _height = 48.0;

  final String label;
  final String? age;
  final Color background;

  const _MonthHeaderDelegate({
    required this.label,
    required this.age,
    required this.background,
  });

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      foregroundDecoration: overlaps
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
              ),
            )
          : null,
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          if (age != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                age!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) =>
      label != old.label || age != old.age || background != old.background;
}

// ─── Contador + filtros ───────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int count;
  final List<MilestoneCat> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterBar({
    required this.count,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            count == 1 ? '1 recuerdo' : '$count recuerdos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        // Filtrar solo tiene sentido con más de una categoría.
        if (categories.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _chip(context, label: 'Todos', key: null),
                for (final c in categories)
                  _chip(context, label: '${c.emoji} ${c.label}', key: c.key),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _chip(BuildContext context, {required String label, String? key}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == key,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onSelected(key),
      ),
    );
  }
}

// ─── Estados de carga / vacío / error ─────────────────────────────────────────

class _SkeletonGallery extends StatefulWidget {
  const _SkeletonGallery();

  @override
  State<_SkeletonGallery> createState() => _SkeletonGalleryState();
}

class _SkeletonGalleryState extends State<_SkeletonGallery>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween(
    begin: 0.45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF242746)
        : const Color(0xFFF0EEFF);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Semantics(
            label: 'Cargando recuerdos',
            child: FadeTransition(
              opacity: _pulse,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 140,
                    height: 16,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: _gridPadding,
          sliver: SliverGrid.builder(
            gridDelegate: _gridDelegate,
            itemCount: 6,
            itemBuilder: (_, _) => PolaroidSkeleton(pulse: _pulse),
          ),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final double bottomInset;
  final String emoji, title, message, actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _MessageState({
    required this.bottomInset,
    required this.emoji,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        // Centrado en el área visible, no detrás de la barra de navegación.
        padding: EdgeInsets.fromLTRB(40, 24, 40, bottomInset + 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(emoji, style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
