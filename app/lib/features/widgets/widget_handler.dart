import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/api_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;

  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  } catch (_) {}

  var user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    try {
      final authState =
          await Supabase.instance.client.auth.onAuthStateChange.first;
      user = authState.session?.user;
    } catch (_) {}
  }

  if (user == null) return;

  String? babyId;
  try {
    final babies = await ApiService.getBabies(user.id);
    if (babies.isNotEmpty) {
      babyId = babies[0]['id'] as String?;
    }
  } catch (_) {}

  if (babyId == null) return;

  final category = uri.queryParameters['category'];
  if (category == null) return;

  final metadata = Map<String, dynamic>.from(uri.queryParameters)
    ..remove('category');

  if (metadata.containsKey('amount_ml')) {
    metadata['amount_ml'] = int.tryParse(metadata['amount_ml'].toString()) ?? 0;
  }

  try {
    await ApiService.registerEvent(babyId, category, metadata);
    final widgetIdStr = uri.queryParameters['widgetId'];
    if (widgetIdStr != null) {
      final oldTitle = await HomeWidget.getWidgetData<String>('widget_${widgetIdStr}_title');
      
      if (oldTitle != null) {
        await HomeWidget.saveWidgetData<String>('widget_${widgetIdStr}_title', '✅');
        await HomeWidget.updateWidget(name: 'QuickActionsWidgetProvider');
        
        await Future.delayed(const Duration(seconds: 2));
        
        await HomeWidget.saveWidgetData<String>('widget_${widgetIdStr}_title', oldTitle);
        await HomeWidget.updateWidget(name: 'QuickActionsWidgetProvider');
      }
    }
  } catch (e) {
    print('Error guardando desde widget: $e');

    final widgetIdStr = uri.queryParameters['widgetId'];
    if (widgetIdStr != null) {
      final oldTitle = await HomeWidget.getWidgetData<String>('widget_${widgetIdStr}_title');
      
      if (oldTitle != null) {
        await HomeWidget.saveWidgetData<String>('widget_${widgetIdStr}_title', '❌');
        await HomeWidget.updateWidget(name: 'QuickActionsWidgetProvider');
        
        await Future.delayed(const Duration(seconds: 2));
        
        await HomeWidget.saveWidgetData<String>('widget_${widgetIdStr}_title', oldTitle);
        await HomeWidget.updateWidget(name: 'QuickActionsWidgetProvider');
      }
    }
  }
}
