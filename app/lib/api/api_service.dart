import 'dart:convert';
import 'package:app/features/analytics/models/daily_summary.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  // BABIES
  static Future<String?> registerBaby(
    String name,
    String dob,
    String userId,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConstants.apiUrl}/babies'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'dob': dob, 'user_id': userId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['data']['id'];
    }
    throw Exception('Error al registrar bebe');
  }

  static Future<List<dynamic>> getBabies(String userId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiUrl}/babies/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    }
    return [];
  }

  //EVENTS
  static Future<Map<String, dynamic>> registerEvent(
    String babyId,
    String category,
    Map<String, dynamic> metadata, {
    DateTime? startTime,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.apiUrl}/events/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'baby_id': babyId,
        'category': category,
        'start_time': (startTime ?? DateTime.now()).toUtc().toIso8601String(),
        'metadata': metadata,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Error al registrar evento (HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveEvents(
    String babyId,
  ) async {
    final url = Uri.parse('${AppConstants.apiUrl}/events/active/$babyId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dataList = decoded['data'] as List;
        return dataList.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo eventos activos: $e');
      return [];
    }
  }

  static Future<List<String>> getValidEventDates(String babyId) async {
    final url = Uri.parse('${AppConstants.apiUrl}/events/valid-dates/$babyId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        final errorMsg =
            jsonDecode(response.body)['detail'] ?? 'Error desconocido';
        throw Exception(errorMsg);
      }

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return List<String>.from(data['dates']);
      } else {
        throw Exception(data['message'] ?? 'Error al obtener fechas');
      }
    } catch (e) {
      print('Error en GET /events/valid-dates/$babyId: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateEvent(
    String eventId,
    Map<String, dynamic> updateData,
  ) async {
    final url = Uri.parse('${AppConstants.apiUrl}/events/$eventId');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        return decodedResponse['data'] as Map<String, dynamic>;
      } else {
        final errorMsg =
            jsonDecode(response.body)['detail'] ?? 'Error desconocido';
        throw Exception('Falló la actualización: $errorMsg');
      }
    } catch (e) {
      print('Error en PATCH /events/$eventId: $e');
      rethrow;
    }
  }

  static Future<void> deleteEvent(String eventId) async {
    final url = Uri.parse('${AppConstants.apiUrl}/events/$eventId');

    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorMsg =
            jsonDecode(response.body)['detail'] ?? 'Error desconocido';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error en DELETE /events/$eventId: $e');
      rethrow;
    }
  }

  // ANALYTICS
  static Future<DailySummary?> getDailySummary(
    String babyId,
    DateTime targetDate,
  ) async {
    final dateStr = targetDate.toIso8601String().split('T')[0];

    final response = await http.get(
      Uri.parse(
        '${AppConstants.apiUrl}/analytics/$babyId/daily-summary?target_date=$dateStr',
      ),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DailySummary.fromJson(data);
    }
    return null;
  }

  static Future<List<dynamic>> getEventsByDateRange(
    String babyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final response = await http.get(
      Uri.parse(
        '${AppConstants.apiUrl}/analytics/$babyId/events?start_date=$startStr&end_date=$endStr',
      ),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : data['data'];
    }
    return [];
  }

  static Future<List<dynamic>> getSleepPredictions(String babyId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiUrl}/analytics/$babyId/sleep-prediction'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : data['data'];
    }
    
    return [];
  }

  static Future<Map<String, dynamic>?> getWakePrediction(String babyId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiUrl}/analytics/$babyId/wake-prediction'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['data'];
    }
    
    return null;
  }
}
