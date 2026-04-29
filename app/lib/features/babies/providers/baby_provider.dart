import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../api/api_service.dart';

final babyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final babies = await ApiService.getBabies(AppConstants.hardcodedUserId);
  
  if (babies.isNotEmpty) {
    return babies[0] as Map<String, dynamic>;
  }
  return null;
});