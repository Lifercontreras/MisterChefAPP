import '../config/constants.dart';
import 'api_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// Servicio de gestión de rutas de entrega en Mister Chef.
///
/// Cubre tres áreas:
/// - **Paradas del vendedor**: obtener, actualizar estado y eliminar paradas.
/// - **Administración**: distribuir rutas entre vendedores, aprobar/rechazar
///   sugerencias y ver ubicaciones activas en tiempo real.
/// - **Google Maps**: calcular y decodificar polilíneas de navegación
///   usando la API de Google Directions.
class RouteService {
  final _api = ApiService();

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
    final res = await _api.get('${AppConstants.endpointRoutes}/navigate/$clientId');
    return Map<String, dynamic>.from(res);
  }

  /// Alias de [navigateToClient] para compatibilidad con `route_screen.dart`.
  Future<Map<String, dynamic>> getClientNavigation(String clientId) async {
    final res = await _api.get(
        '${AppConstants.endpointRoutes}/navigate/$clientId');
    return Map<String, dynamic>.from(res);
  }

  /// Elimina una parada de la ruta del vendedor por su [id].
  Future<void> deleteRoute(String id) async {
    await _api.delete('${AppConstants.endpointRoutes}/$id');
  }

  /// Actualiza el estado de una parada de entrega.
  ///
  /// [estado] puede ser: 'P' (pendiente), 'E' (en camino), 'C' (completada).
  Future<Map<String, dynamic>> updateStopStatus(String id, String estado) async {
    final res = await _api.patch(
      '${AppConstants.endpointRoutes}/$id',
      {'status': estado},
    );
    return Map<String, dynamic>.from(res);
  }

  /// Distribuye automáticamente las rutas del día entre los vendedores activos.
  ///
  /// Solo disponible para administradores. El servidor asigna clientes
  /// a cada vendedor según su zona y carga de trabajo.
  Future<Map<String, dynamic>> distributeRoutes() async {
    final res = await _api.post('${AppConstants.endpointRoutes}/distribute', {});
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
      '${AppConstants.endpointRouteSuggestions}/$id/approve', {});
    return Map<String, dynamic>.from(res);
  }

  /// Rechaza una sugerencia de cambio de ruta por su [id].
  ///
  /// [documentEmployee] identifica al vendedor que hizo la sugerencia
  /// para notificarle del rechazo.
  Future<Map<String, dynamic>> rejectSuggestion(
      String id, String documentEmployee) async {
    final res = await _api.patch(
      '${AppConstants.endpointRouteSuggestions}/$id/reject',
      {'document_employee': documentEmployee},
    );
    return Map<String, dynamic>.from(res);
  }

  // ── INTEGRACIÓN CON GOOGLE MAPS ─────────────────────────────────────────

  /// Obtiene la polilínea de navegación entre dos puntos usando Google Directions.
  ///
  /// Retorna una lista de coordenadas `{lat, lng}` que forman el trazo de la
  /// ruta en carretera para dibujarla sobre el mapa. Usa la librería
  /// `flutter_polyline_points` para llamar a la API de Google.
  ///
  /// Retorna lista vacía si no hay conexión o la API no devuelve puntos.
  Future<List<Map<String, double>>> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final polylinePoints = PolylinePoints();

      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: AppConstants.googleMapsApiKey,
        request: PolylineRequest(
          origin:      PointLatLng(originLat, originLng),
          destination: PointLatLng(destLat,   destLng),
          mode:        TravelMode.driving, // Ruta en vehículo.
        ),
      );

      if (result.points.isEmpty) return [];

      // Convierte los puntos al formato de mapa utilizado por el widget de mapa.
      return result.points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
    } catch (_) {
      return []; // Falla silenciosa: el mapa se muestra sin polilínea.
    }
  }

  /// Decodifica una polilínea codificada de Google (formato Encoded Polyline).
  ///
  /// Algoritmo estándar de Google: interpreta pares de enteros comprimidos
  /// en base64 modificado para reconstruir coordenadas lat/lng.
  ///
  /// Uso interno como alternativa cuando la API de Google devuelve la
  /// polilínea codificada directamente en lugar de puntos decodificados.
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
      shift = 0; result = 0;
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
