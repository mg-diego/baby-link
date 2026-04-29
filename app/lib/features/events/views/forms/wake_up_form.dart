import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class WakeUpForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const WakeUpForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<WakeUpForm> createState() => WakeUpFormState();
}

class WakeUpFormState extends State<WakeUpForm> {
  late DateTime _time;
  String? _mood;
  String? _ended;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _mood = widget.initialMetadata?['mood'];
    _ended = widget.initialMetadata?['ended'];
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialMetadata != null;

    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        DropdownButtonFormField<String>(
          value: _mood,
          decoration: const InputDecoration(
            labelText: 'Estado de ánimo',
            border: OutlineInputBorder(),
          ),
          items: [
            'Mal humor',
            'Neutral',
            'Buen humor',
          ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (val) => setState(() => _mood = val),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _ended,
          decoration: const InputDecoration(
            labelText: 'Fin del sueño',
            border: OutlineInputBorder(),
          ),
          items: [
            'Desperté al bebé',
            'Se despertó solo',
          ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (val) => setState(() => _ended = val),
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
            onPressed: () => widget.onSave({
              'mood': _mood,
              'ended': _ended,
              'notes': _notes.text,
            }, _time),
            child: Text(isEditing ? 'Guardar cambios' : 'Guardar', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}