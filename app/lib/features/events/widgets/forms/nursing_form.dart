import 'package:flutter/material.dart';
import 'package:app/shared/widgets/custom_time_picker.dart';

class NursingForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime, [DateTime?]) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final bool isEditing;

  const NursingForm({
    super.key,
    required this.onSave,
    this.initialMetadata,
    this.initialStartTime,
    this.initialEndTime,
    this.isEditing = false,
  });

  @override
  State<NursingForm> createState() => _NursingFormState();
}

class _NursingFormState extends State<NursingForm> {
  late DateTime _startTime;
  DateTime? _endTime;
  late String _side;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime ?? DateTime.now();
    _endTime = widget.initialEndTime;
    _side = widget.initialMetadata?['side'] ?? 'Ambos';
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = !widget.isEditing || _endTime == null || !_endTime!.isBefore(_startTime);

    return Column(
      crossAxisAlignment: widget.isEditing ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (widget.isEditing) ...[
          const Text('Hora de inicio:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ],
        CustomTimePicker(
          time: _startTime,
          onTimeChanged: (newTime) => setState(() => _startTime = newTime),
        ),
        
        // ── HORA DE FIN (SOLO VISIBLE SI ESTÁ EDITANDO O DETENIENDO) ──
        if (widget.isEditing) ...[
          const SizedBox(height: 16),
          const Text('Hora de fin:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_endTime != null)
            CustomTimePicker(
              time: _endTime!,
              onTimeChanged: (newTime) => setState(() => _endTime = newTime),
            )
          else
            // Si el evento está en curso pero lo abren en edición, permitimos ponerle fin
            OutlinedButton.icon(
              onPressed: () => setState(() => _endTime = DateTime.now()),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Asignar hora de fin (Detener)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          if (!isValid)
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Text('La hora de fin no puede ser anterior a la de inicio', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
        
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Izquierdo', label: Text('Izquierdo')),
            ButtonSegment(value: 'Ambos', label: Text('Ambos')),
            ButtonSegment(value: 'Derecho', label: Text('Derecho')),
          ],
          selected: {_side},
          onSelectionChanged: (set) => setState(() => _side = set.first),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notas',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isValid ? () {
              widget.onSave({
                'type': 'breast',
                'side': _side,
                'notes': _notes.text,
              }, _startTime, _endTime);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isEditing 
                  ? (isValid ? Colors.indigo : Colors.grey) 
                  : Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              widget.isEditing ? 'Guardar cambios' : 'Guardar Toma', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        ),
      ],
    );
  }
}