import 'package:app/features/auth/services/auth_provider.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/babies/views/baby_form_screen.dart';
import 'package:app/features/events/views/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

        final babyAsync = ref.watch(babyProvider);

        return babyAsync.when(
          data: (baby) => baby == null 
              ? const BabyFormScreen() 
              : MainScreen(baby: baby),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
        );
      },
      loading: () {
        final initialSession = Supabase.instance.client.auth.currentSession;
        
        if (initialSession != null) {
          final babyAsync = ref.watch(babyProvider);

          return babyAsync.when(
            data: (baby) => baby == null 
                ? const BabyFormScreen() 
                : MainScreen(baby: baby),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
          );
        }
        
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}