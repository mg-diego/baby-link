import 'package:app/features/events/providers/events_provider.dart';

class VisualClockLogic {
  static String formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String dayNightLabel(bool isDayMode, DateTime selectedDate) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];

    if (isDayMode) {
      return 'Día de ${selectedDate.day} ${months[selectedDate.month - 1]}';
    } else {
      return 'Noche a ${selectedDate.day} ${months[selectedDate.month - 1]}';
    }
  }

  static SleepPrediction? getBedtimePrediction(List<SleepPrediction>? predictions) {
    if (predictions == null) return null;
    for (final p in predictions) {
      if (p.isBedtime) return p;
    }
    return null;
  }

  static List<SleepPrediction> getNapPredictions(
      List<SleepPrediction>? predictions, List<Map<String, dynamic>> events) {
    final preds = predictions?.where((p) => p.isNap && p.end != null).toList() ?? [];
    final realNapsCount = events.where((e) => e['category'] == 'nap').length;

    return preds.where((p) {
      if (p.index != null) {
        return p.index! > realNapsCount;
      }
      return true;
    }).toList();
  }

  static ({DateTime start, DateTime end}) computeRange({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> yesterdayEvents,
    // Eventos del día siguiente: la noche que empieza hoy termina mañana
    List<Map<String, dynamic>> tomorrowEvents = const [],
    required DateTime selectedDate,
    required bool isDayMode,
    required bool? forceNightMode,
    DateTime? biologicalCycleEnd,
    List<SleepPrediction>? sleepPrediction,
    // Despertar previsto por la API (solo se usa si la noche no tiene woke_up)
    DateTime? predictedWake,
  }) {
    final todayAsc = List<Map<String, dynamic>>.from(events)
      ..sort((a, b) => a['start_time'].compareTo(b['start_time']));

    final allEventsDesc = [...yesterdayEvents, ...events]
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    final d = selectedDate;

    if (isDayMode) {
      DateTime? wokeUp, bedTime;
      for (var e in todayAsc) {
        if (e['category'] == 'woke_up' && wokeUp == null) {
          wokeUp = DateTime.parse(e['start_time']).toLocal();
        }
        if (e['category'] == 'bed_time' && bedTime == null) {
          bedTime = DateTime.parse(e['start_time']).toLocal();
        }
      }

      if (forceNightMode != null && wokeUp == null && events.isNotEmpty) {
        wokeUp = DateTime.parse(events.first['start_time']).toLocal();
      }

      final predictedBedtime = getBedtimePrediction(sleepPrediction)?.start;
      final fallback = predictedBedtime ?? DateTime(d.year, d.month, d.day, 20, 30);
      final start = wokeUp ?? DateTime(d.year, d.month, d.day, 7, 0);
      var end = biologicalCycleEnd ?? bedTime ?? fallback;
      if (end.isBefore(start)) end = fallback;
      return (start: start, end: end);
    } else {
      DateTime? bedTime, woke;

      for (var e in allEventsDesc) {
        if (e['category'] == 'bed_time') {
          bedTime = DateTime.parse(e['start_time']).toLocal();
          break;
        }
      }

      final start = bedTime ?? DateTime(d.year, d.month, d.day - 1, 20, 30);

      // La noche acaba en el primer despertar posterior a acostarse, que puede
      // ser ya del día siguiente (si se acostó hoy, se despierta mañana).
      final candidatesAsc = [...events, ...tomorrowEvents]
        ..sort((a, b) => a['start_time'].compareTo(b['start_time']));
      for (var e in candidatesAsc) {
        if (e['category'] != 'woke_up') continue;
        final t = DateTime.parse(e['start_time']).toLocal();
        if (t.isAfter(start)) {
          woke = t;
          break;
        }
      }

      // Sin despertar registrado (la noche está en curso): el fin estimado del
      // ciclo (inicio) o el despertar previsto. No se usa una hora fija: al pasar
      // la medianoche cambia la fecha de referencia y el final saltaría.
      final estimate = biologicalCycleEnd ?? predictedWake;
      final estimateFits = estimate != null &&
          estimate.isAfter(start) &&
          estimate.difference(start) <= const Duration(hours: 16);

      final end = woke ??
          (estimateFits ? estimate : start.add(const Duration(hours: 11, minutes: 30)));

      return (start: start, end: end);
    }
  }

  static double getDayDarkness() {
    final h = DateTime.now().hour + DateTime.now().minute / 60.0;
    if (h < 16.5) return 0.0;
    if (h > 18.5) return 1.0;
    return ((h - 16.5) / 2.0).clamp(0.0, 1.0);
  }
}