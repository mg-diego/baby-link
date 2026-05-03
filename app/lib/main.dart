import 'package:app/features/auth/widgets/auth_wrapper.dart';
import 'package:app/features/widgets/widget_config_screen.dart';
import 'package:app/features/widgets/widget_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  if (!kIsWeb) {
    try {
      const platform = MethodChannel('widget_config');
      final widgetId = await platform.invokeMethod<int>('getWidgetId');

      if (widgetId != null && widgetId != 0) {
        runApp(
          MaterialApp(
            home: WidgetConfigScreen(widgetId: widgetId),
            debugShowCheckedModeBanner: false,
          ),
        );
        return;
      }
    } catch (_) {}
  }

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  if (!kIsWeb) {
    try {
      await HomeWidget.registerInteractivityCallback(backgroundCallback);
    } catch (_) {}
  }
  runApp(const ProviderScope(child: BabyLinkApp()));
}

class BabyLinkApp extends ConsumerWidget {
  const BabyLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BabyLink MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7643),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7643),
          brightness: Brightness.dark,
          background: const Color(0xFF121212),
          surface: const Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}
