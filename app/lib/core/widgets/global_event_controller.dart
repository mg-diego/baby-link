import 'package:app/features/analytics/providers/daily_summary_provider.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../api/api_service.dart';
import '../../../../core/widgets/custom_time_picker.dart'; 

class GlobalEventController extends ConsumerStatefulWidget {
  final String babyId;
  final String activeCategory;
  final ActiveEvent activeEvent;

  const GlobalEventController({
    super.key, 
    required this.babyId,
    required this.activeCategory,
    required this.activeEvent,
  });

  @override
  ConsumerState<GlobalEventController> createState() => _GlobalEventControllerState();
}

class _GlobalEventControllerState extends ConsumerState<GlobalEventController> {
  Timer? _timer;
  Duration _duration = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startLocalTimer(widget.activeEvent.startTime);
  }

  @override
  void didUpdateWidget(GlobalEventController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeEvent.startTime != widget.activeEvent.startTime) {
      _startLocalTimer(widget.activeEvent.startTime);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocalTimer(DateTime startTime) {
    _timer?.cancel();
    _duration = DateTime.now().difference(startTime);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = DateTime.now().difference(startTime);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "$hours:$minutes:$seconds";
    return "$minutes:$seconds";
  }

  // Helper para sacar los datos visuales
  ({String title, IconData icon, Color color}) _getVisuals() {
    switch (widget.activeCategory) {
      case 'nap': return (title: 'Siesta en curso', icon: Icons.bedtime, color: Colors.indigo);
      case 'night_waking': return (title: 'Despertar nocturno', icon: Icons.notifications_active, color: Colors.deepPurple);
      case 'nursing': return (title: 'Lactancia en curso', icon: Icons.favorite, color: Colors.pink);
      case 'pumping': return (title: 'Extracción en curso', icon: Icons.cyclone, color: Colors.teal);
      default: return (title: 'Actividad en curso', icon: Icons.timer, color: Colors.blue);
    }
  }

  // --- AQUÍ ESTÁ LA MAGIA INTERCEPTADA ---
  Future<void> _handleStopEvent() async {
    final visuals = _getVisuals();
    
    // 1. Abrimos el modal devolviendo un Mapa con fecha y notas
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime tempEndTime = DateTime.now();
        if (tempEndTime.isBefore(widget.activeEvent.startTime)) {
          tempEndTime = widget.activeEvent.startTime.add(const Duration(minutes: 1));
        }
        
        final notesController = TextEditingController();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 10,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final duration = tempEndTime.difference(widget.activeEvent.startTime);
              final isValid = !tempEndTime.isBefore(widget.activeEvent.startTime);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.only(bottom: 20, top: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                  ),
                  Text('Detener', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: visuals.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inicio: ${widget.activeEvent.startTime.hour.toString().padLeft(2,'0')}:${widget.activeEvent.startTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Duración: ${duration.inHours}h ${duration.inMinutes % 60}m', 
                                style: TextStyle(color: isValid ? visuals.color : Colors.red, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                          Icon(visuals.icon, color: visuals.color),
                        ],
                      ),
                    ),
                  ),

                  CustomTimePicker(
                    time: tempEndTime,
                    onTimeChanged: (newTime) => setModalState(() => tempEndTime = newTime),
                  ),
                  
                  if (!isValid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text('La hora de fin no puede ser anterior al inicio', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),

                  const SizedBox(height: 15),
                  
                  // Nuevo campo de Notas
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),

                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isValid ? () {
                        Navigator.pop(ctx, {
                          'time': tempEndTime,
                          'notes': notesController.text,
                        });
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: visuals.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Finalizar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (result == null) return; // El usuario canceló el BottomSheet

    // 2. Ejecutamos la API con la hora y notas editadas
    setState(() => _isLoading = true);
    final DateTime finalTime = result['time'];
    final String notes = result['notes'];

    try {
      final updateData = {
        'end_time': finalTime.toUtc().toIso8601String(),
      };
      
      // Solo mandamos las notas al backend si el usuario escribió algo
      if (notes.trim().isNotEmpty) {
        updateData['notes'] = notes.trim();
      }

      await ApiService.updateEvent(widget.activeEvent.eventId, updateData);

      _timer?.cancel();
      
      if (widget.activeCategory == 'nap') ref.read(activeNapProvider.notifier).stop();
      if (widget.activeCategory == 'night_waking') ref.read(activeNightWakingProvider.notifier).stop();
      if (widget.activeCategory == 'nursing') ref.read(activeBreastfeedingProvider.notifier).stop();
      if (widget.activeCategory == 'pumping') ref.read(activePumpingProvider.notifier).stop();
      
      // Refrescamos las listas globales
      final currentDate = ref.read(selectedDateProvider);
      ref.invalidate(dailyEventsProvider((babyId: widget.babyId, date: currentDate)));
      ref.invalidate(dailySummaryProvider((babyId: widget.babyId, date: currentDate)));

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _getVisuals();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: visuals.color.withOpacity(0.1),
        border: Border(top: BorderSide(color: visuals.color.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(visuals.icon, color: visuals.color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(visuals.title, style: TextStyle(fontWeight: FontWeight.bold, color: visuals.color)),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(fontSize: 16, color: visuals.color),
                  ),
                ],
              ),
            ],
          ),
          _isLoading 
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : TextButton.icon(
                onPressed: _handleStopEvent,
                icon: const Icon(Icons.stop, color: Colors.red),
                label: const Text('Detener', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
        ],
      ),
    );
  }
}