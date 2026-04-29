import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedStatCategoryProvider = StateProvider<String>((ref) => 'Sueño');
final selectedStatSubCategoryProvider = StateProvider<String?>((ref) => 'Todo');

class StatsCategorySelector extends ConsumerWidget {
  const StatsCategorySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mainCategory = ref.watch(selectedStatCategoryProvider);
    final subCategory = ref.watch(selectedStatSubCategoryProvider);

    final categories = [
      {'name': 'Crecimiento', 'icon': Icons.show_chart},
      {'name': 'Sueño', 'icon': Icons.nights_stay_outlined},
      {'name': 'Alimentación', 'icon': Icons.local_dining_outlined},
      {'name': 'Pañales', 'icon': Icons.baby_changing_station},
    ];

    final sleepSubcategories = [
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: categories.map((cat) {
              final isSelected = mainCategory == cat['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat['name'] as String),
                  avatar: Icon(
                    cat['icon'] as IconData,
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(selectedStatCategoryProvider.notifier).state =
                          cat['name'] as String;
                      if (cat['name'] == 'Sueño') {
                        ref.read(selectedStatSubCategoryProvider.notifier).state =
                            'Todo';
                      } else {
                        ref.read(selectedStatSubCategoryProvider.notifier).state =
                            null;
                      }
                    }
                  },
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: mainCategory == 'Sueño'
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: sleepSubcategories.map((sub) {
                      final isSelected = (subCategory ?? 'Todo') == sub;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            sub,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref
                                .read(selectedStatSubCategoryProvider.notifier)
                                .state = sub;
                          },
                          backgroundColor: Colors.transparent,
                          selectedColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}