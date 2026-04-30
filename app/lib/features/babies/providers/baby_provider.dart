import 'package:app/features/auth/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../api/api_service.dart';

final babyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  
  if (user == null) {
    return null;
  }

  final babies = await ApiService.getBabies(user.id);
  
  if (babies.isNotEmpty) {
    return babies[0] as Map<String, dynamic>;
  }
  
  return null;
});