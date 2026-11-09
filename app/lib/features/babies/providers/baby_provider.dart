import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';

final babyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Solo el id: al renovar el token (p. ej. al volver de la cámara) llega otro
  // objeto User del mismo usuario, y recargar aquí desmontaba toda la app
  // (AuthWrapper muestra la carga) y cerraba lo que hubiera abierto.
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));

  if (userId == null) {
    return null;
  }

  final babies = await ApiService.getBabies();
  
  if (babies.isNotEmpty) {
    return babies.first as Map<String, dynamic>;
  }
  
  return null;
});

final babyIdProvider = Provider<AsyncValue<String?>>((ref) {
  final babyAsyncValue = ref.watch(babyProvider);
  
  return babyAsyncValue.whenData((baby) => baby?['id'] as String?);
});