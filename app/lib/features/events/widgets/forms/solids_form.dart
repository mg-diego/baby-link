import 'package:app/shared/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class SolidsForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const SolidsForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<SolidsForm> createState() => SolidsFormState();
}

class SolidsFormState extends State<SolidsForm> {
  late DateTime _time;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _amount = TextEditingController(text: widget.initialMetadata?['amount']?.toString() ?? '');
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
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
        TextField(
          controller: _amount,
          decoration: const InputDecoration(
            labelText: 'Cantidad (Opcional)',
            border: OutlineInputBorder(),
          ),
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
              'type': 'solids',
              'amount': _amount.text,
              'notes': _notes.text,
            }, _time),
            child: Text(
              isEditing ? 'Guardar cambios' : 'Guardar Sólidos',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}