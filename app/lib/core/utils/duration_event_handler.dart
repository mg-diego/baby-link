import 'package:app/core/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/shared/models/event_type.dart';
import 'package:app/shared/widgets/custom_time_picker.dart';
import 'package:app/core/network/api_service.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../features/events/providers/events_provider.dart';

class DurationEventHandler {
  static StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>?
  getProviderForEventType(EventType type) {
    if (type == EventType.nap) return activeNapProvider;
    if (type == EventType.nightWaking) return activeNightWakingProvider;
    if (type == EventType.nursing) return activeNursingProvider;
    if (type == EventType.pumping) return activePumpingProvider;
    return null;
  }

  static Future<void> handleAction({
    required BuildContext context,
    required WidgetRef ref,
    required String babyId,
    required EventType eventType,
    required VoidCallback onSuccess,
  }) async {
    final provider = getProviderForEventType(eventType);
    if (provider == null) return;

    final activeEvent = ref.read(provider);
    final isActive = activeEvent != null;

    if (!isActive) {
      await _startEvent(context, ref, babyId, eventType, provider, onSuccess);
    } else {
      await _stopEvent(
        context,
        ref,
        eventType,
        provider,
        activeEvent,
        onSuccess,
      );
    }
  }

  static Future<void> _startEvent(
    BuildContext context,
    WidgetRef ref,
    String babyId,
    EventType eventType,
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?> provider,
    VoidCallback onSuccess,
  ) async {
    final selectedStartTime = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime tempTime = DateTime.now();
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 10,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20, top: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    'Iniciar ${eventType.uiLabel}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomTimePicker(
                    time: tempTime,
                    onTimeChanged: (newTime) =>
                        setModalState(() => tempTime = newTime),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, tempTime),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Guardar inicio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selectedStartTime == null) return;

    try {
      Map<String, dynamic> metadata = {};
      if (eventType == EventType.nursing) metadata = {'type': 'nursing'};
      if (eventType == EventType.nap) {
        final predictions = ref
            .read(sleepPredictionProvider(babyId))
            .asData
            ?.value;
        final currentNapPrediction = predictions
            ?.where((p) => p.isNap)
            .firstOrNull;
        if (currentNapPrediction != null && currentNapPrediction.end != null) {
          final predictedDuration = currentNapPrediction.end!
              .difference(currentNapPrediction.start)
              .inMinutes;
          metadata = {'predicted_duration_minutes': predictedDuration};
        }
      }

      final response = await ApiService.registerEvent(
        babyId,
        eventType.backendCategory,
        metadata,
        startTime: selectedStartTime,
      );

      final eventId = response['id'] ?? response['data']?['id'];
      ref.read(provider.notifier).start(eventId.toString(), selectedStartTime);
      onSuccess();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static Future<void> _stopEvent(
    BuildContext context,
    WidgetRef ref,
    EventType eventType,
    StateNotifierProvider<ActiveEventNotifier, ActiveEvent?> provider,
    ActiveEvent activeEvent,
    VoidCallback onSuccess,
  ) async {
    final selectedEndTime = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime tempEndTime = DateTime.now();
        if (tempEndTime.isBefore(activeEvent.startTime)) {
          tempEndTime = activeEvent.startTime.add(const Duration(minutes: 1));
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 10,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final duration = tempEndTime.difference(activeEvent.startTime);
              final isValid = !tempEndTime.isBefore(activeEvent.startTime);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20, top: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    'Detener ${eventType.uiLabel}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: eventType
                            .getAccentColor(context)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inicio: ${TimeUtils.formatTimeOnly(activeEvent.startTime)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Duración: ${TimeUtils.formatDuration(duration)}',
                                style: TextStyle(
                                  color: isValid
                                      ? eventType.getAccentColor(context)
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            eventType.icon,
                            color: eventType.getAccentColor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  CustomTimePicker(
                    time: tempEndTime,
                    onTimeChanged: (newTime) =>
                        setModalState(() => tempEndTime = newTime),
                  ),
                  if (!isValid)
                    const Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: Text(
                        'La hora de fin no puede ser anterior al inicio',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isValid
                          ? () => Navigator.pop(ctx, tempEndTime)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Finalizar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selectedEndTime == null) return;

    try {
      await ApiService.updateEvent(activeEvent.eventId, {
        'end_time': selectedEndTime.toUtc().toIso8601String(),
      });
      ref.read(provider.notifier).stop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${eventType.uiLabel} finalizada correctamente'),
          ),
        );
      }
      onSuccess();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
