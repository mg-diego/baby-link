import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

enum EventType {
  // --- SLEEP ---
  wokeUp(
    'Se despertó', 'woke_up', 'sleep',
    Icons.wb_sunny_rounded, null,
    Color(0xFFF8A173),
  ),
  nap(
    'Siesta', 'nap', 'sleep',
    Icons.bedtime_rounded, null,
    Color(0xFF9797FF),
  ),
  bedtime(
    'Hora de dormir', 'bed_time', 'sleep',
    Icons.nights_stay_rounded, null,
    Color(0xFFF9A475),
  ),
  nightWaking(
    'Despertar nocturno', 'night_waking', 'sleep',
    Icons.thunderstorm, null,
    Color(0xFFF9765D),
  ),

  // --- FEEDING ---
  bottle(
    'Biberón', 'feed', 'feeding',
    null,
    'bottle',
    Color(0xFFA2F6D0),
  ),
  nursing(
    'Lactancia', 'feed', 'feeding',
    Icons.favorite_rounded, 'nursing',
    Color(0xFFA2F6D0),
  ),
  solids(
    'Sólidos', 'feed', 'feeding',
    Icons.restaurant_rounded, 'solids',
    Color(0xFFA2F6D0),
  ),
  pumping(
    'Extracción', 'pumping', 'feeding',
    Icons.water_drop_rounded, null,
    Color(0xFFA2F6D0),
  ),

  // --- CARE ---
  diaper(
    'Pañal', 'diaper', 'care',
    Icons.baby_changing_station_rounded, null,
    Color(0xFFFFAEEB),
  ),
  bath(
    'Baño', 'bath', 'care',
    Icons.bathtub_rounded, null,
    Color(0xFF4FC3F7),
  ),
  temperature(
    'Temperatura', 'temperature', 'care',
    Icons.thermostat_rounded, null,
    Color(0xFFEF9A9A),
  ),
  medicine(
    'Medicina', 'medicine', 'care',
    Icons.medication_liquid_rounded, null,
    Color(0xFFFFCC80),
  ),

  // --- HEALTH ---
  growth(
    'Crecimiento', 'growth', 'health',
    Icons.show_chart_rounded, null,
    Color(0xFF7986CB),
  ),
  milestone(
    'Hito', 'milestone', 'health',
    Icons.star_rounded, null,
    Color(0xFFFFD54F),
  );

  final String uiLabel;
  final String backendCategory;
  final String uiGroup;
  final IconData? _nativeIcon;
  final String? metadataType;
  final Color color;

  const EventType(
    this.uiLabel,
    this.backendCategory,
    this.uiGroup,
    this._nativeIcon,
    this.metadataType,
    this.color,
  );

  IconData get icon {
    if (this == EventType.bottle) {
      return MdiIcons.babyBottleOutline;
    }
    else if(this == EventType.nursing) {
      return MdiIcons.motherNurse;
    }
    else if(this == EventType.bedtime) {
      return MdiIcons.sleep;
    }
    return _nativeIcon ?? Icons.help_outline; 
  }

  Color getAccentColor(BuildContext context, {bool? forceNightMode}) {
    final isNight = forceNightMode ?? Theme.of(context).brightness == Brightness.dark;

    if (isNight) {
      return color;
    }

    final hsl = HSLColor.fromColor(color);    
    final double targetLightness = hsl.lightness > 0.40 ? 0.40 : hsl.lightness;    
    return hsl.withLightness(targetLightness).withSaturation(0.85).toColor();
  }

  Color getBackgroundColor(BuildContext context, {bool? forceNightMode}) {
    final isNight = forceNightMode ?? Theme.of(context).brightness == Brightness.dark;
    final baseAccent = getAccentColor(context, forceNightMode: forceNightMode);
    
    return baseAccent.withOpacity(isNight ? 0.15 : 0.08);
  }

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