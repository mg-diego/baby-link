import 'package:flutter/material.dart';
import 'package:app/shared/widgets/custom_time_picker.dart';

class BedtimeForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;
  
  const BedtimeForm({
    super.key, 
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });
  
  @override
  State<BedtimeForm> createState() => _BedtimeFormState();
}

class _BedtimeFormState extends State<BedtimeForm> {
  late DateTime _time;
  String? _how;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _how = widget.initialMetadata?['how'];
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
        DropdownButtonFormField<String>(
          value: _how,
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
            child: Text(isEditing ? 'Guardar cambios' : 'Guardar', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}