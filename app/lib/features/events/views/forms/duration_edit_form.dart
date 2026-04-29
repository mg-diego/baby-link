import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class DurationEditForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime, DateTime?) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime initialStartTime;
  final DateTime? initialEndTime;

  const DurationEditForm({
    super.key,
    required this.onSave,
    required this.initialStartTime,
    this.initialEndTime,
    this.initialMetadata,
  });

  @override
  State<DurationEditForm> createState() => _DurationEditFormState();
}

class _DurationEditFormState extends State<DurationEditForm> {
  late DateTime _startTime;
  late DateTime? _endTime;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _endTime == null || !_endTime!.isBefore(_startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hora de inicio:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        CustomTimePicker(
          time: _startTime,
          onTimeChanged: (newTime) => setState(() => _startTime = newTime),
        ),
        const SizedBox(height: 16),
        const Text('Hora de fin:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_endTime != null)
          CustomTimePicker(
            time: _endTime!,
            onTimeChanged: (newTime) => setState(() => _endTime = newTime),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Evento en curso', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        if (!isValid)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text('La hora de fin no puede ser anterior a la de inicio', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        const SizedBox(height: 16),
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
              final Map<String, dynamic> metadata = Map.from(widget.initialMetadata ?? {});
              metadata['notes'] = _notes.text;
              widget.onSave(metadata, _startTime, _endTime);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.indigo : Colors.grey,
            ),
            child: const Text('Guardar cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}