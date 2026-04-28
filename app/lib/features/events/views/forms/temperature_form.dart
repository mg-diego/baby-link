import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class TemperatureForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  const TemperatureForm({required this.onSave});
  @override
  State<TemperatureForm> createState() => TemperatureFormState();
}

class TemperatureFormState extends State<TemperatureForm> {
  DateTime _time = DateTime.now();
  double _temp = 36.5;
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
            child: const Text(
              'Guardar Temperatura',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
