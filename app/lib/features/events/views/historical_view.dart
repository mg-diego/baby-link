import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/babies/views/widgets/baby_avatar.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/widgets/date_selector.dart';
import 'package:app/features/events/widgets/historical_view/event_list_view.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_view.dart';

class HistoricalView extends ConsumerStatefulWidget {
  final String babyId;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>, {bool stopNow}) onTap;

  const HistoricalView({
    super.key,
    required this.babyId,
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
    // La noche del día seleccionado termina al día siguiente (salvo si es hoy)
    final now = DateTime.now();
    final tomorrow = DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1);
    final tomorrowAsync = tomorrow.isAfter(now)
        ? null
        : ref.watch(dailyEventsProvider((babyId: widget.babyId, date: tomorrow)));
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

    // Espacio que ocupa el menú flotante inferior (navbar de MainScreen), para
    // que el contenido no quede tapado por él (MainScreen usa extendBody).
    final bottomReserve = MediaQuery.paddingOf(context).bottom + 88;

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
                    padding: EdgeInsets.only(top: 16, bottom: bottomReserve),
                    child: VisualClockView(
                      key: ValueKey('clock_${events.hashCode}'),
                      events: List<Map<String, dynamic>>.from(events),
                      yesterdayEvents: List<Map<String, dynamic>>.from(
                        yesterdayEvents,
                      ),
                      tomorrowEvents: List<Map<String, dynamic>>.from(
                        tomorrowAsync?.asData?.value ?? const [],
                      ),
                      selectedDate: selectedDate,
                      sleepPrediction: sleepPredAsync.asData?.value,
                      wakePrediction: wakePredAsync.asData?.value,
                      isLearning: sleepPredAsync.asData?.value == null,
                      alignment: Alignment.center,
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
                  bottomPadding: bottomReserve,
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

/// Cabecera de la pestaña Histórico: título + edad del bebé en la fecha
/// seleccionada, con su avatar a la derecha.
class _HistoricalAppBar extends StatelessWidget {
  final AsyncValue babyAsync;
  final bool isDark;
  final Color surfColor, textPri, textSec, primary;
  final DateTime selectedDate;
  final String Function(DateTime, DateTime?) calculateAge;

  const _HistoricalAppBar({
    required this.babyAsync,
    required this.isDark,
    required this.surfColor,
    required this.textPri,
    required this.textSec,
    required this.primary,
    required this.selectedDate,
    required this.calculateAge,
  });

  @override
  Widget build(BuildContext context) {
    final baby = babyAsync.asData?.value as Map<String, dynamic>?;
    final name = (baby?['name'] as String?) ?? '';
    final dobStr = baby?['dob'] as String?;
    final dob = dobStr != null ? DateTime.tryParse(dobStr) : null;
    final subtitle = [
      if (name.isNotEmpty) name,
      if (dob != null) calculateAge(dob, selectedDate),
    ].join(' · ');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Histórico',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                          height: 1.1,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSec,
                              height: 1.1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (babyAsync.isLoading)
                  const CupertinoActivityIndicator()
                else if (baby != null)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: BabyAvatar(
                      photoUrl: baby['photo_url'] as String?,
                      size: 38,
                      backgroundColor: primary.withOpacity(isDark ? 0.18 : 0.12),
                      fallback: Text(
                        initial,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
