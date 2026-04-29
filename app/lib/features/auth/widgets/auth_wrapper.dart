import 'package:app/features/auth/services/auth_provider.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/babies/views/baby_form_screen.dart';
import 'package:app/features/events/views/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/login_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        final session = state.session;
        
        if (session == null) {
          return const LoginScreen();
        }

        // Si hay sesión, pasamos al segundo check: ¿Tiene bebé?
        final babyAsync = ref.watch(babyProvider);

        return babyAsync.when(
          data: (baby) => baby == null 
              ? const BabyFormScreen() 
              : MainScreen(baby: baby),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}