import 'dart:convert';
import 'dart:developer' as developer;

import 'package:app/features/analytics/models/daily_summary.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';

/// Cliente de la API. Todas las respuestas tienen la forma `{status, data}`.
class ApiService {
  // ─── Infraestructura ───────────────────────────────────────────────────────

  /// Cabeceras comunes: la API exige el access token de Supabase del usuario.
  static Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session != null && session.isExpired) {
        session = (await auth.refreshSession()).session;
      }
      final token = session?.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    } catch (_) {
      // Supabase sin inicializar (tests) o sin red para refrescar: se envía sin
      // token y la API responderá 401.
    }
    return headers;
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConstants.apiUrl}$path').replace(queryParameters: query);

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static dynamic _decode(http.Response response) => jsonDecode(utf8.decode(response.bodyBytes));

  /// Campo `data` de una respuesta 200, o excepción con el `detail` de la API.
  static dynamic _data(http.Response response, String what) {
    if (response.statusCode == 204) return null;
    if (response.statusCode == 200 || response.statusCode == 201) {
      return _decode(response)['data'];
    }
    String detail = 'HTTP ${response.statusCode}';
    try {
      detail = _decode(response)['detail']?.toString() ?? detail;
    } catch (_) {}
    throw Exception('$what: $detail');
  }

  static void _log(String message) => developer.log(message, name: 'ApiService');

  // ─── Bebés ─────────────────────────────────────────────────────────────────

  /// El dueño es el usuario de la sesión (lo deduce la API del token).
  static Future<String?> registerBaby(String name, String dob) async {
    final response = await http.post(
      _uri('/babies'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'dob': dob}),
    );
    return _data(response, 'Error al registrar bebé')['id'] as String?;
  }

  /// Bebés del usuario de la sesión.
  static Future<List<dynamic>> getBabies() async {
    final response = await http.get(_uri('/me/babies'), headers: await _headers());
    if (response.statusCode != 200) return [];
    return _decode(response)['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> updateBaby(String babyId, Map<String, dynamic> updateData) async {
    final response = await http.patch(
      _uri('/babies/$babyId'),
      headers: await _headers(),
      body: jsonEncode(updateData),
    );
    return _data(response, 'Error al actualizar bebé') as Map<String, dynamic>;
  }

  // ─── Eventos ───────────────────────────────────────────────────────────────

  /// Devuelve la respuesta completa (`{status, data}`); el id está en `data.id`.
  static Future<Map<String, dynamic>> registerEvent(
    String babyId,
    String category,
    Map<String, dynamic> metadata, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final response = await http.post(
      _uri('/babies/$babyId/events'),
      headers: await _headers(),
      body: jsonEncode({
        'category': category,
        'start_time': (startTime ?? DateTime.now()).toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        'metadata': metadata,
      }),
    );
    _data(response, 'Error al registrar evento');
    return _decode(response) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getActiveEvents(String babyId) async {
    try {
      final response = await http.get(_uri('/babies/$babyId/events/active'), headers: await _headers());
      if (response.statusCode != 200) return [];
      return (_decode(response)['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('Error obteniendo eventos activos: $e');
      return [];
    }
  }

  static Future<List<String>> getValidEventDates(String babyId) async {
    final response = await http.get(_uri('/babies/$babyId/events/dates'), headers: await _headers());
    return List<String>.from(_data(response, 'Error al obtener fechas') as List);
  }

  static Future<Map<String, String?>> getLastEvents(String babyId) async {
    final response = await http.get(_uri('/babies/$babyId/events/last'), headers: await _headers());
    final data = _data(response, 'Error al obtener los últimos eventos') as Map<String, dynamic>;
    return data.map((key, value) => MapEntry(key, value?.toString()));
  }

  static Future<List<Map<String, dynamic>>> getGrowthHistory(String babyId) async {
    final response = await http.get(_uri('/babies/$babyId/growth'), headers: await _headers());
    return (_data(response, 'Error al obtener crecimiento') as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> updateData) async {
    final response = await http.patch(
      _uri('/events/$eventId'),
      headers: await _headers(),
      body: jsonEncode(updateData),
    );
    return _data(response, 'Falló la actualización') as Map<String, dynamic>;
  }

  static Future<void> deleteEvent(String eventId) async {
    final response = await http.delete(_uri('/events/$eventId'), headers: await _headers());
    _data(response, 'Error al borrar el evento');
  }

  static Future<List<dynamic>> getEventsByDateRange(String babyId, DateTime startDate, DateTime endDate) async {
    final response = await http.get(
      _uri('/babies/$babyId/events', {'start_date': _day(startDate), 'end_date': _day(endDate)}),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    return _decode(response)['data'] as List<dynamic>;
  }

  // ─── Análisis ──────────────────────────────────────────────────────────────

  static Future<DailySummary?> getDailySummary(String babyId, DateTime targetDate) async {
    final response = await http.get(
      _uri('/babies/$babyId/summary', {'date': _day(targetDate)}),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    return DailySummary.fromJson(_decode(response)['data'] as Map<String, dynamic>);
  }

  /// Agenda de sueño y despertar previsto en una sola llamada. Con pocos datos
  /// la API responde `insufficient_data` con agenda vacía y sin despertar.
  static Future<({List<dynamic> schedule, Map<String, dynamic>? wake})> getPredictions(String babyId) async {
    final response = await http.get(_uri('/babies/$babyId/predictions'), headers: await _headers());
    if (response.statusCode != 200) return (schedule: <dynamic>[], wake: null);
    final data = _decode(response)['data'] as Map<String, dynamic>;
    final wake = data['wake'];
    return (
      schedule: (data['schedule'] as List?) ?? <dynamic>[],
      wake: wake is Map<String, dynamic> ? wake : null,
    );
  }

  /// Códigos de la API para las etiquetas de la pantalla de estadísticas.
  static const statCategoryCodes = {
    'Sueño': 'sleep',
    'Alimentación': 'feeding',
    'Pañales': 'diapers',
    'Crecimiento': 'growth',
  };
  static const statSubcategoryCodes = {
    'Todo': 'all',
    'Siestas': 'naps',
    'Nocturno': 'night',
    'Despertares': 'wakings',
    'Biberón': 'bottle',
    'Lactancia': 'nursing',
    'Sólidos': 'solids',
    'Mojado': 'wet',
    'Sucio': 'dirty',
    'Peso': 'weight',
    'Altura': 'height',
    'Perímetro': 'head',
  };

  /// Lanza en vez de devolver null para que la pantalla muestre el error en
  /// lugar de un "Sin datos" engañoso.
  static Future<Map<String, dynamic>?> getStats({
    required String babyId,
    required DateTime startDate,
    required DateTime endDate,
    required String category,
    String subcategory = 'Todo',
  }) async {
    final response = await http.get(
      _uri('/babies/$babyId/stats', {
        'start_date': _day(startDate),
        'end_date': _day(endDate),
        'category': statCategoryCodes[category] ?? category,
        'subcategory': statSubcategoryCodes[subcategory] ?? subcategory,
      }),
      headers: await _headers(),
    );
    return _data(response, 'Error al cargar estadísticas') as Map<String, dynamic>?;
  }
}
