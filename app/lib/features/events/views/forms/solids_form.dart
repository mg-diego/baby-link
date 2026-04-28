import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class SolidsForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  const SolidsForm({required this.onSave});
  @override
  State<SolidsForm> createState() => SolidsFormState();
}

class SolidsFormState extends State<SolidsForm> {
  DateTime _time = DateTime.now();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
            child: const Text(
              'Guardar Sólidos',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
