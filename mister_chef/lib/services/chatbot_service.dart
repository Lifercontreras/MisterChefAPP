import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'api_service.dart';

class ChatbotService {
  Future<String> sendMessage(String message,
      {double? latitude, double? longitude}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAuthToken);

      final body = <String, dynamic>{'message': message};
      if (latitude != null)  body['latitude']  = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointChatbot}'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60)); // ← timeout largo para IA

      final data = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data['response']?.toString() ?? 'Sin respuesta';
      }
      return 'Error: ${data['message'] ?? 'Error desconocido'}';
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El asistente tardó demasiado. Intenta de nuevo.');
    }
  }
}