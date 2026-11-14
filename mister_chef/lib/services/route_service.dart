import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import 'api_service.dart';

/// Servicio de gestión de rutas de entrega en Mister Chef.
///
/// Cubre tres áreas:
/// - **Paradas del vendedor**: obtener, actualizar estado y eliminar paradas.
/// - **Administración**: previsualizar y aplicar la redistribución de clientes
///   entre vendedores, y ver ubicaciones activas en tiempo real.
/// - **Rutas en carretera**: calcular y decodificar polilíneas de navegación
///   con el servidor público OSRM de OpenStreetMap, sin clave de API.
///
/// OSRM es gratuito para uso razonable y no comercial, pero no garantiza
/// disponibilidad y limita las peticiones a una por segundo. El servicio
/// identifica el tráfico de la app con [_userAgent]; la interfaz muestra la
/// atribución «Rutas © OpenStreetMap · OSRM».
class RouteService {
  /// Crea el servicio.
  ///
  /// [client] es opcional y existe para las pruebas: la app lo omite y se
  /// usa un `http.Client()` nuevo.
  RouteService({http.Client? client}) : _client = client ?? http.Client();

  /// URL base del servidor público de OSRM (perfil de conducción).
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Identificación que exige la política de uso del servidor público.
  static const String _userAgent =
      'LogiGo-MisterChef/0.1 (proyecto academico)';

  static const String _noRouteMessage =
      'No se encontró una ruta entre el origen y el destino.';

  final _api = ApiService();
  final http.Client _client;

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

  /// Calcula la vista previa de la redistribución TOTAL de clientes.
  ///
  /// Solo disponible para administradores. No escribe nada en el servidor:
  /// devuelve el reparto propuesto, el resumen y un `fingerprint` que debe
  /// enviarse a [applyDistribution] para confirmar exactamente ese reparto.
  Future<Map<String, dynamic>> previewDistribution() async {
    final res = await _api.post(
      AppConstants.endpointRouteDistributionPreview,
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  /// Aplica la redistribución previamente calculada con [fingerprint].
  ///
  /// Solo disponible para administradores. Si los datos cambiaron desde la
  /// vista previa, el servidor responde 409 y no escribe nada: hay que
  /// recalcular con [previewDistribution].
  Future<Map<String, dynamic>> applyDistribution(String fingerprint) async {
    final res = await _api.post(
      AppConstants.endpointRouteDistributionApply,
      {'fingerprint': fingerprint},
    );
    return Map<String, dynamic>.from(res);
  }

  /// Obtiene las ubicaciones GPS activas de todos los vendedores.
  ///
  /// Solo disponible para administradores. Usado en el mapa de entrega
  /// en tiempo real ([DeliveryMapScreen]).
  Future<List<Map<String, dynamic>>> getActiveLocations() async {
    final res = await _api.get(AppConstants.endpointLocation);
    return List<Map<String, dynamic>>.from(res);
  }

  // ── INTEGRACIÓN CON OSRM / OPENSTREETMAP ────────────────────────────────

  /// Obtiene la polilínea de la ruta en carretera que une [waypoints].
  ///
  /// [waypoints] debe traer al menos dos puntos `{lat, lng}` en el orden en
  /// que se quiere recorrer la ruta. Retorna la geometría decodificada como
  /// una lista de coordenadas `{lat, lng}` lista para dibujar en el mapa.
  ///
  /// Usa el servidor público de OSRM, que recibe las coordenadas como
  /// `longitud,latitud` separadas por `;`. Lanza [ApiException] si faltan
  /// puntos, el servidor limita las peticiones (HTTP 429), responde un error
  /// HTTP, no devuelve una ruta o falla la red.
  Future<List<Map<String, double>>> getRoadRoute(
    List<Map<String, double>> waypoints,
  ) async {
    if (waypoints.length < 2) {
      throw ApiException(
        'Se necesitan al menos dos puntos para calcular la ruta.',
      );
    }

    // OSRM exige longitud,latitud (al revés que la app) y 6 decimales.
    final coordinates = waypoints
        .map(
          (point) =>
              '${point['lng']!.toStringAsFixed(6)},'
              '${point['lat']!.toStringAsFixed(6)}',
        )
        .join(';');

    final uri = Uri.parse('$_osrmBaseUrl/$coordinates').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'polyline',
      },
    );

    final http.Response res;
    try {
      res = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(AppConstants.connectTimeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado.');
    } on http.ClientException {
      throw ApiException('Sin conexión a internet.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    }

    if (res.statusCode == 429) {
      throw ApiException(
        'Demasiadas solicitudes de ruta. Intenta de nuevo en unos segundos.',
        statusCode: 429,
      );
    }
    if (res.statusCode != 200) {
      throw ApiException(
        'No se pudo calcular la ruta (código ${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is! Map<String, dynamic> || decoded['code'] != 'Ok') {
      throw ApiException(_noRouteMessage);
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw ApiException(_noRouteMessage);
    }

    final first = routes.first;
    final encoded = first is Map ? first['geometry'] : null;

    if (encoded is! String || encoded.isEmpty) {
      throw ApiException(_noRouteMessage);
    }

    final points = _decodePolyline(encoded);
    if (points.isEmpty) {
      throw ApiException(_noRouteMessage);
    }
    return points;
  }

  /// Calcula la ruta en carretera entre dos puntos concretos.
  ///
  /// Se mantiene con la misma firma de siempre para no tocar a sus
  /// llamadores; por dentro delega en [getRoadRoute].
  Future<List<Map<String, double>>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    return getRoadRoute([
      {'lat': originLat, 'lng': originLng},
      {'lat': destLat, 'lng': destLng},
    ]);
  }

  /// Decodifica una polilínea en formato Encoded Polyline (precisión 5).
  ///
  /// Es el formato que devuelve OSRM con `geometries=polyline`: pares de
  /// enteros comprimidos en base64 modificado que reconstruyen coordenadas
  /// lat/lng. Si la cadena está truncada, devuelve los puntos completos que
  /// haya podido reconstruir para no romper el mapa.
  List<Map<String, double>> _decodePolyline(String encoded) {
    final List<Map<String, double>> points = [];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      // Decodifica la latitud.
      int shift = 0, result = 0, b;
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      // Decodifica la longitud.
      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) return points;
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
