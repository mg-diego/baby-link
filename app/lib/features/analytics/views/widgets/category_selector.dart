import 'package:app/shared/models/event_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedStatCategoryProvider = StateProvider<String>((ref) => 'Sueño');
final selectedStatSubCategoryProvider = StateProvider<String?>((ref) => 'Todo');

class StatsCategorySelector extends ConsumerWidget {
  const StatsCategorySelector({super.key});

  static const _categories = [
    _Cat('Sueño', Icons.nights_stay_rounded, EventType.nap),
    _Cat('Alimentación', Icons.local_dining_rounded, EventType.bottle),
    _Cat('Pañales', Icons.baby_changing_station_rounded, EventType.diaper),
    _Cat('Crecimiento', Icons.show_chart_rounded, EventType.growth),
  ];

  static const _subCategories = {
    'Sueño': ['Todo', 'Siestas', 'Nocturno', 'Despertares'],
    'Alimentación': ['Todo', 'Biberón', 'Lactancia', 'Sólidos'],
    'Pañales': ['Todo', 'Mojado', 'Sucio'],
    'Crecimiento': ['Peso', 'Altura', 'Perímetro'],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainCategory = ref.watch(selectedStatCategoryProvider);
    final subCategory = ref.watch(selectedStatSubCategoryProvider);
    final subs = _subCategories[mainCategory] ?? [];
    final activeCat = _categories.firstWhere((c) => c.name == mainCategory);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main categories ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: _categories.map((cat) {
              final isSelected = mainCategory == cat.name;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: cat == _categories.last ? 0 : 8,
                  ),
                  child: _CategoryChip(
                    cat: cat,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedStatCategoryProvider.notifier).state =
                          cat.name;
                      final firstSub = _subCategories[cat.name]?.first;
                      ref.read(selectedStatSubCategoryProvider.notifier).state =
                          firstSub;
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Subcategories ─────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          child: subs.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: subs.map((sub) {
                        final isSelected = (subCategory ?? subs.first) == sub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _SubChip(
                            label: sub,
                            isSelected: isSelected,
                            color: activeCat.eventType.getAccentColor(context),
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                      .read(
                                        selectedStatSubCategoryProvider
                                            .notifier,
                                      )
                                      .state =
                                  sub;
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),

        // Separador
        Divider(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.07),
        ),
      ],
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _Cat {
  final String name;
  final IconData icon;
  final EventType eventType;
  const _Cat(this.name, this.icon, this.eventType);
}

// ─── Main category chip ───────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final _Cat cat;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.cat,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? cat.eventType.getAccentColor(context).withOpacity(isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cat.eventType.getAccentColor(context).withOpacity(isDark ? 0.55 : 0.45)
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08)),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              cat.icon,
              size: 20,
              color: isSelected
                  ? cat.eventType.getAccentColor(context)
                  : (isDark
                        ? Colors.white.withOpacity(0.35)
                        : Colors.black.withOpacity(0.30)),
            ),
            const SizedBox(height: 4),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? cat.eventType.getAccentColor(context)
                    : (isDark
                          ? Colors.white.withOpacity(0.40)
                          : Colors.black.withOpacity(0.38)),
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-category chip ────────────────────────────────────────────────────────

class _SubChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? Colors.white.withOpacity(0.45)
                      : Colors.black.withOpacity(0.40)),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
