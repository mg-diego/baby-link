import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class DiaperForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  const DiaperForm({required this.onSave});
  @override
  State<DiaperForm> createState() => DiaperFormState();
}

class DiaperFormState extends State<DiaperForm> {
  DateTime _time = DateTime.now();
  String _condition = 'Seco';
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
              widget.onSave({
                'condition': backendCond,
                'ui_condition': _condition,
                'notes': _notes.text,
              }, _time);
            },
            child: const Text('Guardar Pañal', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
