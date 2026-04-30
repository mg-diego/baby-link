import 'package:app/features/auth/services/auth_provider.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../api/api_service.dart';

class BabyFormScreen extends ConsumerStatefulWidget {
  const BabyFormScreen({super.key});

  @override
  ConsumerState<BabyFormScreen> createState() => _BabyFormScreenState();
}

class _BabyFormScreenState extends ConsumerState<BabyFormScreen> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _saveBaby() async {
    final user = ref.read(currentUserProvider);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró sesión activa')),
        );
      }
      return;
    }

    try {
      final dob = _selectedDate.toIso8601String().split('T')[0];
      
      final newId = await ApiService.registerBaby(
        _nameController.text,
        dob,
        user.id,
      );
      
      ref.invalidate(babyProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bebé guardado con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
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