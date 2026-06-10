import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAuthToken);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body['message'] ?? 'Error desconocido';
    switch (res.statusCode) {
      case 401: throw ApiException('Sesión expirada. Inicia sesión de nuevo.', statusCode: 401);
      case 403: throw ApiException('No tienes permiso para esta acción.',      statusCode: 403);
      case 404: throw ApiException('Recurso no encontrado.',                   statusCode: 404);
      case 422:
        final errors = body['errors'] as Map<String, dynamic>?;
        final first  = errors?.values.first;
        throw ApiException(
          first is List ? first.first.toString() : msg.toString(),
          statusCode: 422,
        );
      case 500: throw ApiException('Error en el servidor. Intenta más tarde.', statusCode: 500);
      default:  throw ApiException(msg.toString(), statusCode: res.statusCode);
    }
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? query, bool auth = true}) async {
    try {
      var uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      if (query != null) uri = uri.replace(queryParameters: query);
      final res = await http.get(uri, headers: await _headers(auth: auth))
          .timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException   { throw ApiException('Sin conexión a internet.'); }
      on TimeoutException  { throw ApiException('El servidor tardó demasiado.'); }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body, {bool auth = true}) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException   { throw ApiException('Sin conexión a internet.'); }
      on TimeoutException  { throw ApiException('El servidor tardó demasiado.'); }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body, {bool auth = true}) async {
    try {
      final res = await http.put(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException   { throw ApiException('Sin conexión a internet.'); }
      on TimeoutException  { throw ApiException('El servidor tardó demasiado.'); }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body, {bool auth = true}) async {
    try {
      final res = await http.patch(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException   { throw ApiException('Sin conexión a internet.'); }
      on TimeoutException  { throw ApiException('El servidor tardó demasiado.'); }
  }

  Future<dynamic> delete(String endpoint, {bool auth = true}) async {
    try {
      final res = await http.delete(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
      ).timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException   { throw ApiException('Sin conexión a internet.'); }
      on TimeoutException  { throw ApiException('El servidor tardó demasiado.'); }
  }
}