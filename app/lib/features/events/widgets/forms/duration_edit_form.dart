import 'package:app/shared/widgets/custom_time_picker.dart';
import 'package:flutter/material.dart';

class DurationEditForm extends StatefulWidget {
  final Function(Map<String, dynamic>, DateTime, DateTime?) onSave;
  final Map<String, dynamic>? initialMetadata;
  final DateTime initialStartTime;
  final DateTime? initialEndTime;

  const DurationEditForm({
    super.key,
    required this.onSave,
    required this.initialStartTime,
    this.initialEndTime,
    this.initialMetadata,
  });

  @override
  State<DurationEditForm> createState() => _DurationEditFormState();
}

class _DurationEditFormState extends State<DurationEditForm> {
  late DateTime _startTime;
  late DateTime? _endTime;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _notes = TextEditingController(text: widget.initialMetadata?['notes'] ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = (size.width / 400).clamp(0.85, 1.2);
    final isValid = _endTime == null || !_endTime!.isBefore(_startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hora de inicio:', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 * scale),
        ),
        SizedBox(height: 10 * scale),
        CustomTimePicker(
          time: _startTime,
          onTimeChanged: (newTime) => setState(() => _startTime = newTime),
        ),
        SizedBox(height: 20 * scale),
        Text(
          'Hora de fin:', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 * scale),
        ),
        SizedBox(height: 10 * scale),
        if (_endTime != null)
          CustomTimePicker(
            time: _endTime!,
            onTimeChanged: (newTime) => setState(() => _endTime = newTime),
          )
        else
          Container(
            padding: EdgeInsets.symmetric(vertical: 14 * scale),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Text(
              'Evento en curso', 
              style: TextStyle(
                color: Colors.grey.shade600, 
                fontWeight: FontWeight.bold,
                fontSize: 15 * scale,
              ),
            ),
          ),
        if (!isValid)
          Padding(
            padding: EdgeInsets.only(top: 10 * scale, bottom: 4 * scale),
            child: Text(
              'La hora de fin no puede ser anterior a la de inicio', 
              style: TextStyle(color: Colors.red.shade400, fontSize: 13 * scale),
            ),
          ),
        SizedBox(height: 20 * scale),
        TextField(
          controller: _notes,
          style: TextStyle(fontSize: 15 * scale),
          decoration: InputDecoration(
            labelText: 'Notas',
            labelStyle: TextStyle(fontSize: 15 * scale),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16 * scale, 
              vertical: 16 * scale,
            ),
          ),
        ),
        SizedBox(height: 28 * scale),
        SizedBox(
          width: double.infinity,
          height: 52 * scale,
          child: ElevatedButton(
            onPressed: isValid ? () {
              final Map<String, dynamic> metadata = Map.from(widget.initialMetadata ?? {});
              metadata['notes'] = _notes.text;
              widget.onSave(metadata, _startTime, _endTime);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              foregroundColor: isValid ? Theme.of(context).colorScheme.onPrimary : Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * scale),
              ),
              elevation: isValid ? 2 : 0,
            ),
            child: Text(
              'Guardar cambios', 
              style: TextStyle(
                fontSize: 16 * scale, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}