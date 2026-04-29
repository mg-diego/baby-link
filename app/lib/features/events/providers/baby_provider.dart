import 'package:app/features/auth/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final babyIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('babies')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (response != null) {
    return response['id'] as String;
  }
  return null;
});