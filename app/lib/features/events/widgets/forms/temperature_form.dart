import 'package:app/shared/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class TemperatureForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const TemperatureForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<TemperatureForm> createState() => TemperatureFormState();
}

class TemperatureFormState extends State<TemperatureForm> {
  late DateTime _time;
  late double _temp;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _temp = (widget.initialMetadata?['celsius'] as num?)?.toDouble() ?? 36.5;
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
        Slider(
          value: _temp,
          min: 35.0,
          max: 42.0,
          divisions: 70,
          label: _temp.toStringAsFixed(1),
          onChanged: (v) => setState(() => _temp = v),
        ),
        Text(
          '${_temp.toStringAsFixed(1)} °C',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            onPressed: () =>
                widget.onSave({'celsius': _temp, 'notes': _notes.text}, _time),
            child: Text(
              isEditing ? 'Guardar cambios' : 'Guardar Temperatura',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}