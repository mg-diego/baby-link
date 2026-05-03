import 'package:app/core/network/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

typedef DailyEventsArgs = ({String babyId, DateTime date});

final dailyEventsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, DailyEventsArgs>((ref, args) async {
      return await ApiService.getEventsByDateRange(
        args.babyId,
        args.date,
        args.date,
      );
    });

class ActiveEvent {
  final String eventId;
  final DateTime startTime;

  ActiveEvent({required this.eventId, required this.startTime});
}

class SleepPrediction {
  final String type;
  final int? index;
  final DateTime start;
  final DateTime? end;
  final String? note;

  const SleepPrediction({
    required this.type,
    this.index,
    required this.start,
    this.end,
    this.note,
  });

  bool get isNap => type == 'nap';
  bool get isBedtime => type == 'bedtime';
  bool get isWakeUp => type == 'woke_up';

  factory SleepPrediction.fromJson(Map<String, dynamic> json) {
    DateTime parseUtc(String dateStr) {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      return DateTime.parse(dateStr).toLocal();
    }

    return SleepPrediction(
      type: json['type'] as String,
      index: json['index'] as int?,
      start: parseUtc(json['start'] as String),
      end: json['end'] != null ? parseUtc(json['end'] as String) : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': type,
    if (index != null) 'index': index,
    'start_time': start.toIso8601String(),
    if (end != null) 'end_time': end!.toIso8601String(),
    if (note != null) 'metadata': {'notes': note},
  };
}

class ActiveEventNotifier extends StateNotifier<ActiveEvent?> {
  ActiveEventNotifier() : super(null);

  void start(String backendEventId, DateTime startTime) {
    state = ActiveEvent(eventId: backendEventId, startTime: startTime);
  }

  void stop() {
    state = null;
  }
}

final activeNapProvider =
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
      return ActiveEventNotifier();
    });

final activeNightWakingProvider =
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
      return ActiveEventNotifier();
    });

final activeNursingProvider =
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
      return ActiveEventNotifier();
    });

final activePumpingProvider =
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
      return ActiveEventNotifier();
    });

final allActiveEventsProvider = Provider<Map<String, ActiveEvent>>((ref) {
  final activeEvents = <String, ActiveEvent>{};

  final nap = ref.watch(activeNapProvider);
  if (nap != null) activeEvents['nap'] = nap;

  final nightWaking = ref.watch(activeNightWakingProvider);
  if (nightWaking != null) activeEvents['night_waking'] = nightWaking;

  final nursing = ref.watch(activeNursingProvider);
  if (nursing != null) {
    activeEvents['nursing'] = nursing;
    activeEvents['feed'] = nursing;
  }

  final pumping = ref.watch(activePumpingProvider);
  if (pumping != null) activeEvents['pumping'] = pumping;

  return activeEvents;
});

final validEventDatesProvider = FutureProvider.family<Set<DateTime>, String>((
  ref,
  babyId,
) async {
  try {
    final datesStr = await ApiService.getValidEventDates(babyId);

    return datesStr.map((dateStr) {
      final parsed = DateTime.parse(dateStr);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }).toSet();
  } catch (e) {
    print('Error en validEventDatesProvider: $e');
    return <DateTime>{};
  }
});

final sleepPredictionProvider =
    FutureProvider.family<List<SleepPrediction>, String>((ref, babyId) async {
      final raw = await ApiService.getSleepPredictions(babyId);
      return raw
          .cast<Map<String, dynamic>>()
          .map(SleepPrediction.fromJson)
          .toList();
    });

final wakePredictionProvider = FutureProvider.family<SleepPrediction?, String>((
  ref,
  babyId,
) async {
  final rawData = await ApiService.getWakePrediction(babyId);
  if (rawData == null) return null;
  return SleepPrediction.fromJson(rawData);
});

final lastEventsProvider = FutureProvider.family<Map<String, String?>, String>((
  ref,
  babyId,
) async {
  return await ApiService.getLastEvents(babyId);
});
