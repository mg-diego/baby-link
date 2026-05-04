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

  // Rotación determinista basada en el id — siempre la misma por hito
  double get rotation {
    final hash = id.codeUnits.fold(0, (a, b) => a + b);
    return ((hash % 13) - 6) * math.pi / 180; // −6° a +6°
  }

  String ageLabel(DateTime dob) {
    int months = (date.year - dob.year) * 12 + date.month - dob.month;
    int days = date.day - dob.day;
    if (days < 0) { months--; days += 30; }
    if (months <= 0) return '$days días';
    if (months < 12) return months == 1 ? '1 mes' : '$months meses';
    final y = months ~/ 12;
    final m = months % 12;
    if (m == 0) return y == 1 ? '1 año' : '$y años';
    return '${y == 1 ? '1 año' : '$y años'}, ${m == 1 ? '1 mes' : '$m meses'}';
  }
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
    suggestions: [
      'Primera sonrisa',
      'Primera carcajada',
      'Primera palabra',
    ],
  ),
  MilestoneCat(
    key: 'feeding',
    label: 'Alimentación',
    emoji: '🍎',
    suggestions: [
      'Primeros sólidos',
      'Primera fruta',
      'Primera papilla',
    ],
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

MilestoneCat catFor(String key) =>
    kMilestoneCategories.firstWhere((c) => c.key == key,
        orElse: () => kMilestoneCategories.last);