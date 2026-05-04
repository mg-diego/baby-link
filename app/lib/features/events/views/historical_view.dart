import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/widgets/date_selector.dart';
import 'package:app/features/events/widgets/historical_view/event_list_view.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_view.dart';

class HistoricalView extends ConsumerStatefulWidget {
  final String babyId;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>, {bool stopNow}) onTap;

  const HistoricalView({
    super.key,
    required this.babyId,
    required this.onBack,
    required this.onRefresh,
    required this.onDelete,
    required this.onTap,
  });

  @override
  ConsumerState<HistoricalView> createState() => _HistoricalViewState();
}

class _HistoricalViewState extends ConsumerState<HistoricalView>
    with SingleTickerProviderStateMixin {
  int _viewMode = 0;
  late AnimationController _segmentController;

  @override
  void initState() {
    super.initState();
    _segmentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _segmentController.dispose();
    super.dispose();
  }

  String _calculateAge(DateTime dob, [DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    int years = ref.year - dob.year;
    int months = ref.month - dob.month;
    int days = ref.day - dob.day;
    if (days < 0) {
      months--;
      days += DateTime(ref.year, ref.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    String _y(int n) => n == 1 ? '1 año' : '$n años';
    String _m(int n) => n == 1 ? '1 mes' : '$n meses';
    String _d(int n) => n == 1 ? '1 día' : '$n días';

    if (years > 0) {
      if (months > 0 && days > 0)
        return '${_y(years)}, ${_m(months)}, ${_d(days)}';
      if (months > 0) return '${_y(years)}, ${_m(months)}';
      if (days > 0) return '${_y(years)}, ${_d(days)}';
      return _y(years);
    }
    if (months > 0) {
      if (days > 0) return '${_m(months)}, ${_d(days)}';
      return _m(months);
    }
    return _d(days);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(selectedDateProvider);
    final args = (babyId: widget.babyId, date: selectedDate);
    final argsYday = (
      babyId: widget.babyId,
      date: selectedDate.subtract(const Duration(days: 1)),
    );

    final eventsAsync = ref.watch(dailyEventsProvider(args));
    final eventsYdayAsync = ref.watch(dailyEventsProvider(argsYday));
    final sleepPredAsync = ref.watch(sleepPredictionProvider(widget.babyId));
    final wakePredAsync = ref.watch(wakePredictionProvider(widget.babyId));
    final babyAsync = ref.watch(babyProvider);

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isToday = selectedDate == today;

    final bgColor = isDark ? const Color(0xFF0F1222) : const Color(0xFFFAFBFF);
    final surfColor = isDark ? const Color(0xFF1A1D2E) : Colors.white;
    final textPri = isDark ? const Color(0xFFE8EAF6) : const Color(0xFF2D3142);
    final textSec = isDark ? const Color(0xFF7986CB) : const Color(0xFF546E7A);
    const primary = Color(0xFF4A90D9);

    return Scaffold(
      backgroundColor: bgColor,

      // ── AppBar custom ──────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _HistoricalAppBar(
          babyAsync: babyAsync,
          isDark: isDark,
          surfColor: surfColor,
          textPri: textPri,
          textSec: textSec,
          primary: primary,
          selectedDate: selectedDate,
          calculateAge: _calculateAge,
          onBack: widget.onBack,
        ),
      ),

      body: Column(
        children: [
          // ── Date selector ────────────────────────────────────────────────
          DateSelector(babyId: widget.babyId),

          // ── View toggle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _ViewToggle(
              viewMode: _viewMode,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _viewMode = v),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 2.5,
                ),
              ),
              error: (err, _) => _ErrorState(message: '$err', isDark: isDark),
              data: (events) {
                final yesterdayEvents = eventsYdayAsync.asData?.value ?? [];
                if (_viewMode == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: VisualClockView(
                      key: ValueKey('clock_${events.hashCode}'),
                      events: List<Map<String, dynamic>>.from(events),
                      yesterdayEvents: List<Map<String, dynamic>>.from(
                        yesterdayEvents,
                      ),
                      selectedDate: selectedDate,
                      sleepPrediction: sleepPredAsync.asData?.value,
                      wakePrediction: wakePredAsync.asData?.value,
                      isLearning: sleepPredAsync.asData?.value == null,
                      alignment: Alignment.topCenter,
                    ),
                  );
                }
                return EventListView(
                  key: ValueKey('list_${events.hashCode}'),
                  initialEvents: List<Map<String, dynamic>>.from(events),
                  yesterdayEvents: List<Map<String, dynamic>>.from(
                    yesterdayEvents,
                  ),
                  isToday: isToday,
                  onRefresh: widget.onRefresh,
                  onDelete: widget.onDelete,
                  onTap: widget.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ────────────────────────────────────────────────────────────────────

class _HistoricalAppBar extends StatelessWidget {
  final AsyncValue babyAsync;
  final bool isDark;
  final Color surfColor, textPri, textSec, primary;
  final DateTime selectedDate;
  final String Function(DateTime, DateTime?) calculateAge;
  final VoidCallback onBack;

  const _HistoricalAppBar({
    required this.babyAsync,
    required this.isDark,
    required this.surfColor,
    required this.textPri,
    required this.textSec,
    required this.primary,
    required this.selectedDate,
    required this.calculateAge,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                // Back
                _NavIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  isDark: isDark,
                  primary: primary,
                  onTap: onBack,
                ),

                const SizedBox(width: 12),

                // Baby info
                Expanded(
                  child: babyAsync.when(
                    data: (baby) {
                      if (baby == null) {
                        return Text(
                          'Histórico',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPri,
                          ),
                        );
                      }
                      final dob = DateTime.parse(baby['dob']);
                      final initial = (baby['name'] as String).isNotEmpty
                          ? (baby['name'] as String)[0].toUpperCase()
                          : 'B';
                      return Row(
                        children: [
                          // Avatar
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(isDark ? 0.18 : 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primary.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                baby['name'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textPri,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                calculateAge(dob, selectedDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSec,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const CupertinoActivityIndicator(),
                    error: (_, __) => Text(
                      'Histórico',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final int viewMode;
  final bool isDark;
  final Color primary;
  final ValueChanged<int> onChanged;

  const _ViewToggle({
    required this.viewMode,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Reloj',
            icon: Icons.av_timer_rounded,
            isSelected: viewMode == 0,
            isDark: isDark,
            primary: primary,
            onTap: () => onChanged(0),
          ),
          _ToggleTab(
            label: 'Lista',
            icon: Icons.format_list_bulleted_rounded,
            isSelected: viewMode == 1,
            isDark: isDark,
            primary: primary,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected, isDark;
  final Color primary;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1A1D2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? primary
                    : (isDark
                          ? Colors.white.withOpacity(0.35)
                          : Colors.black.withOpacity(0.35)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? primary
                      : (isDark
                            ? Colors.white.withOpacity(0.40)
                            : Colors.black.withOpacity(0.40)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav icon button ──────────────────────────────────────────────────────────

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? primary.withOpacity(0.12) : primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: primary),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorState({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: isDark
                  ? Colors.white.withOpacity(0.20)
                  : Colors.black.withOpacity(0.18),
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF6)
                    : const Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withOpacity(0.35)
                    : Colors.black.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
