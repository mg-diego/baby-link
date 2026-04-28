import 'package:flutter/material.dart';
import 'package:app/core/widgets/custom_time_picker.dart';

class BedtimeForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  
  const BedtimeForm({super.key, required this.onSave});
  
  @override
  State<BedtimeForm> createState() => _BedtimeFormState();
}

class _BedtimeFormState extends State<BedtimeForm> {
  DateTime _time = DateTime.now();
  String? _how;
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
          decoration: const InputDecoration(labelText: 'Cómo se durmió', border: OutlineInputBorder()),
          items: ['En la cama', 'Lactancia', 'Sostenido', 'A mi lado', 'Biberón', 'Carrito', 'Automóvil']
              .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (val) => setState(() => _how = val),
        ),
        const SizedBox(height: 15),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => widget.onSave({'how': _how, 'notes': _notes.text}, _time),
            child: const Text('Guardar', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}