import 'package:flutter/material.dart';

enum EventType {
  // Sleep
  wokeUp(
    'Se despertó', 'woke_up', 'sleep',
    Icons.wb_sunny_outlined, null,
    Color(0xFFFDCC77), // amber
  ),
  nap(
    'Siesta', 'nap', 'sleep',
    Icons.bedtime_outlined, null,
    Color(0xFF8F95FF), // lavender
  ),
  bedtime(
    'Hora de acostarse', 'bed_time', 'sleep',
    Icons.nightlight_round, null,
    Color(0xFFF9AC87), // indigo
  ),
  nightWaking(
    'Despertar nocturno', 'night_waking', 'sleep',
    Icons.notifications_active_outlined, null,
    Color(0xFFF77E6E), // red
  ),

  // Feeding
  bottle(
    'Biberón', 'feed', 'feeding',
    Icons.local_drink, 'bottle',
    Color(0xFFACFBD7), // green
  ),
  nursing(
    'Lactancia', 'feed', 'feeding',
    Icons.favorite_outline, 'breast',
    Color(0xFFACFBD7), // green
  ),
  solids(
    'Sólidos', 'feed', 'feeding',
    Icons.restaurant, 'solids',
    Color(0xFFACFBD7), // green
  ),
  pumping(
    'Extracción', 'pumping', 'feeding',
    Icons.cyclone, null,
    Color(0xFFACFBD7), // cyan
  ),

  // Care
  diaper(
    'Pañal', 'diaper', 'care',
    Icons.baby_changing_station, null,
    Color(0xFFFFB0EE), // pink
  ),
  bath(
    'Baño', 'bath', 'care',
    Icons.bathtub_outlined, null,
    Color(0xFF4FC3F7), // light blue
  ),
  temperature(
    'Temperatura', 'temperature', 'care',
    Icons.thermostat, null,
    Color(0xFFEF9A9A), // soft red
  ),
  medicine(
    'Medicina', 'medicine', 'care',
    Icons.medication_liquid, null,
    Color(0xFFFFCC80), // orange
  ),

  // Health
  growth(
    'Crecimiento', 'growth', 'health',
    Icons.show_chart, null,
    Color(0xFF80CBC4), // teal
  ),
  milestone(
    'Hito', 'milestone', 'health',
    Icons.star_border, null,
    Color(0xFFFFD54F), // yellow
  );

  final String uiLabel;
  final String backendCategory;
  final String uiGroup;
  final IconData icon;
  final String? metadataType;
  final Color color;

  const EventType(
    this.uiLabel,
    this.backendCategory,
    this.uiGroup,
    this.icon,
    this.metadataType,
    this.color,
  );

  /// Color de fondo suave (10% de opacidad) para usar en cards
  Color get backgroundColor => color.withOpacity(0.10);

  /// Color de acento (el color puro) para iconos, bordes, badges
  Color get accentColor => color;

  static EventType fromBackend(String category, Map<String, dynamic> metadata) {
    return EventType.values.firstWhere(
      (e) {
        if (e.backendCategory != category) return false;
        if (e.metadataType != null) {
          return metadata['type'] == e.metadataType;
        }
        return true;
      },
      orElse: () => EventType.values.firstWhere(
        (e) => e.backendCategory == category,
        orElse: () => EventType.nap,
      ),
    );
  }
}