import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class BottleForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  
  const BottleForm({super.key, required this.onSave});
  
  @override
  State<BottleForm> createState() => _BottleFormState();
}

class _BottleFormState extends State<BottleForm> {
  DateTime _time = DateTime.now();
  final _amount = TextEditingController();
  String _type = 'Fórmula';
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Fórmula', label: Text('Fórmula')),
            ButtonSegment(value: 'Materna', label: Text('Materna')),
            ButtonSegment(value: 'Otro', label: Text('Otro')),
          ],
          selected: {_type},
          onSelectionChanged: (set) => setState(() => _type = set.first),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad (ml)',
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
            onPressed: () {
              if (_amount.text.isEmpty) return;
              
              widget.onSave({
                'type': 'bottle',
                'milk_type': _type,
                'amount_ml': int.tryParse(_amount.text) ?? 0,
                'notes': _notes.text,
              }, _time);
            },
            child: const Text('Guardar Toma', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}