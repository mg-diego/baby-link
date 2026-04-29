import 'package:app/features/analytics/views/widgets/category_selector.dart';
import 'package:app/features/events/providers/baby_provider.dart';
import 'package:app/features/events/views/widgets/date_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../api/api_service.dart';
import '../models/daily_summary.dart';
import '../../events/providers/events_provider.dart';

// Ahora usa DailyEventsArgs para saber exactamente qué día pedir
final dailySummaryProvider = FutureProvider.autoDispose.family<DailySummary?, DailyEventsArgs>((ref, args) async {
  return await ApiService.getDailySummary(args.babyId, args.date);
});

final statsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final babyId = ref.watch(babyIdProvider).value;
  if (babyId == null) return null;

  // Escuchamos el rango de fechas
  final dateRange = ref.watch(selectedDateRangeProvider);
  
  // Escuchamos las categorías
  final category = ref.watch(selectedStatCategoryProvider);
  final subcategory = ref.watch(selectedStatSubCategoryProvider) ?? 'Todo';

  return ApiService.getStats(
    babyId: babyId,
    startDate: dateRange.start,
    endDate: dateRange.end,
    category: category,
    subcategory: subcategory,
  );
});