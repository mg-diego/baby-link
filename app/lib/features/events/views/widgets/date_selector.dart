import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../providers/events_provider.dart';

final selectedDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: now.subtract(const Duration(days: 6)),
    end: now,
  );
});

class DateSelector extends ConsumerStatefulWidget {
  final String? babyId;
  final bool isRangeMode;

  const DateSelector({
    super.key,
    this.babyId,
    this.isRangeMode = false,
  });

  @override
  ConsumerState<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends ConsumerState<DateSelector> {
  late PageController _pageController;
  final int _baseIndex = 10000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedDate = ref.read(selectedDateProvider);
      final selectedRange = ref.read(selectedDateRangeProvider);
      final targetDate = widget.isRangeMode ? selectedRange.end : selectedDate;
      _pageController.jumpToPage(_baseIndex - _weeksAgo(targetDate));
    });
    _pageController = PageController(initialPage: _baseIndex);
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

  String _label(DateTime date, DateTimeRange range) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    String format(DateTime d) {
      final selected = DateTime(d.year, d.month, d.day);
      if (selected == todayDate) return 'Hoy';
      if (selected == todayDate.subtract(const Duration(days: 1))) {
        return 'Ayer';
      }
      const months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${selected.day} ${months[selected.month - 1]} ${selected.year}';
    }

    if (widget.isRangeMode) {
      final startStr = format(range.start);
      final endStr = format(range.end);
      if (range.start.isAtSameMomentAs(range.end)) return startStr;
      return '$startStr - $endStr';
    }

    return format(date);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedRange = ref.watch(selectedDateRangeProvider);

    final todayDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final primaryColor = Theme.of(context).colorScheme.primary;

    Set<DateTime> validDates = {};
    if (widget.babyId != null) {
      final validDatesAsync = ref.watch(validEventDatesProvider(widget.babyId!));
      validDates = validDatesAsync.asData?.value ?? {todayDate};
    }

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

    if (widget.isRangeMode) {
      final safeStartRange = DateTime(
        selectedRange.start.year,
        selectedRange.start.month,
        selectedRange.start.day,
      );
      if (safeStartRange.isBefore(minimumDate)) {
        minimumDate = safeStartRange;
      }
    }

    final targetDate = widget.isRangeMode ? selectedRange.end : selectedDate;
    final targetPage = _baseIndex - _weeksAgo(targetDate);

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
            if (widget.isRangeMode) {
              final range = await showDateRangePicker(
                context: context,
                initialDateRange: selectedRange,
                firstDate: DateTime(2020),
                lastDate: todayDate,
                helpText: 'SELECCIONA UN RANGO',
                cancelText: 'CANCELAR',
                confirmText: 'ACEPTAR',
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
              if (range != null) {
                ref.read(selectedDateRangeProvider.notifier).state = range;
              }
            } else {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: widget.babyId == null ? DateTime(2020) : minimumDate,
                lastDate: todayDate,
                helpText: 'SELECCIONA UNA FECHA',
                cancelText: 'CANCELAR',
                confirmText: 'ACEPTAR',
                selectableDayPredicate: (DateTime day) {
                  if (widget.babyId == null) return true;
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
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(selectedDate, selectedRange),
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
        if (!widget.isRangeMode) SizedBox(
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
                  final isToday = normalizedDate.isAtSameMomentAs(todayDate);

                  final isSelected = widget.isRangeMode
                      ? (normalizedDate.isAtSameMomentAs(DateTime(
                              selectedRange.start.year,
                              selectedRange.start.month,
                              selectedRange.start.day)) ||
                          normalizedDate.isAtSameMomentAs(DateTime(
                              selectedRange.end.year,
                              selectedRange.end.month,
                              selectedRange.end.day)))
                      : normalizedDate.isAtSameMomentAs(DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day));

                  final isInRange = widget.isRangeMode
                      ? (normalizedDate.isAfter(DateTime(
                              selectedRange.start.year,
                              selectedRange.start.month,
                              selectedRange.start.day)) &&
                          normalizedDate.isBefore(DateTime(
                              selectedRange.end.year,
                              selectedRange.end.month,
                              selectedRange.end.day)))
                      : false;

                  final bool hasEvents = validDates.any(
                    (d) =>
                        d.year == normalizedDate.year &&
                        d.month == normalizedDate.month &&
                        d.day == normalizedDate.day,
                  );

                  final isSelectable =
                      widget.babyId == null || widget.isRangeMode || hasEvents || isToday;
                  final isDisabled = isFuture || !isSelectable;

                  return GestureDetector(
                    onTap: isDisabled
                        ? null
                        : () {
                            if (widget.isRangeMode) {
                              ref
                                  .read(selectedDateRangeProvider.notifier)
                                  .state = DateTimeRange(
                                start: date,
                                end: date,
                              );
                            } else {
                              ref.read(selectedDateProvider.notifier).state =
                                  date;
                            }
                          },
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
                                : (isInRange
                                    ? primaryColor.withOpacity(0.15)
                                    : Colors.transparent),
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
                                      ? Colors.grey.withOpacity(0.4)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface),
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
        if (widget.isRangeMode) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickChip(context, '7 días', todayDate.subtract(const Duration(days: 6)), todayDate),
                _buildQuickChip(context, '30 días', todayDate.subtract(const Duration(days: 29)), todayDate),
                _buildQuickChip(context, '3 meses', DateTime(todayDate.year, todayDate.month - 3, todayDate.day), todayDate),
                _buildQuickChip(context, '6 meses', DateTime(todayDate.year, todayDate.month - 6, todayDate.day), todayDate),
                _buildQuickChip(context, 'Todo', minimumDate, todayDate),
              ],
            ),
          ),
        ],
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildQuickChip(BuildContext context, String label, DateTime start, DateTime end) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        onPressed: () {
          ref.read(selectedDateRangeProvider.notifier).state = DateTimeRange(
            start: start,
            end: end,
          );
        },
      ),
    );
  }
}