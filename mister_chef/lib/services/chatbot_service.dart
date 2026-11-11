import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'api_service.dart';

/// Servicio del asistente virtual (chatbot) de Mister Chef.
///
/// Usa su propio timeout largo porque las respuestas de IA pueden tardar más
/// que las peticiones normales, pero comparte con [ApiService] el parseo de
/// respuestas y el tratamiento global de sesiones expiradas.
class ChatbotService {
  Future<String> sendMessage(
    String message, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAuthToken);

      final body = <String, dynamic>{'message': message};
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final res = await http
          .post(
            Uri.parse(
              '${AppConstants.apiBaseUrl}${AppConstants.endpointChatbot}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60)); // ← timeout largo para IA

      try {
        final data = parseApiResponse(res.statusCode, res.body);
        if (data is Map<String, dynamic>) {
          return data['response']?.toString() ?? 'Sin respuesta';
        }
        return 'Sin respuesta';
      } on ApiException catch (e) {
        // Mismo tratamiento que el resto de peticiones autenticadas.
        if (e.statusCode == 401) {
          await ApiService().handleUnauthorized();
        }
        rethrow;
      }
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El asistente tardó demasiado. Intenta de nuevo.');
    }
  }
}
