import 'package:app/shared/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class BottleForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;
  
  const BottleForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });
  
  @override
  State<BottleForm> createState() => _BottleFormState();
}

class _BottleFormState extends State<BottleForm> {
  late DateTime _time;
  late final TextEditingController _amount;
  late String _type;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    final initialAmount = widget.initialMetadata?['amount_ml']?.toString() ?? '';
    _amount = TextEditingController(text: initialAmount == '0' ? '' : initialAmount);
    _type = widget.initialMetadata?['milk_type'] ?? 'Fórmula';
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
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Fórmula', label: Text('Fórmula')),
            ButtonSegment(value: 'Materna', label: Text('Materna')),
            ButtonSegment(value: 'Leche', label: Text('Leche')),
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
            child: Text(isEditing ? 'Guardar cambios' : 'Guardar Toma', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}