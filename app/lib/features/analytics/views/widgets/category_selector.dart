import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedStatCategoryProvider = StateProvider<String>((ref) => 'Sueño');
final selectedStatSubCategoryProvider = StateProvider<String?>((ref) => 'Todo');

class StatsCategorySelector extends ConsumerWidget {
  const StatsCategorySelector({super.key});

  Color _getCategoryColor(String name) {
    switch (name) {
      case 'Sueño':
        return const Color(0xFF5C6BC0);
      case 'Crecimiento':
        return const Color(0xFF4DB6AC);
      case 'Alimentación':
        return const Color(0xFFFFB74D);
      case 'Pañales':
        return const Color(0xFF4FC3F7);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mainCategory = ref.watch(selectedStatCategoryProvider);
    final subCategory = ref.watch(selectedStatSubCategoryProvider);

    final categories = [
      {'name': 'Sueño', 'icon': Icons.nights_stay_rounded},
      {'name': 'Crecimiento', 'icon': Icons.show_chart_rounded},
      {'name': 'Alimentación', 'icon': Icons.local_dining_rounded},
      {'name': 'Pañales', 'icon': Icons.baby_changing_station_rounded},
    ];

    final sleepSubcategories = [
      'Todo',
      'Siestas',
      'Sueño Nocturno',
      'Despertares Nocturnos',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              final name = cat['name'] as String;
              final icon = cat['icon'] as IconData;
              final isSelected = mainCategory == name;
              final catColor = _getCategoryColor(name);

              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: GestureDetector(
                  onTap: () {
                    ref.read(selectedStatCategoryProvider.notifier).state = name;
                    if (name == 'Sueño') {
                      ref.read(selectedStatSubCategoryProvider.notifier).state = 'Todo';
                    } else {
                      ref.read(selectedStatSubCategoryProvider.notifier).state = null;
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? catColor : catColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? catColor : catColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: catColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isSelected ? Colors.white : catColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: mainCategory == 'Sueño'
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: sleepSubcategories.map((sub) {
                      final isSelected = (subCategory ?? 'Todo') == sub;
                      final activeColor = _getCategoryColor('Sueño');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedStatSubCategoryProvider.notifier).state = sub;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? activeColor
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              sub,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? activeColor
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}