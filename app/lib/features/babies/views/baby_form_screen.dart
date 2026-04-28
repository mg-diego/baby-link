import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../api/api_service.dart';

class BabyFormScreen extends StatefulWidget {
  const BabyFormScreen({super.key});

  @override
  State<BabyFormScreen> createState() => _BabyFormScreenState();
}

class _BabyFormScreenState extends State<BabyFormScreen> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _saveBaby() async {
    try {
      final dob = _selectedDate.toIso8601String().split('T')[0];
      final newId = await ApiService.registerBaby(
        _nameController.text,
        dob,
        AppConstants.hardcodedUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bebé guardado con ID: $newId')),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Bebé')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now()
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              child: Text('Fecha Nac: ${_selectedDate.toLocal()}'.split(' ')[0]),
            ),
            const Spacer(),
            ElevatedButton(onPressed: _saveBaby, child: const Text('Registrar Bebé')),
          ],
        ),
      ),
    );
  }
}