import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/shared/widgets/custom_top_bar.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
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

class _HistoricalViewState extends ConsumerState<HistoricalView> {
  int _viewMode = 0;

  String _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      final previousMonth = DateTime(now.year, now.month, 0);
      days += previousMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final yStr = years == 1 ? '1 año' : '$years años';
    final mStr = months == 1 ? '1 mes' : '$months meses';
    final dStr = days == 1 ? '1 día' : '$days días';

    if (years > 0) return '$yStr, $mStr, $dStr';
    if (months > 0) return '$mStr, $dStr';
    return dStr;
  }

  Widget _buildSegmentContent(int index, String text, IconData icon) {
    final isSelected = _viewMode == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final args = (babyId: widget.babyId, date: selectedDate);
    final argsYday = (
      babyId: widget.babyId,
      date: selectedDate.subtract(const Duration(days: 1)),
    );

    final eventsAsync = ref.watch(dailyEventsProvider(args));
    final eventsYdayAsync = ref.watch(dailyEventsProvider(argsYday));
    final sleepPredictionAsync = ref.watch(sleepPredictionProvider(widget.babyId));
    final wakePredictionAsync = ref.watch(wakePredictionProvider(widget.babyId));
    final babyAsync = ref.watch(babyProvider);

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isToday = selectedDate == today;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: CustomTopBar(
        centerContent: babyAsync.when(
          data: (baby) {
            if (baby == null) {
              return const Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20));
            }
            final dob = DateTime.parse(baby['dob']);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(
                    baby['name'].isNotEmpty ? baby['name'][0].toUpperCase() : 'B',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(baby['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.1)),
                    Text(
                      _calculateAge(dob),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), height: 1.1),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const CupertinoActivityIndicator(),
          error: (_, __) => const Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualizar', onPressed: widget.onRefresh),
        ],
      ),
      body: Column(
        children: [
          DateSelector(babyId: widget.babyId),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _viewMode,
                thumbColor: primaryColor,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                padding: const EdgeInsets.all(4),
                children: {
                  0: _buildSegmentContent(0, 'Reloj', Icons.av_timer_rounded),
                  1: _buildSegmentContent(1, 'Lista', Icons.format_list_bulleted_rounded),
                },
                onValueChanged: (int? value) {
                  if (value != null) setState(() => _viewMode = value);
                },
              ),
            ),
          ),
          if (_viewMode == 1) const Divider(height: 1),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final yesterdayEvents = eventsYdayAsync.asData?.value ?? [];
                if (_viewMode == 0) {
                  return VisualClockView(
                    key: ValueKey('clock_${events.hashCode}'),
                    events: List<Map<String, dynamic>>.from(events),
                    yesterdayEvents: List<Map<String, dynamic>>.from(yesterdayEvents),
                    selectedDate: selectedDate,
                    sleepPrediction: sleepPredictionAsync.asData?.value,
                    wakePrediction: wakePredictionAsync.asData?.value,
                    isLearning: sleepPredictionAsync.asData?.value == null,
                  );
                }
                return EventListView(
                  key: ValueKey('list_${events.hashCode}'),
                  initialEvents: List<Map<String, dynamic>>.from(events),
                  yesterdayEvents: List<Map<String, dynamic>>.from(yesterdayEvents),
                  isToday: isToday,
                  onRefresh: widget.onRefresh,
                  onDelete: widget.onDelete,
                  onTap: widget.onTap,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}