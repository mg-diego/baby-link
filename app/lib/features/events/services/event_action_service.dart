// lib/features/events/services/event_action_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/network/api_service.dart';
import 'package:app/shared/models/event_type.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/analytics/providers/daily_summary_provider.dart';

final eventActionProvider = Provider((ref) => EventActionService(ref));

class EventActionService {
  final Ref ref;

  EventActionService(this.ref);

  void refreshLists(String babyId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final currentDate = ref.read(selectedDateProvider);

    ref.invalidate(dailyEventsProvider((babyId: babyId, date: today)));
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: yesterday)));
    ref.invalidate(dailyEventsProvider((babyId: babyId, date: currentDate)));
    
    ref.invalidate(dailySummaryProvider((babyId: babyId, date: currentDate)));
    ref.invalidate(lastEventsProvider(babyId));
    ref.invalidate(sleepPredictionProvider(babyId));
    ref.invalidate(wakePredictionProvider(babyId));
  }

  Future<void> logEvent(String babyId, String category, Map<String, dynamic> metadata, DateTime eventTime) async {
    await ApiService.registerEvent(
      babyId,
      category,
      metadata,
      startTime: eventTime,
    );
    refreshLists(babyId);
  }

  Future<void> startNursingEvent(String babyId, Map<String, dynamic> meta, DateTime time) async {
    final response = await ApiService.registerEvent(
      babyId,
      EventType.nursing.backendCategory,
      meta,
      startTime: time,
    );

    final eventId = response['id'] ?? response['data']?['id'];
    
    ref.read(activeBreastfeedingProvider.notifier).start(eventId.toString(), time);
    refreshLists(babyId);
  }

  Future<void> stopNursingEvent(String babyId, ActiveEvent activeEvent, Map<String, dynamic> meta, DateTime endTime) async {
    if (endTime.isBefore(activeEvent.startTime)) {
      throw Exception('La hora de fin no puede ser anterior al inicio');
    }

    await ApiService.updateEvent(activeEvent.eventId, {
      'end_time': endTime.toUtc().toIso8601String(),
      'metadata': meta,
    });

    ref.read(activeBreastfeedingProvider.notifier).stop();
    refreshLists(babyId);
  }

  Future<void> updateEvent(String babyId, String eventId, Map<String, dynamic> payload, {String? categoryToStop}) async {
    await ApiService.updateEvent(eventId, payload);
    
    if (categoryToStop == 'nursing' && payload.containsKey('end_time')) {
      ref.read(activeBreastfeedingProvider.notifier).stop();
    }
    refreshLists(babyId);
  }

  Future<void> deleteEvent(String babyId, String eventId, String category, String? endTimeStr) async {
    await ApiService.deleteEvent(eventId);
    
    if (endTimeStr == null) {
      if (category == 'nap') ref.read(activeNapProvider.notifier).stop();
      if (category == 'night_waking') ref.read(activeNightWakingProvider.notifier).stop();
      if (category == 'nursing') ref.read(activeBreastfeedingProvider.notifier).stop();
      if (category == 'pumping') ref.read(activePumpingProvider.notifier).stop();
    }
    refreshLists(babyId);
  }
}