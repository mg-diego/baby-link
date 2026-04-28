import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../api/api_service.dart';
import '../models/daily_summary.dart';
import '../../events/providers/events_provider.dart';

// Ahora usa DailyEventsArgs para saber exactamente qué día pedir
final dailySummaryProvider = FutureProvider.autoDispose.family<DailySummary?, DailyEventsArgs>((ref, args) async {
  return await ApiService.getDailySummary(args.babyId, args.date);
});