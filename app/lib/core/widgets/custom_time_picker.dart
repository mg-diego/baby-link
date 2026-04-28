import 'package:flutter/material.dart';

class CustomTimePicker extends StatelessWidget {
  final DateTime time;
  final Function(DateTime) onTimeChanged;
  
  // ── OPCIONALES PARA CUANDO QUERAMOS RESTRINGIR ──
  final Set<DateTime>? validDates; 
  final DateTime? minimumDate;

  const CustomTimePicker({
    super.key,
    required this.time,
    required this.onTimeChanged,
    this.validDates,
    this.minimumDate,
  });

  String _getFormattedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(time.year, time.month, time.day);

    if (targetDate == today) return 'Hoy';
    if (targetDate == yesterday) return 'Ayer';

    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${time.day} ${months[time.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // Si no nos pasan minimumDate, usamos 2020 por defecto
    final firstDate = minimumDate ?? DateTime(2020);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: time,
                    firstDate: firstDate,
                    lastDate: DateTime.now(),
                    helpText: validDates != null 
                        ? 'SELECCIONA EL DÍA (Toca el año para saltar)' 
                        : 'SELECCIONA EL DÍA',
                    cancelText: 'CANCELAR',
                    confirmText: 'ACEPTAR',
                    // ── LÓGICA CONDICIONAL DE BLOQUEO ──
                    selectableDayPredicate: validDates != null
                        ? (DateTime day) {
                            final normalizedDay = DateTime(day.year, day.month, day.day);
                            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                            return validDates!.contains(normalizedDay) || normalizedDay == today;
                          }
                        : null, // Si validDates es null, todos los días son clicables
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.teal, 
                            onPrimary: Colors.white,
                            onSurface: Colors.black87,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    onTimeChanged(DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      time.hour,
                      time.minute,
                    ));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        _getFormattedDate(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.teal),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onTimeChanged(time.subtract(const Duration(minutes: 1))),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(time),
                      );
                      if (pickedTime != null) {
                        onTimeChanged(DateTime(
                          time.year,
                          time.month,
                          time.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        ));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onTimeChanged(time.add(const Duration(minutes: 1))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}