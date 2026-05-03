import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';

final babyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  
  if (user == null) {
    return null;
  }

  final babies = await ApiService.getBabies(user.id);
  
  if (babies.isNotEmpty) {
    return babies.first as Map<String, dynamic>;
  }
  
  return null;
});

final babyIdProvider = Provider<AsyncValue<String?>>((ref) {
  final babyAsyncValue = ref.watch(babyProvider);
  
  return babyAsyncValue.whenData((baby) => baby?['id'] as String?);
});