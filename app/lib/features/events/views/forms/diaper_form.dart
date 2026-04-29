import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class DiaperForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const DiaperForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<DiaperForm> createState() => DiaperFormState();
}

class DiaperFormState extends State<DiaperForm> {
  late DateTime _time;
  late String _condition;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _condition = widget.initialMetadata?['ui_condition'] ?? 'Mojado';
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
        Wrap(
          spacing: 10,
          children: ['Seco', 'Mojado', 'Sucio', 'Variado']
              .map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: _condition == c,
                  onSelected: (_) => setState(() => _condition = c),
                ),
              )
              .toList(),
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
              String backendCond = 'wet';
              if (_condition == 'Sucio') backendCond = 'dirty';
              if (_condition == 'Variado') backendCond = 'mixed';
              if (_condition == 'Seco') backendCond = 'clean';

              widget.onSave({
                'condition': backendCond,
                'ui_condition': _condition,
                'notes': _notes.text,
              }, _time);
            },
            child: Text(isEditing ? 'Guardar cambios' : 'Guardar Pañal', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}