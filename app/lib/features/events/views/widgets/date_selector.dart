import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/events_provider.dart';

class DateSelector extends ConsumerStatefulWidget {
  final String babyId;
  const DateSelector({super.key, required this.babyId});

  @override
  ConsumerState<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends ConsumerState<DateSelector> {
  late PageController _pageController;
  final int _baseIndex = 10000;

  @override
  void initState() {
    super.initState();
    final selectedDate = ref.read(selectedDateProvider);
    _pageController = PageController(
      initialPage: _baseIndex - _weeksAgo(selectedDate),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _weeksAgo(DateTime date) {
    final today = DateTime.now();
    final currentMonday = DateTime.utc(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final dateMonday = DateTime.utc(
      date.year,
      date.month,
      date.day - (date.weekday - 1),
    );
    final int diffInDays = currentMonday.difference(dateMonday).inDays;
    return diffInDays ~/ 7;
  }

  String _label(DateTime selectedDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (selected == todayDate) return 'Hoy';
    if (selected == todayDate.subtract(const Duration(days: 1))) return 'Ayer';

    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${selected.day} ${months[selected.month - 1]} ${selected.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final todayDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final primaryColor = Theme.of(context).colorScheme.primary;

    final validDatesAsync = ref.watch(validEventDatesProvider(widget.babyId));
    final Set<DateTime> validDates =
        validDatesAsync.asData?.value ?? {todayDate};

    DateTime minimumDate = DateTime(2023);
    if (validDates.isNotEmpty) {
      minimumDate = validDates.reduce((a, b) => a.isBefore(b) ? a : b);
    }

    final safeSelectedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (safeSelectedDate.isBefore(minimumDate)) {
      minimumDate = safeSelectedDate;
    }

    final targetPage = _baseIndex - _weeksAgo(selectedDate);
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    const dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: minimumDate,
              lastDate: todayDate,
              helpText: 'SELECCIONA UNA FECHA',
              cancelText: 'CANCELAR',
              confirmText: 'ACEPTAR',
              selectableDayPredicate: (DateTime day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return validDates.contains(normalizedDay) ||
                    normalizedDay == todayDate;
              },
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      onSurface: Colors.black87,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              ref.read(selectedDateProvider.notifier).state = date;
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 75,
          child: PageView.builder(
            controller: _pageController,
            itemBuilder: (context, index) {
              final weeksAgo = _baseIndex - index;
              final currentMonday = DateTime(
                todayDate.year,
                todayDate.month,
                todayDate.day - (todayDate.weekday - 1),
              );
              final weekMonday = DateTime(
                currentMonday.year,
                currentMonday.month,
                currentMonday.day - (weeksAgo * 7),
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (dayIndex) {
                  final date = DateTime(
                    weekMonday.year,
                    weekMonday.month,
                    weekMonday.day + dayIndex,
                  );
                  final normalizedDate = DateTime(
                    date.year,
                    date.month,
                    date.day,
                  );

                  final isFuture = normalizedDate.isAfter(todayDate);
                  final isSelected = normalizedDate.isAtSameMomentAs(
                    DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                    ),
                  );
                  final isToday = normalizedDate.isAtSameMomentAs(todayDate);
                  final bool hasEvents = validDates.any(
                    (d) =>
                        d.year == normalizedDate.year &&
                        d.month == normalizedDate.month &&
                        d.day == normalizedDate.day,
                  );

                  final isSelectable = hasEvents || isToday;
                  final isDisabled = isFuture || !isSelectable;

                  return GestureDetector(
                    onTap: isDisabled ? null : () => ref.read(selectedDateProvider.notifier).state = date,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayNames[dayIndex],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSelected
                                ? Border.all(color: primaryColor, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDisabled
                                        ? Colors.grey.withOpacity(
                                            0.4,
                                          ) // <-- Aquí aplicamos el gris si no hay eventos
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: hasEvents && !isFuture
                                ? (isSelected
                                      ? Colors.white.withOpacity(0.8)
                                      : primaryColor)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
