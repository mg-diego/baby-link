import 'package:app/core/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class PlaceholderForm extends StatefulWidget {
  final String title;
  final Function(Map<String, dynamic>, DateTime) onSave;
  const PlaceholderForm({required this.title, required this.onSave});
  @override
  State<PlaceholderForm> createState() => PlaceholderFormState();
}

class PlaceholderFormState extends State<PlaceholderForm> {
  DateTime _time = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTimePicker(
          time: _time,
          onTimeChanged: (newTime) => setState(() => _time = newTime),
        ),
        Text('${widget.title} en construcción 🚧'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => widget.onSave({'status': 'placeholder'}, _time),
            child: const Text('Guardar', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
