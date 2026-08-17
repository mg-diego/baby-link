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
    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime tempStartTime = DateTime.now();
        DateTime? tempEndTime;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final size = MediaQuery.sizeOf(ctx);
            final viewInsets = MediaQuery.viewInsetsOf(ctx);
            final scale = (size.width / 400).clamp(0.85, 1.2);
            final horizontalPadding = size.width > 600 ? (size.width - 600) / 2 : 0.0;
            final isValidEnd =
                tempEndTime != null && !tempEndTime!.isBefore(tempStartTime);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: size.height * 0.9),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: EdgeInsets.only(
                      bottom: viewInsets.bottom + (20 * scale),
                      left: 24 * scale,
                      right: 24 * scale,
                      top: 12 * scale,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48 * scale,
                            height: 5 * scale,
                            margin: EdgeInsets.only(bottom: 20 * scale),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Text(
                            'Registrar ${eventType.uiLabel}',
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 24 * scale),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Hora de inicio',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15 * scale,
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          CustomTimePicker(
                            time: tempStartTime,
                            onTimeChanged: (newTime) {
                              setModalState(() {
                                tempStartTime = newTime;
                                if (tempEndTime != null &&
                                    tempEndTime!.isBefore(tempStartTime)) {
                                  tempEndTime = tempStartTime.add(
                                    const Duration(minutes: 30),
                                  );
                                }
                              });
                            },
                          ),
                          SizedBox(height: 24 * scale),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hora de fin (Opcional)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15 * scale,
                                ),
                              ),
                              if (tempEndTime != null)
                                GestureDetector(
                                  onTap: () => setModalState(() => tempEndTime = null),
                                  child: Text(
                                    'Borrar',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 * scale,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 10 * scale),
                          if (tempEndTime == null)
                            InkWell(
                              onTap: () {
                                setModalState(() {
                                  tempEndTime = tempStartTime.add(
                                    const Duration(minutes: 30),
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(16 * scale),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16 * scale),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20 * scale,
                                    ),
                                    SizedBox(width: 8 * scale),
                                    Text(
                                      'Añadir hora de fin',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15 * scale,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            CustomTimePicker(
                              time: tempEndTime!,
                              onTimeChanged: (newTime) =>
                                  setModalState(() => tempEndTime = newTime),
                            ),
                          if (tempEndTime != null && !isValidEnd)
                            Padding(
                              padding: EdgeInsets.only(top: 12.0 * scale),
                              child: Text(
                                'La hora de fin no puede ser anterior al inicio',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 13 * scale,
                                ),
                              ),
                            ),
                          SizedBox(height: 32 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 52 * scale,
                            child: ElevatedButton(
                              onPressed: isValidEnd
                                  ? () {
                                      Navigator.pop(ctx, {
                                        'start': tempStartTime,
                                        'end': tempEndTime!,
                                      });
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16 * scale),
                                ),
                                elevation: isValidEnd ? 2 : 0,
                              ),
                              child: Text(
                                'Guardar evento finalizado',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 52 * scale,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx, {'start': tempStartTime});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16 * scale),
                                ),
                              ),
                              child: Text(
                                'Solo iniciar evento',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || result['start'] == null) return;

    final selectedStartTime = result['start']!;
    final selectedEndTime = result['end'];

    try {
      Map<String, dynamic> metadata = {};
      if (eventType == EventType.nursing) metadata = {'type': 'nursing'};
      if (eventType == EventType.nap) {
        final predictionsState = ref.read(sleepPredictionProvider(babyId));
        final predictions = predictionsState.asData?.value;
        final currentNapPrediction = predictions
            ?.where((p) => p.isNap)
            .firstOrNull;

        if (currentNapPrediction != null && currentNapPrediction.end != null) {
          metadata = {
            ...metadata,
            'predicted_start_time': currentNapPrediction.start
                .toUtc()
                .toIso8601String(),
            'predicted_end_time': currentNapPrediction.end!
                .toUtc()
                .toIso8601String(),
          };
        }
      }

      final response = await ApiService.registerEvent(
        babyId,
        eventType.backendCategory,
        metadata,
        startTime: selectedStartTime,
      );

      final eventId = response['id'] ?? response['data']?['id'];

      if (selectedEndTime != null) {
        await ApiService.updateEvent(eventId.toString(), {
          'end_time': selectedEndTime.toUtc().toIso8601String(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${eventType.uiLabel} registrado correctamente'),
            ),
          );
        }
      } else {
        ref
            .read(provider.notifier)
            .start(eventId.toString(), selectedStartTime);
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

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final size = MediaQuery.sizeOf(ctx);
            final viewInsets = MediaQuery.viewInsetsOf(ctx);
            final scale = (size.width / 400).clamp(0.85, 1.2);
            final horizontalPadding = size.width > 600 ? (size.width - 600) / 2 : 0.0;
            
            final duration = tempEndTime.difference(activeEvent.startTime);
            final isValid = !tempEndTime.isBefore(activeEvent.startTime);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: size.height * 0.9),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: EdgeInsets.only(
                      bottom: viewInsets.bottom + (20 * scale),
                      left: 24 * scale,
                      right: 24 * scale,
                      top: 12 * scale,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48 * scale,
                            height: 5 * scale,
                            margin: EdgeInsets.only(bottom: 20 * scale),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Text(
                            'Detener ${eventType.uiLabel}',
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0 * scale),
                            child: Container(
                              padding: EdgeInsets.all(16 * scale),
                              decoration: BoxDecoration(
                                color: eventType
                                    .getAccentColor(context)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16 * scale),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Inicio: ${TimeUtils.formatTimeOnly(activeEvent.startTime)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15 * scale,
                                        ),
                                      ),
                                      SizedBox(height: 6 * scale),
                                      Text(
                                        'Duración: ${TimeUtils.formatDuration(duration)}',
                                        style: TextStyle(
                                          color: isValid
                                              ? eventType.getAccentColor(context)
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15 * scale,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    eventType.icon,
                                    color: eventType.getAccentColor(context),
                                    size: 28 * scale,
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
                            Padding(
                              padding: EdgeInsets.only(top: 12.0 * scale),
                              child: Text(
                                'La hora de fin no puede ser anterior al inicio',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 13 * scale,
                                ),
                              ),
                            ),
                          SizedBox(height: 32 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 52 * scale,
                            child: ElevatedButton(
                              onPressed: isValid
                                  ? () => Navigator.pop(ctx, tempEndTime)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16 * scale),
                                ),
                                elevation: isValid ? 2 : 0,
                              ),
                              child: Text(
                                'Finalizar',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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