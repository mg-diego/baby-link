import 'package:flutter/material.dart';
import 'package:app/shared/widgets/custom_time_picker.dart';

class GrowthForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime? initialTime;

  const GrowthForm({
    super.key,
    required this.onSave,
    this.initialMetadata,
    this.initialTime,
  });

  @override
  State<GrowthForm> createState() => _GrowthFormState();
}

class _GrowthFormState extends State<GrowthForm> {
  late DateTime _time;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _head;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime ?? DateTime.now();
    _height = TextEditingController(text: widget.initialMetadata?['height_cm']?.toString() ?? '');
    _weight = TextEditingController(text: widget.initialMetadata?['weight_kg']?.toString() ?? '');
    _head = TextEditingController(text: widget.initialMetadata?['head_cm']?.toString() ?? '');
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _head.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _height.text.trim().isNotEmpty ||
           _weight.text.trim().isNotEmpty ||
           _head.text.trim().isNotEmpty;
  }

  void _onFieldChanged(String _) {
    setState(() {});
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
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onFieldChanged,
                decoration: const InputDecoration(
                  labelText: 'Altura',
                  suffixText: 'cm',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onFieldChanged,
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _head,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _onFieldChanged,
          decoration: const InputDecoration(
            labelText: 'Perímetro craneal',
            suffixText: 'cm',
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
            onPressed: _isValid ? () {
              final meta = <String, dynamic>{
                'notes': _notes.text,
              };

              if (_height.text.isNotEmpty) {
                meta['height_cm'] = double.tryParse(_height.text.replaceAll(',', '.')) ?? 0.0;
              }
              if (_weight.text.isNotEmpty) {
                meta['weight_kg'] = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0.0;
              }
              if (_head.text.isNotEmpty) {
                meta['head_cm'] = double.tryParse(_head.text.replaceAll(',', '.')) ?? 0.0;
              }

              widget.onSave(meta, _time);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEditing
                  ? (_isValid ? Colors.indigo : Colors.grey)
                  : (_isValid ? Theme.of(context).colorScheme.primary : Colors.grey),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isEditing ? 'Guardar cambios' : 'Guardar Crecimiento',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}