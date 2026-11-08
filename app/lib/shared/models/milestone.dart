import 'dart:math' as math;

class Milestone {
  final String id;
  final String babyId;
  final String title;
  final String? description;
  final DateTime date;
  final String category;
  final String? subcategory;
  final String? mediaUrl;
  final String mediaType;
  final String? emoji;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.babyId,
    required this.title,
    this.description,
    required this.date,
    required this.category,
    this.subcategory,
    this.mediaUrl,
    this.mediaType = 'none',
    this.emoji,
    this.metadata = const {},
    required this.createdAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
    id: j['id'] as String,
    babyId: j['baby_id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    date: DateTime.parse(j['date'] as String),
    category: j['category'] as String,
    subcategory: j['subcategory'] as String?,
    mediaUrl: j['media_url'] as String?,
    mediaType: j['media_type'] as String? ?? 'none',
    emoji: j['emoji'] as String?,
    metadata: (j['metadata'] as Map<String, dynamic>?) ?? {},
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  bool get hasMedia => mediaUrl != null && mediaType != 'none';
  bool get isVideo => hasMedia && mediaType == 'video';
  bool get isImage => hasMedia && !isVideo;

  /// Emoji a mostrar cuando no hay foto.
  String get displayEmoji => emoji ?? catFor(category).emoji;

  /// Tag compartido por las transiciones Hero de la foto del hito.
  String get heroTag => 'milestone-media-$id';

  // Rotación determinista basada en el id — siempre la misma por hito
  double get rotation {
    final hash = id.codeUnits.fold(0, (a, b) => a + b);
    return ((hash % 13) - 6) * math.pi / 180; // −6° a +6°
  }

  /// Inclinación sutil para las tarjetas de la cuadrícula (−1.5° a +1.5°).
  double get tilt {
    final hash = id.codeUnits.fold(0, (a, b) => a + b);
    return ((hash % 7) - 3) * 0.5 * math.pi / 180;
  }

  String ageLabel(DateTime dob) => formatBabyAge(dob, date);
}

/// Edad del bebé en [at] respecto a su fecha de nacimiento [dob].
String formatBabyAge(DateTime dob, DateTime at) {
  // UTC para que los cambios de horario no alteren el cómputo de días.
  final birth = DateTime.utc(dob.year, dob.month, dob.day);
  final day = DateTime.utc(at.year, at.month, at.day);

  var months = (day.year - birth.year) * 12 + day.month - birth.month;
  if (day.day < birth.day) months--;

  if (months <= 0) {
    final days = math.max(0, day.difference(birth).inDays);
    return days == 1 ? '1 día' : '$days días';
  }
  if (months < 12) return months == 1 ? '1 mes' : '$months meses';
  final y = months ~/ 12;
  final m = months % 12;
  final years = y == 1 ? '1 año' : '$y años';
  if (m == 0) return years;
  return '$years y ${m == 1 ? '1 mes' : '$m meses'}';
}

// ─── Categorías ────────────────────────────────────────────────────────────────

class MilestoneCat {
  final String key;
  final String label;
  final String emoji;
  final List<String> suggestions;

  const MilestoneCat({
    required this.key,
    required this.label,
    required this.emoji,
    this.suggestions = const [],
  });
}

const kMilestoneCategories = [
  MilestoneCat(
    key: 'physical',
    label: 'Físico',
    emoji: '💪',
    suggestions: [
      'Primera vuelta',
      'Se mantiene sentado',
      'Gatea',
      'Primeros pasos',
      'Primer diente',
    ],
  ),
  MilestoneCat(
    key: 'social',
    label: 'Social',
    emoji: '😊',
    suggestions: ['Primera sonrisa', 'Primera carcajada', 'Primera palabra'],
  ),
  MilestoneCat(
    key: 'feeding',
    label: 'Alimentación',
    emoji: '🍎',
    suggestions: ['Primeros sólidos', 'Primera fruta', 'Primera papilla'],
  ),
  MilestoneCat(
    key: 'events',
    label: 'Eventos',
    emoji: '🎉',
    suggestions: [
      'Primer baño',
      'Primer corte de pelo',
      'Primera Navidad',
      'Primer viaje',
      'Primer cumpleaños',
    ],
  ),
  MilestoneCat(
    key: 'custom',
    label: 'Personalizado',
    emoji: '⭐',
    suggestions: [],
  ),
];

MilestoneCat catFor(String key) => kMilestoneCategories.firstWhere(
  (c) => c.key == key,
  orElse: () => kMilestoneCategories.last,
);
