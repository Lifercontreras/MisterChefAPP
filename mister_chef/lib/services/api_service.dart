import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Excepción personalizada lanzada por [ApiService] cuando la API
/// responde con un código de error HTTP o cuando ocurre un problema de red.
///
/// El campo [statusCode] es nulo si el error es de conectividad (sin internet,
/// timeout) y contiene el código HTTP en caso contrario.
class ApiException implements Exception {
  /// Mensaje descriptivo del error, listo para mostrar al usuario.
  final String message;
  /// Código de estado HTTP asociado al error, o null si es un error de red.
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Servicio HTTP centralizado para comunicarse con la API REST de Laravel.
///
/// Implementa el patrón **Singleton** para reutilizar la misma instancia
/// en toda la aplicación y evitar conexiones duplicadas.
///
/// Características:
/// - Adjunta automáticamente el token Bearer a cada petición autenticada.
/// - Convierte las respuestas de error en [ApiException] con mensajes claros.
/// - Gestiona errores de red (sin internet, timeout) de forma uniforme.
/// - Soporta los métodos HTTP: GET, POST, PUT, PATCH y DELETE.
///
/// Uso:
/// ```dart
/// final api = ApiService();
/// final data = await api.get('/products');
/// ```
class ApiService {
  // ── Instancia única (Singleton)
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Recupera el token de autenticación guardado en [SharedPreferences].
  ///
  /// Devuelve `null` si el usuario no ha iniciado sesión.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAuthToken);
  }

  /// Construye los encabezados HTTP comunes para todas las peticiones.
  ///
  /// Si [auth] es `true` (valor por defecto), agrega el encabezado
  /// `Authorization: Bearer <token>` necesario para endpoints protegidos.
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

  /// Valida la respuesta HTTP y lanza [ApiException] si el servidor
  /// devolvió un código de error.
  ///
  /// Convierte los códigos HTTP estándar en mensajes de usuario en español:
  /// - 401 → Credenciales inválidas.
  /// - 403 → Sin permiso para la acción.
  /// - 404 → Recurso no encontrado.
  /// - 422 → Error de validación (muestra el primer mensaje del servidor).
  /// - 500 → Error interno del servidor.
  dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final msg = body['message'] ?? 'Error desconocido';
    switch (res.statusCode) {
      case 401: throw ApiException(msg.toString(), statusCode: 401);
      case 403: throw ApiException('No tienes permiso para esta acción.',      statusCode: 403);
      case 404: throw ApiException('Recurso no encontrado.',                   statusCode: 404);
      case 422:
        // Extrae el primer mensaje de validación devuelto por Laravel.
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

  /// Realiza una petición HTTP GET al [endpoint] indicado.
  ///
  /// [query] permite pasar parámetros de consulta opcionales (query string).
  /// Si [auth] es false, la petición no incluye el token de autenticación.
  ///
  /// Lanza [ApiException] en caso de error de red o respuesta no exitosa.
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

  /// Realiza una petición HTTP POST al [endpoint] con el [body] como JSON.
  ///
  /// Se usa para crear recursos (facturas, clientes, empleados, etc.)
  /// y para acciones como login o logout.
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

  /// Realiza una petición HTTP PUT al [endpoint] para reemplazar un recurso completo.
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

  /// Realiza una petición HTTP PATCH al [endpoint] para actualizar
  /// parcialmente un recurso (ej. cambiar estado, confirmar factura).
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

  /// Realiza una petición HTTP DELETE al [endpoint] para eliminar un recurso.
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
