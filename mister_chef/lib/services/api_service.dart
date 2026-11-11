import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'auth_service.dart';

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

/// Convierte la respuesta cruda del servidor en datos listos para usar.
///
/// Es una función pura (sin red, sin plugins) para poder probarla de forma
/// aislada. Revisa primero el código de estado y solo después intenta
/// interpretar el body, evitando que un HTML de proxy o un body vacío
/// provoquen un [FormatException] sin contexto.
///
/// Reglas:
/// - `2xx` con body vacío → mapa vacío (operación exitosa sin contenido).
/// - `2xx` con JSON válido → el objeto decodificado.
/// - `429` → mensaje fijo de demasiados intentos.
/// - `5xx` vacío o JSON válido → mensaje genérico de problema del servidor.
/// - Body no vacío que no sea JSON → "Respuesta inesperada del servidor".
/// - `401`, `403`, `404`, `422` y demás errores → mensajes claros,
///   conservando el `message` enviado por el back cuando existe.
dynamic parseApiResponse(int statusCode, String body) {
  final isSuccess = statusCode >= 200 && statusCode < 300;
  final trimmed = body.trim();

  // 2xx sin contenido: la operación fue exitosa pero no hay datos.
  if (isSuccess && trimmed.isEmpty) return <String, dynamic>{};

  // Códigos con un significado claro que no depende del body.
  if (!isSuccess && statusCode == 429) {
    throw ApiException(
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
      statusCode: 429,
    );
  }
  if (!isSuccess && statusCode >= 500 && trimmed.isEmpty) {
    throw ApiException(
      'El servidor tuvo un problema. Inténtalo más tarde.',
      statusCode: statusCode,
    );
  }

  dynamic decoded;
  var parsed = false;
  if (trimmed.isNotEmpty) {
    try {
      decoded = jsonDecode(trimmed);
      parsed = true;
    } catch (_) {
      // El back (o un proxy) devolvió algo que no es JSON.
      parsed = false;
    }
  }

  if (!parsed) {
    throw ApiException(
      'Respuesta inesperada del servidor (código $statusCode)',
      statusCode: statusCode,
    );
  }

  if (isSuccess) return decoded;

  if (statusCode >= 500) {
    throw ApiException(
      'El servidor tuvo un problema. Inténtalo más tarde.',
      statusCode: statusCode,
    );
  }

  final map = decoded is Map<String, dynamic> ? decoded : null;
  final backendMessage = map?['message']?.toString();

  switch (statusCode) {
    case 401:
      throw ApiException(
        backendMessage ?? 'Tu sesión expiró. Inicia sesión de nuevo.',
        statusCode: 401,
      );
    case 403:
      throw ApiException(
        'No tienes permiso para esta acción.',
        statusCode: 403,
      );
    case 404:
      throw ApiException('Recurso no encontrado.', statusCode: 404);
    case 422:
      // Extrae el primer mensaje de validación devuelto por Laravel.
      final errors = map?['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          throw ApiException(first.first.toString(), statusCode: 422);
        }
        throw ApiException(first.toString(), statusCode: 422);
      }
      throw ApiException(
        backendMessage ?? 'Los datos enviados no son válidos.',
        statusCode: 422,
      );
    default:
      throw ApiException(
        backendMessage ?? 'Error desconocido',
        statusCode: statusCode,
      );
  }
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
/// - Detecta sesiones expiradas (401) y avisa una sola vez a la app.
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

  /// Callback que la app registra para reaccionar a una sesión expirada.
  ///
  /// Se dispara una sola vez por sesión hasta que se llame a
  /// [resetUnauthorizedGuard] (por ejemplo, tras un login exitoso).
  static void Function()? onUnauthorized;

  /// Evita que varias peticiones simultáneas redirijan al login repetidamente.
  static bool _unauthorizedHandled = false;

  /// Vuelve a habilitar el aviso de sesión expirada tras un login exitoso.
  static void resetUnauthorizedGuard() {
    _unauthorizedHandled = false;
  }

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
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// Limpia la sesión local y notifica a la app que debe volver al login.
  ///
  /// Es idempotente: si ya se está redirigiendo, las peticiones posteriores
  /// no vuelven a limpiar ni a disparar [onUnauthorized].
  Future<void> handleUnauthorized() async {
    if (_unauthorizedHandled) return;
    _unauthorizedHandled = true;

    try {
      // Reutiliza la limpieza de sesión existente en AuthService.
      await AuthService().clearSession();
    } finally {
      onUnauthorized?.call();
    }
  }

  /// Valida la respuesta HTTP y lanza [ApiException] si el servidor
  /// devolvió un código de error.
  ///
  /// Si el error es un 401 en una petición autenticada, limpia la sesión
  /// y dispara [onUnauthorized] una única vez.
  Future<dynamic> _handle(http.Response res, {bool auth = true}) async {
    try {
      return parseApiResponse(res.statusCode, res.body);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && auth) {
        await handleUnauthorized();
      }
      rethrow;
    }
  }

  /// Realiza una petición HTTP GET al [endpoint] indicado.
  ///
  /// [query] permite pasar parámetros de consulta opcionales (query string).
  /// Si [auth] es false, la petición no incluye el token de autenticación.
  ///
  /// Lanza [ApiException] en caso de error de red o respuesta no exitosa.
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    try {
      var uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      if (query != null) uri = uri.replace(queryParameters: query);
      final res = await http
          .get(uri, headers: await _headers(auth: auth))
          .timeout(AppConstants.connectTimeout);
      return await _handle(res, auth: auth);
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    }
  }

  /// Realiza una petición HTTP POST al [endpoint] con el [body] como JSON.
  ///
  /// Se usa para crear recursos (facturas, clientes, empleados, etc.)
  /// y para acciones como login o logout.
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(AppConstants.connectTimeout);
      return await _handle(res, auth: auth);
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    }
  }

  /// Realiza una petición HTTP PUT al [endpoint] para reemplazar un recurso completo.
  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(AppConstants.connectTimeout);
      return await _handle(res, auth: auth);
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    }
  }

  /// Realiza una petición HTTP PATCH al [endpoint] para actualizar
  /// parcialmente un recurso (ej. cambiar estado, confirmar factura).
  Future<dynamic> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(AppConstants.connectTimeout);
      return await _handle(res, auth: auth);
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    }
  }

  /// Realiza una petición HTTP DELETE al [endpoint] para eliminar un recurso.
  Future<dynamic> delete(String endpoint, {bool auth = true}) async {
    try {
      final res = await http
          .delete(
            Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(AppConstants.connectTimeout);
      return await _handle(res, auth: auth);
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    }
  }
}
