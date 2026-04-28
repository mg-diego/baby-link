import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class WakeUpForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;

  const WakeUpForm({required this.onSave});

  @override
  State<WakeUpForm> createState() => WakeUpFormState();
}

class WakeUpFormState extends State<WakeUpForm> {
  DateTime _time = DateTime.now();
  String? _mood;
  String? _ended;
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        DropdownButtonFormField<String>(
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
            child: const Text('Guardar', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
