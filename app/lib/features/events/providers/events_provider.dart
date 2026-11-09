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

  /// Siesta corta de rescate (no cabe una normal antes de la noche).
  final bool isCatnap;

  /// Bloque opaco que devuelve la API (corrección aplicada, siesta corta,
  /// retrasada...). Se guarda tal cual en el evento real para que el backend
  /// pueda medir el error de sus predicciones.
  final Map<String, dynamic>? feedback;

  /// Intervalo en el que es más probable que empiece (≈ 50 % de las veces). Se
  /// calcula con lo regular que es el bebé: cuanto más irregular, más ancho.
  final DateTime? earliest;
  final DateTime? latest;

  /// Ya debería haber empezado: `start` es "ahora" y la hora calculada quedó atrás.
  final bool overdue;

  /// De dónde sale la hora (ventana habitual, rutina, horas de noche...). Lo
  /// interpreta `PredictionExplanation`; null en respuestas antiguas de la API.
  final Map<String, dynamic>? basis;

  const SleepPrediction({
    required this.type,
    this.index,
    required this.start,
    this.end,
    this.note,
    this.isCatnap = false,
    this.feedback,
    this.earliest,
    this.latest,
    this.overdue = false,
    this.basis,
  });

  bool get isNap => type == 'nap';
  bool get isBedtime => type == 'bedtime';
  bool get isWakeUp => type == 'woke_up';

  /// "entre 9:20 y 9:50", o null si la API no envía margen.
  String? get rangeLabel {
    if (earliest == null || latest == null) return null;
    String hm(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    final from = hm(earliest!), to = hm(latest!);
    return from == to ? null : 'entre $from y $to';
  }

  factory SleepPrediction.fromJson(Map<String, dynamic> json) {
    DateTime parseUtc(String dateStr) {
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      return DateTime.parse(dateStr).toLocal();
    }

    final range = json['start_range'];
    return SleepPrediction(
      type: json['type'] as String,
      index: json['index'] as int?,
      start: parseUtc(json['start'] as String),
      end: json['end'] != null ? parseUtc(json['end'] as String) : null,
      note: json['note'] as String?,
      isCatnap: json['is_catnap'] == true,
      feedback: json['predicted_feedback'] is Map
          ? Map<String, dynamic>.from(json['predicted_feedback'] as Map)
          : null,
      earliest: range is Map && range['earliest'] is String ? parseUtc(range['earliest'] as String) : null,
      latest: range is Map && range['latest'] is String ? parseUtc(range['latest'] as String) : null,
      overdue: json['overdue'] == true,
      basis: json['basis'] is Map ? Map<String, dynamic>.from(json['basis'] as Map) : null,
    );
  }

  /// Metadatos `predicted_*` que se guardan al registrar el evento real.
  /// (El formulario de edición conserva las claves `predicted_*` y `nap_index`.)
  Map<String, dynamic> toPredictionMetadata() => {
    'predicted_start_time': start.toUtc().toIso8601String(),
    if (end != null) 'predicted_end_time': end!.toUtc().toIso8601String(),
    if (index != null) 'nap_index': index,
    if (feedback != null) 'predicted_feedback': feedback,
  };

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

typedef Predictions = ({List<SleepPrediction> schedule, SleepPrediction? wake});

/// Una sola llamada a la API para la agenda y el despertar. Para refrescar las
/// predicciones basta con invalidar este provider.
final predictionsProvider = FutureProvider.family<Predictions, String>((ref, babyId) async {
  final raw = await ApiService.getPredictions(babyId);
  return (
    schedule: raw.schedule.cast<Map<String, dynamic>>().map(SleepPrediction.fromJson).toList(),
    wake: raw.wake == null ? null : SleepPrediction.fromJson(raw.wake!),
  );
});

final sleepPredictionProvider = FutureProvider.family<List<SleepPrediction>, String>(
  (ref, babyId) async => (await ref.watch(predictionsProvider(babyId).future)).schedule,
);

final wakePredictionProvider = FutureProvider.family<SleepPrediction?, String>(
  (ref, babyId) async => (await ref.watch(predictionsProvider(babyId).future)).wake,
);

final lastEventsProvider = FutureProvider.family<Map<String, String?>, String>((
  ref,
  babyId,
) async {
  return await ApiService.getLastEvents(babyId);
});


final growthHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, babyId) async {
      return await ApiService.getGrowthHistory(babyId);
    });
