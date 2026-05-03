import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../events/providers/events_provider.dart';

final selectedDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: now.subtract(const Duration(days: 6)),
    end: now,
  );
});

// Rangos predefinidos para detectar cuál está activo
enum _QuickRange { days7, days30, months3, custom }

_QuickRange _detectQuickRange(DateTimeRange range) {
  final today = DateTime(
    DateTime.now().year, DateTime.now().month, DateTime.now().day,
  );
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end   = DateTime(range.end.year,   range.end.month,   range.end.day);
  if (!end.isAtSameMomentAs(today)) return _QuickRange.custom;
  final diff = today.difference(start).inDays;
  if (diff == 6)  return _QuickRange.days7;
  if (diff == 29) return _QuickRange.days30;
  final threeMonths = DateTime(today.year, today.month - 3, today.day);
  if (start.isAtSameMomentAs(threeMonths)) return _QuickRange.months3;
  return _QuickRange.custom;
}

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
    _pageController = PageController(initialPage: _baseIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedDate  = ref.read(selectedDateProvider);
      final selectedRange = ref.read(selectedDateRangeProvider);
      final targetDate    = widget.isRangeMode ? selectedRange.end : selectedDate;
      _pageController.jumpToPage(_baseIndex - _weeksAgo(targetDate));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _weeksAgo(DateTime date) {
    final today = DateTime.now();
    final currentMonday = DateTime.utc(
      today.year, today.month, today.day - (today.weekday - 1),
    );
    final dateMonday = DateTime.utc(
      date.year, date.month, date.day - (date.weekday - 1),
    );
    return currentMonday.difference(dateMonday).inDays ~/ 7;
  }

  String _label(DateTime date, DateTimeRange range) {
    final todayDate = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day,
    );

    String fmt(DateTime d) {
      final n = DateTime(d.year, d.month, d.day);
      if (n == todayDate) return 'Hoy';
      if (n == todayDate.subtract(const Duration(days: 1))) return 'Ayer';
      const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${n.day} ${m[n.month - 1]}';
    }

    if (widget.isRangeMode) {
      final s = fmt(range.start), e = fmt(range.end);
      return range.start.isAtSameMomentAs(range.end) ? s : '$s – $e';
    }
    return fmt(date);
  }

  void _applyRange(DateTime start, DateTime end) {
    HapticFeedback.selectionClick();
    ref.read(selectedDateRangeProvider.notifier).state =
        DateTimeRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final selectedDate  = ref.watch(selectedDateProvider);
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final primaryColor  = const Color(0xFF4A90D9);
    final todayDate     = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day,
    );

    Set<DateTime> validDates = {};
    if (widget.babyId != null) {
      final async = ref.watch(validEventDatesProvider(widget.babyId!));
      validDates = async.asData?.value ?? {todayDate};
    }

    DateTime minimumDate = DateTime(2023);
    if (validDates.isNotEmpty) {
      minimumDate = validDates.reduce((a, b) => a.isBefore(b) ? a : b);
    }

    final safeSelected = DateTime(
      selectedDate.year, selectedDate.month, selectedDate.day,
    );
    if (safeSelected.isBefore(minimumDate)) minimumDate = safeSelected;

    if (widget.isRangeMode) {
      final safeStart = DateTime(
        selectedRange.start.year, selectedRange.start.month, selectedRange.start.day,
      );
      if (safeStart.isBefore(minimumDate)) minimumDate = safeStart;
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
    final textSecondary = isDark
        ? Colors.white.withOpacity(0.38)
        : Colors.black.withOpacity(0.35);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── Header: label + calendar icon ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRangeMode ? 'Período' : 'Fecha',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _label(selectedDate, selectedRange),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFE8EAF6)
                            : const Color(0xFF2D3142),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              _IconButton(
                icon: Icons.calendar_month_rounded,
                color: primaryColor,
                isDark: isDark,
                onTap: () => _openPicker(
                  context, isDark, primaryColor, todayDate,
                  selectedDate, selectedRange, minimumDate, validDates,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Week strip (solo en modo día único) ──────────────────────────
        if (!widget.isRangeMode)
          SizedBox(
            height: 72,
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

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (dayIndex) {
                      final date = DateTime(
                        weekMonday.year,
                        weekMonday.month,
                        weekMonday.day + dayIndex,
                      );
                      final normalized = DateTime(date.year, date.month, date.day);
                      final isFuture   = normalized.isAfter(todayDate);
                      final isToday    = normalized.isAtSameMomentAs(todayDate);
                      final isSelected = normalized.isAtSameMomentAs(
                        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
                      );
                      final hasEvents = validDates.any((d) =>
                          d.year == normalized.year &&
                          d.month == normalized.month &&
                          d.day == normalized.day);
                      final isDisabled = isFuture ||
                          (widget.babyId != null && !hasEvents && !isToday);

                      return GestureDetector(
                        onTap: isDisabled
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref.read(selectedDateProvider.notifier).state = date;
                              },
                        child: SizedBox(
                          width: 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayNames[dayIndex],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isToday && !isSelected
                                      ? Border.all(
                                          color: primaryColor.withOpacity(0.6),
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : isDisabled
                                            ? textSecondary.withOpacity(0.5)
                                            : isDark
                                                ? const Color(0xFFE8EAF6)
                                                : const Color(0xFF2D3142),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Dot de eventos
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasEvents && !isFuture
                                      ? (isSelected
                                          ? Colors.white.withOpacity(0.80)
                                          : primaryColor.withOpacity(0.70))
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),

        // ── Quick range chips (solo en modo rango) ───────────────────────
        if (widget.isRangeMode) ...[
          const SizedBox(height: 4),
          _QuickRangeChips(
            selectedRange: selectedRange,
            todayDate: todayDate,
            isDark: isDark,
            primaryColor: primaryColor,
            onApply: _applyRange,
          ),
        ],

        const SizedBox(height: 14),
        Divider(
          height: 1,
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.07),
        ),
      ],
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    DateTime todayDate,
    DateTime selectedDate,
    DateTimeRange selectedRange,
    DateTime minimumDate,
    Set<DateTime> validDates,
  ) async {
    final theme = Theme.of(context).copyWith(
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: const Color(0xFF1A1D2E),
              onSurface: const Color(0xFFE8EAF6),
            )
          : ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF2D3142),
            ),
    );

    if (widget.isRangeMode) {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: selectedRange,
        firstDate: DateTime(2020),
        lastDate: todayDate,
        helpText: 'Selecciona un rango',
        cancelText: 'Cancelar',
        confirmText: 'Aceptar',
        builder: (ctx, child) => Theme(data: theme, child: child!),
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
        helpText: 'Selecciona una fecha',
        cancelText: 'Cancelar',
        confirmText: 'Aceptar',
        selectableDayPredicate: (day) {
          if (widget.babyId == null) return true;
          final n = DateTime(day.year, day.month, day.day);
          final today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day,
          );
          return validDates.contains(n) || n.isAtSameMomentAs(today);
        },
        builder: (ctx, child) => Theme(data: theme, child: child!),
      );
      if (date != null) {
        ref.read(selectedDateProvider.notifier).state = date;
      }
    }
  }
}

// ─── Quick range chips ─────────────────────────────────────────────────────────

class _QuickRangeChips extends StatelessWidget {
  final DateTimeRange selectedRange;
  final DateTime todayDate;
  final bool isDark;
  final Color primaryColor;
  final void Function(DateTime start, DateTime end) onApply;

  const _QuickRangeChips({
    required this.selectedRange,
    required this.todayDate,
    required this.isDark,
    required this.primaryColor,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final active = _detectQuickRange(selectedRange);

    final chips = [
      (label: '7 días',  range: _QuickRange.days7,
       start: todayDate.subtract(const Duration(days: 6))),
      (label: '30 días', range: _QuickRange.days30,
       start: todayDate.subtract(const Duration(days: 29))),
      (label: '3 meses', range: _QuickRange.months3,
       start: DateTime(todayDate.year, todayDate.month - 3, todayDate.day)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chips.map((chip) {
          final isSelected = active == chip.range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _QuickChip(
              label: chip.label,
              isSelected: isSelected,
              isDark: isDark,
              color: primaryColor,
              onTap: () => onApply(chip.start, todayDate),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
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
                    ? Colors.white.withOpacity(0.50)
                    : Colors.black.withOpacity(0.45)),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Small icon button ────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? color.withOpacity(0.14)
              : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}