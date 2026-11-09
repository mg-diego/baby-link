import 'package:flutter/material.dart';

import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/widgets/visual_clock/visual_clock_logic.dart';

/// Un motivo de la predicción. `weight` (0-1) es cuánto pesa en la hora final
/// cuando se mezclan varios criterios (hora de dormir y despertar).
class PredictionReason {
  final IconData icon;
  final String text;
  final double? weight;

  const PredictionReason(this.icon, this.text, {this.weight});

  int? get weightPercent => weight == null ? null : (weight! * 100).round();
}

/// Texto de la hoja que se abre al tocar una predicción. Se construye solo a
/// partir de lo que devuelve la API (`basis`), sin lógica de predicción propia.
class PredictionExplanation {
  final String title;
  final String time;
  final String? subtitle; // "Hoy · en 1 h 20 min", "Mañana", "Ya es la hora"
  final String? range;
  final List<PredictionReason> reasons;
  final String? footer;

  const PredictionExplanation({
    required this.title,
    required this.time,
    this.subtitle,
    this.range,
    this.reasons = const [],
    this.footer,
  });

  /// Pesos por debajo de esto no se mencionan: apenas mueven la hora.
  static const double minWeight = 0.1;

  /// Correcciones por feedback por debajo de esto no se mencionan.
  static const int minCorrection = 5;

  factory PredictionExplanation.of(SleepPrediction p, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final b = p.basis ?? const {};
    final reasons = switch (p.type) {
      'nap' => _napReasons(p, b),
      'bedtime' => _bedReasons(b),
      _ => _wakeReasons(b),
    };
    return PredictionExplanation(
      title: _title(p, b),
      time: p.isNap && p.end != null ? '${_hm(p.start)} – ${_hm(p.end!)}' : _hm(p.start),
      subtitle: _subtitle(p, at),
      range: p.earliest != null && p.latest != null && p.earliest != p.latest
          ? 'Lo más probable: entre ${_hm(p.earliest!)} y ${_hm(p.latest!)}'
          : null,
      reasons: reasons,
      footer: _footer(b),
    );
  }

  // ─── Cabecera ──────────────────────────────────────────────────────────────

  static String _title(SleepPrediction p, Map<String, dynamic> b) {
    if (p.isBedtime) return 'Hora de dormir prevista';
    if (p.isWakeUp) return 'Despertar previsto';
    if (b['rescue'] == true) return 'Siesta corta extra';
    final count = _int(b['nap_count']);
    if (p.index == null) return 'Siesta prevista';
    return count != null && count > 1 ? 'Siesta ${p.index} de $count' : 'Siesta ${p.index}';
  }

  static String? _subtitle(SleepPrediction p, DateTime now) {
    if (p.overdue || !p.start.isAfter(now)) {
      return p.isWakeUp ? 'Ya debería estar despierto' : 'Ya es la hora';
    }
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(p.start.year, p.start.month, p.start.day);
    final diff = day.difference(today).inDays;
    final dayLabel = diff == 0 ? 'Hoy' : diff == 1 ? 'Mañana' : null;
    final mins = p.start.difference(now).inMinutes;
    final inLabel = mins < 1 ? 'ahora' : 'en ${_duration(mins)}';
    if (mins > 12 * 60) return dayLabel;
    return dayLabel == null ? inLabel : '$dayLabel · $inLabel';
  }

  static String? _footer(Map<String, dynamic> b) {
    final days = _int(b['days']);
    if (days == null || days == 0) return null;
    final base = days == 1
        ? 'Calculado con 1 día de registros.'
        : 'Calculado con sus últimos $days días de registros.';
    final caution = days < 7 ? ' Con pocos días aún es aproximado: se afina con cada registro.' : '';
    return '$base$caution';
  }

  // ─── Siesta ────────────────────────────────────────────────────────────────

  static List<PredictionReason> _napReasons(SleepPrediction p, Map<String, dynamic> b) {
    final out = <PredictionReason>[];
    final from = _time(b['from_time']);
    if (from != null) out.add(_fromReason(b['from'], from, b['from_predicted'] == true));

    final usual = _int(b['usual_window_min']);
    if (usual != null) {
      final which = p.index == 1 ? 'Por la mañana' : 'Antes de esta siesta';
      out.add(PredictionReason(Icons.hourglass_bottom_rounded,
          '$which suele aguantar ${_duration(usual)} despierto'));
    }
    final shortened = _int(b['shortened_min']) ?? 0;
    if (shortened >= minCorrection) {
      out.add(PredictionReason(Icons.trending_down_rounded,
          'Hoy se adelanta ${_duration(shortened)}: ha dormido menos de lo habitual en las siestas'));
    }
    _addCorrection(out, b, 'se dormía');

    final duration = _int(b['duration_min']);
    if (b['rescue'] == true) {
      out.add(const PredictionReason(Icons.bolt_rounded,
          'Hoy ha dormido poco: sin una siesta corta la noche llegaría demasiado pronto'));
    } else if (p.isCatnap) {
      out.add(const PredictionReason(Icons.bolt_rounded,
          'Siesta corta: una completa retrasaría demasiado la hora de dormir'));
    } else if (duration != null) {
      out.add(PredictionReason(Icons.bedtime_outlined, 'Suele dormir ${_duration(duration)} en esta siesta'));
    }
    return out;
  }

  // ─── Hora de dormir ────────────────────────────────────────────────────────

  static List<PredictionReason> _bedReasons(Map<String, dynamic> b) {
    final out = <PredictionReason>[];
    final routineW = _double(b['routine_weight']) ?? 0;
    final dayW = _double(b['day_length_weight']) ?? 0;
    final windowW = (1 - routineW - dayW).clamp(0.0, 1.0);
    final mixed = routineW >= minWeight || dayW >= minWeight;

    final from = _time(b['from_time']);
    if (from != null) out.add(_fromReason(b['from'], from, b['from_predicted'] == true));

    final window = _int(b['usual_window_min']);
    final byWindow = _time(b['by_window']);
    if (window != null && windowW >= minWeight) {
      final since = b['from'] == 'wake' ? 'Desde que se despierta' : 'Después de la última siesta';
      final result = mixed && byWindow != null ? ' (${_hm(byWindow)})' : '';
      out.add(PredictionReason(Icons.hourglass_bottom_rounded,
          '$since suele aguantar ${_duration(window)} despierto$result',
          weight: mixed ? windowW : null));
    }
    final routine = _time(b['routine_time']);
    if (routine != null && routineW >= minWeight) {
      out.add(PredictionReason(Icons.schedule_rounded, 'Suele acostarse sobre las ${_hm(routine)}',
          weight: routineW));
    }
    final dayLength = _int(b['day_length_min']);
    final byDay = _time(b['by_day_length']);
    if (dayLength != null && byDay != null && dayW >= minWeight) {
      out.add(PredictionReason(Icons.wb_sunny_outlined,
          'Su día suele durar ${_duration(dayLength)} desde que se despierta (${_hm(byDay)})',
          weight: dayW));
    }
    _addCorrection(out, b, 'se dormía');
    return out;
  }

  // ─── Despertar ─────────────────────────────────────────────────────────────

  static List<PredictionReason> _wakeReasons(Map<String, dynamic> b) {
    final out = <PredictionReason>[];
    final bed = _time(b['bed']);
    if (bed == null) {
      out.add(const PredictionReason(Icons.schedule_rounded,
          'Es su hora habitual de despertarse (no hay registrada una hora de acostarse)'));
      _addCorrection(out, b, 'se despertaba');
      return out;
    }
    out.add(b['bed_predicted'] == true
        ? PredictionReason(Icons.nightlight_round, 'Contando con que se acueste hacia las ${_hm(bed)}')
        : PredictionReason(Icons.nightlight_round, 'Se acostó a las ${_hm(bed)}'));

    final nightW = (_double(b['night_weight']) ?? 0).clamp(0.0, 1.0);
    final clockW = 1 - nightW;
    final mixed = nightW >= minWeight && clockW >= minWeight;
    final usual = _time(b['usual_time']);
    if (usual != null && clockW >= minWeight) {
      out.add(PredictionReason(Icons.schedule_rounded, 'Suele despertarse sobre las ${_hm(usual)}',
          weight: mixed ? clockW : null));
    }
    final night = _int(b['night_min']);
    final byNight = _time(b['by_night']);
    if (night != null && byNight != null && nightW >= minWeight) {
      out.add(PredictionReason(Icons.bedtime_outlined,
          'Suele dormir ${_duration(night)} por la noche (${_hm(byNight)})',
          weight: mixed ? nightW : null));
    }
    _addCorrection(out, b, 'se despertaba');
    return out;
  }

  // ─── Comunes ───────────────────────────────────────────────────────────────

  static PredictionReason _fromReason(Object? kind, DateTime at, bool predicted) {
    if (kind == 'wake') {
      return predicted
          ? PredictionReason(Icons.wb_twilight_rounded, 'Contando con que se despierte hacia las ${_hm(at)}')
          : PredictionReason(Icons.wb_twilight_rounded, 'Se despertó a las ${_hm(at)}');
    }
    return predicted
        ? PredictionReason(Icons.alarm_on_rounded, 'La siesta anterior debería terminar hacia las ${_hm(at)}')
        : PredictionReason(Icons.alarm_on_rounded, 'La última siesta terminó a las ${_hm(at)}');
  }

  /// Corrección aprendida comparando predicciones pasadas con lo que pasó.
  static void _addCorrection(List<PredictionReason> out, Map<String, dynamic> b, String verb) {
    final c = _int(b['correction_min']) ?? 0;
    if (c.abs() < minCorrection) return;
    final later = c > 0;
    out.add(PredictionReason(
      later ? Icons.update_rounded : Icons.history_rounded,
      '${_duration(c.abs())} más ${later ? 'tarde' : 'pronto'}: últimamente $verb '
      '${later ? 'después' : 'antes'} de lo previsto',
    ));
  }

  static String _hm(DateTime t) => VisualClockLogic.formatTime(t);

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
  static int? _int(Object? v) => v is num ? v.round() : null;
  static double? _double(Object? v) => v is num ? v.toDouble() : null;
}
