import 'package:app/api/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

typedef DailyEventsArgs = ({String babyId, DateTime date});

final dailyEventsProvider = FutureProvider.autoDispose.family<List<dynamic>, DailyEventsArgs>((ref, args) async {
  return await ApiService.getEventsByDateRange(args.babyId, args.date, args.date);
});

// --- MODELO GENÉRICO DE EVENTO ACTIVO ---
class ActiveEvent {
  final String eventId;
  final DateTime startTime;

  ActiveEvent({required this.eventId, required this.startTime});
}

// --- NOTIFIER GENÉRICO ---
// Maneja la lógica de iniciar y detener para cualquier tipo de cronómetro
class ActiveEventNotifier extends StateNotifier<ActiveEvent?> {
  ActiveEventNotifier() : super(null);

  void start(String backendEventId, DateTime startTime) {
    state = ActiveEvent(eventId: backendEventId, startTime: startTime);
  }

  void stop() {
    state = null;
  }
}

// --- PROVIDERS ---

// 1. Proveedor de Siesta
final activeNapProvider = StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
  return ActiveEventNotifier();
});

// 2. Proveedor de Despertar Nocturno
final activeNightWakingProvider = StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
  return ActiveEventNotifier();
});

// 3. Proveedor de Lactancia (Pecho)
final activeBreastfeedingProvider = StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
  return ActiveEventNotifier();
});

// 4. Proveedor de Extracción de leche
final activePumpingProvider = StateNotifierProvider<ActiveEventNotifier, ActiveEvent?>((ref) {
  return ActiveEventNotifier();
});


final allActiveEventsProvider = Provider<Map<String, ActiveEvent>>((ref) {
  final activeEvents = <String, ActiveEvent>{};

  final nap = ref.watch(activeNapProvider);
  if (nap != null) activeEvents['nap'] = nap;

  final nightWaking = ref.watch(activeNightWakingProvider);
  if (nightWaking != null) activeEvents['night_waking'] = nightWaking;

  final nursing = ref.watch(activeBreastfeedingProvider);
  if (nursing != null) activeEvents['nursing'] = nursing;

  final pumping = ref.watch(activePumpingProvider);
  if (pumping != null) activeEvents['pumping'] = pumping;

  return activeEvents; 
});

final validEventDatesProvider = FutureProvider.family<Set<DateTime>, String>((ref, babyId) async {
  try {
    // Llamamos a tu ApiService
    final datesStr = await ApiService.getValidEventDates(babyId);
    
    // Mapeamos los strings a DateTimes limpios (sin hora)
    return datesStr.map((dateStr) {
      final parsed = DateTime.parse(dateStr);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }).toSet();
    
  } catch (e) {
    print('Error en validEventDatesProvider: $e');
    return <DateTime>{}; // Si hay error, devolvemos un set vacío
  }
});