import 'package:app/features/analytics/views/widgets/category_selector.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/widgets/date_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../models/daily_summary.dart';
import '../../events/providers/events_provider.dart';

final dailySummaryProvider = FutureProvider.autoDispose.family<DailySummary?, DailyEventsArgs>((ref, args) async {
  return await ApiService.getDailySummary(args.babyId, args.date);
});

final statsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final babyId = ref.watch(babyIdProvider).value;

  if (babyId == null) return null;

  final dateRange = ref.watch(selectedDateRangeProvider);
  
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