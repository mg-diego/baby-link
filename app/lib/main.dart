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
      title: 'BabyLink',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary:          Color(0xFF4A90D9),
          onPrimary:        Colors.white,
          primaryContainer: Color(0xFFEAF4FF),
          onPrimaryContainer: Color(0xFF0C447C),
          secondary:        Color(0xFF9B7FD4),
          onSecondary:      Colors.white,
          secondaryContainer: Color(0xFFF0EEFF),
          onSecondaryContainer: Color(0xFF3C3489),
          surface:          Color(0xFFFFFFFF),
          onSurface:        Color(0xFF2D3142),
          surfaceContainerHighest: Color(0xFFF0EEFF),
          onSurfaceVariant: Color(0xFF546E7A),
          background:       Color(0xFFFAFBFF),
          onBackground:     Color(0xFF2D3142),
          error:            Color(0xFFE24B4A),
          onError:          Colors.white,
          outline:          Color(0xFFCFD8DC),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary:          Color(0xFF7BB8F0),
          onPrimary:        Color(0xFF0C447C),
          primaryContainer: Color(0xFF1A2B45),
          onPrimaryContainer: Color(0xFFB5D4F4),
          secondary:        Color(0xFFB8A0E8),
          onSecondary:      Color(0xFF26215C),
          secondaryContainer: Color(0xFF242746),
          onSecondaryContainer: Color(0xFFCECBF6),
          surface:          Color(0xFF1A1D2E),
          onSurface:        Color(0xFFE8EAF6),
          surfaceContainerHighest: Color(0xFF242746),
          onSurfaceVariant: Color(0xFF7986CB),
          background:       Color(0xFF0F1222),
          onBackground:     Color(0xFFE8EAF6),
          error:            Color(0xFFF09595),
          onError:          Color(0xFF501313),
          outline:          Color(0xFF2E3250),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1A1D2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1222),
          foregroundColor: Color(0xFFE8EAF6),
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}
