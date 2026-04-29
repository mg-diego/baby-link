import 'package:flutter/material.dart';
import 'package:app/core/widgets/custom_time_picker.dart';

class BasicNotesForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const BasicNotesForm({
    super.key,
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<BasicNotesForm> createState() => _BasicNotesFormState();
}

class _BasicNotesFormState extends State<BasicNotesForm> {
  late DateTime _time;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        const SizedBox(height: 12),
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
            onPressed: () => widget.onSave({'notes': _notes.text}, _time),
            child: const Text('Guardar cambios', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}