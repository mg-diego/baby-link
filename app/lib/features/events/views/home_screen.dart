import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // <-- Añadido para el Slider
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/api/api_service.dart';
import '../providers/events_provider.dart';
import '../../analytics/providers/daily_summary_provider.dart';

// Importa tus nuevos widgets separados
import 'widgets/date_selector.dart';
import 'widgets/summary_dashboard.dart';
import 'widgets/event_list_view.dart';
import 'widgets/visual_clock.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String babyId;
  const HomeScreen({super.key, required this.babyId});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _viewMode = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateAll();
    }
  }

  Future<void> _invalidateAll() async {
    final selectedDate = ref.read(selectedDateProvider);
    ref.invalidate(
      dailyEventsProvider((babyId: widget.babyId, date: selectedDate)),
    );
    ref.invalidate(
      dailyEventsProvider((
        babyId: widget.babyId,
        date: selectedDate.subtract(const Duration(days: 1)),
      )),
    );
    ref.invalidate(
      dailySummaryProvider((babyId: widget.babyId, date: selectedDate)),
    );
  }

  Future<void> _handleDelete(Map<String, dynamic> event) async {
    try {
      await ApiService.deleteEvent(event['id'].toString());
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _handleTap(Map<String, dynamic> event) {
    // TODO: navegar a pantalla de edición
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final args = (babyId: widget.babyId, date: selectedDate);
    final argsYday = (
      babyId: widget.babyId,
      date: selectedDate.subtract(const Duration(days: 1)),
    );

    final eventsAsync = ref.watch(dailyEventsProvider(args));
    final eventsYdayAsync = ref.watch(dailyEventsProvider(argsYday));
    final summaryAsync = ref.watch(dailySummaryProvider(args));

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isToday = selectedDate == today;
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Bebé',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _invalidateAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. SELECTOR DE FECHAS ──
          DateSelector(babyId: widget.babyId),

          // ── 2. TOGGLE DE VISTA (Estilo iOS) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity, // Ocupa todo el ancho disponible
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _viewMode,
                thumbColor: primaryColor,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                padding: const EdgeInsets.all(4),
                children: {
                  0: _buildSegmentContent(0, 'Reloj', Icons.av_timer_rounded),
                  1: _buildSegmentContent(1, 'Lista', Icons.format_list_bulleted_rounded),
                },
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() => _viewMode = value);
                  }
                },
              ),
            ),
          ),

          if (_viewMode == 1) const Divider(height: 1),

          // ── 4. ÁREA DE CONTENIDO ──
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                // Sacamos los eventos de ayer de forma segura
                final ydayEvents = eventsYdayAsync.asData?.value ?? [];

                if (_viewMode == 0) {
                  return VisualClockView(
                    events: List<Map<String, dynamic>>.from(events),
                    ydayEvents: List<Map<String, dynamic>>.from(ydayEvents),
                    selectedDate: selectedDate,
                  );
                }

                return EventListView(
                  initialEvents: List<Map<String, dynamic>>.from(events),
                  ydayEvents: List<Map<String, dynamic>>.from(
                    eventsYdayAsync.asData?.value ?? [],
                  ),
                  isToday: isToday,
                  onRefresh: _invalidateAll,
                  onDelete: _handleDelete,
                  onTap: _handleTap,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para construir el interior de cada segmento del selector iOS
  Widget _buildSegmentContent(int index, String text, IconData icon) {
    final isSelected = _viewMode == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}