import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import 'api_service.dart';

/// Error controlado cuando falta la clave de Google Directions.
///
/// Permite a la interfaz mostrar un mensaje claro en lugar de fallar en
/// silencio cuando el build no define `DIRECTIONS_API_KEY`.
class DirectionsApiKeyMissingException implements Exception {
  const DirectionsApiKeyMissingException();

  @override
  String toString() =>
      'Falta DIRECTIONS_API_KEY. Compila con '
      '--dart-define=DIRECTIONS_API_KEY=... o '
      '--dart-define-from-file=env/prod.json';
}

/// Servicio de gestión de rutas de entrega en Mister Chef.
///
/// Cubre tres áreas:
/// - **Paradas del vendedor**: obtener, actualizar estado y eliminar paradas.
/// - **Administración**: distribuir rutas entre vendedores, aprobar/rechazar
///   sugerencias y ver ubicaciones activas en tiempo real.
/// - **Google Maps**: calcular y decodificar polilíneas de navegación
///   usando la API de Routes de Google.
class RouteService {
  /// Crea el servicio.
  ///
  /// [client] y [apiKey] son opcionales y existen para las pruebas: la app
  /// los omite y se usan un `http.Client()` nuevo y
  /// [AppConstants.directionsApiKey].
  RouteService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? AppConstants.directionsApiKey;

  static const String _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  static const String _routesFieldMask =
      'routes.polyline.encodedPolyline,'
      'routes.distanceMeters,'
      'routes.duration';

  static const String _noRouteMessage =
      'No se encontró una ruta entre el origen y el destino.';

  final _api = ApiService();
  final http.Client _client;
  final String _apiKey;

  /// Obtiene las paradas de entrega asignadas al vendedor para el día.
  ///
  /// Cada parada incluye el cliente, dirección, coordenadas y estado
  /// (pendiente, en camino, completada).
  Future<List<Map<String, dynamic>>> getStops() async {
    final res = await _api.get(AppConstants.endpointRoutes);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Alias de [getStops] para compatibilidad con `route_screen.dart`.
  Future<List<Map<String, dynamic>>> getRoutes() async {
    final res = await _api.get(AppConstants.endpointRoutes);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene los datos de navegación hacia el cliente identificado por [clientId].
  ///
  /// Retorna la dirección, coordenadas destino y, opcionalmente, una
  /// polilínea precalculada por el servidor.
  Future<Map<String, dynamic>> navigateToClient(String clientId) async {
    final res = await _api.get(
      '${AppConstants.endpointRoutes}/navigate/$clientId',
    );
    return Map<String, dynamic>.from(res);
  }

  /// Alias de [navigateToClient] para compatibilidad con `route_screen.dart`.
  Future<Map<String, dynamic>> getClientNavigation(String clientId) async {
    final res = await _api.get(
      '${AppConstants.endpointRoutes}/navigate/$clientId',
    );
    return Map<String, dynamic>.from(res);
  }

  /// Elimina una parada de la ruta del vendedor por su [id].
  Future<void> deleteRoute(String id) async {
    await _api.delete('${AppConstants.endpointRoutes}/$id');
  }

  /// Actualiza el estado de una parada de entrega.
  ///
  /// [estado] puede ser: 'P' (pendiente), 'E' (en camino), 'C' (completada).
  Future<Map<String, dynamic>> updateStopStatus(
    String id,
    String estado,
  ) async {
    final res = await _api.patch('${AppConstants.endpointRoutes}/$id', {
      'status': estado,
    });
    return Map<String, dynamic>.from(res);
  }

  /// Distribuye automáticamente las rutas del día entre los vendedores activos.
  ///
  /// Solo disponible para administradores. El servidor asigna clientes
  /// a cada vendedor según su zona y carga de trabajo.
  Future<Map<String, dynamic>> distributeRoutes() async {
    final res = await _api.post(
      '${AppConstants.endpointRoutes}/distribute',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  /// Obtiene las sugerencias de cambio de ruta enviadas por los vendedores.
  ///
  /// Los vendedores pueden proponer modificaciones a su ruta asignada;
  /// el administrador las aprueba o rechaza desde esta lista.
  Future<List<Map<String, dynamic>>> getRouteSuggestions() async {
    final res = await _api.get(AppConstants.endpointRouteSuggestions);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene las ubicaciones GPS activas de todos los vendedores.
  ///
  /// Solo disponible para administradores. Usado en el mapa de entrega
  /// en tiempo real ([DeliveryMapScreen]).
  Future<List<Map<String, dynamic>>> getActiveLocations() async {
    final res = await _api.get(AppConstants.endpointLocation);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Aprueba una sugerencia de cambio de ruta por su [id].
  ///
  /// El servidor reasigna la parada según la sugerencia aprobada.
  Future<Map<String, dynamic>> approveSuggestion(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointRouteSuggestions}/$id/approve',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  /// Rechaza una sugerencia de cambio de ruta por su [id].
  ///
  /// [documentEmployee] identifica al vendedor que hizo la sugerencia
  /// para notificarle del rechazo.
  Future<Map<String, dynamic>> rejectSuggestion(
    String id,
    String documentEmployee,
  ) async {
    final res = await _api.patch(
      '${AppConstants.endpointRouteSuggestions}/$id/reject',
      {'document_employee': documentEmployee},
    );
    return Map<String, dynamic>.from(res);
  }

  // ── INTEGRACIÓN CON GOOGLE MAPS ─────────────────────────────────────────

  /// Obtiene la polilínea de navegación entre dos puntos usando Google Routes.
  ///
  /// Retorna una lista de coordenadas `{lat, lng}` que forman el trazo de la
  /// ruta en carretera para dibujarla sobre el mapa. Llama a la API de Routes
  /// (`computeRoutes`) y decodifica la polilínea codificada de la respuesta.
  ///
  /// Lanza [DirectionsApiKeyMissingException] si no hay key configurada y
  /// [ApiException] si Google rechaza la petición, no devuelve rutas o falla
  /// la red.
  Future<List<Map<String, double>>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // Fallo controlado y explícito: la UI muestra este mensaje al usuario.
    if (_apiKey.isEmpty) {
      throw const DirectionsApiKeyMissingException();
    }

    final body = jsonEncode({
      'origin': {
        'location': {
          'latLng': {'latitude': originLat, 'longitude': originLng},
        },
      },
      'destination': {
        'location': {
          'latLng': {'latitude': destLat, 'longitude': destLng},
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_UNAWARE',
      'polylineEncoding': 'ENCODED_POLYLINE',
    });

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_routesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': _routesFieldMask,
            },
            body: body,
          )
          .timeout(AppConstants.connectTimeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    }

    if (res.statusCode != 200) {
      throw ApiException(_googleErrorMessage(res), statusCode: res.statusCode);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(_noRouteMessage);
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw ApiException(_noRouteMessage);
    }

    final first = routes.first;
    final polyline = first is Map ? first['polyline'] : null;
    final encoded = polyline is Map ? polyline['encodedPolyline'] : null;

    if (encoded is! String || encoded.isEmpty) {
      throw ApiException(_noRouteMessage);
    }

    return _decodePolyline(encoded);
  }

  /// Extrae el mensaje de error de Google sin exponer la API key.
  ///
  /// Si el cuerpo no es JSON o no trae `error.message`, devuelve un mensaje
  /// genérico con el código HTTP.
  String _googleErrorMessage(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString().trim();
          final status = error['status']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            if (status != null && status.isNotEmpty) {
              return 'No se pudo calcular la ruta ($status): $message';
            }
            return 'No se pudo calcular la ruta: $message';
          }
        }
      }
    } catch (_) {
      // El cuerpo no es JSON: se usa el mensaje genérico de abajo.
    }
    return 'No se pudo calcular la ruta (código ${res.statusCode}).';
  }

  /// Decodifica una polilínea codificada de Google (formato Encoded Polyline).
  ///
  /// Algoritmo estándar de Google: interpreta pares de enteros comprimidos
  /// en base64 modificado para reconstruir coordenadas lat/lng. Es el único
  /// decodificador del servicio y alimenta directamente el mapa.
  List<Map<String, double>> _decodePolyline(String encoded) {
    final List<Map<String, double>> points = [];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      // Decodifica la latitud.
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      // Decodifica la longitud.
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      // Divide entre 1e5 para obtener las coordenadas reales.
      points.add({'lat': lat / 1e5, 'lng': lng / 1e5});
    }
    return points;
  }
}
