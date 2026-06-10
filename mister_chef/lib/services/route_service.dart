import '../config/constants.dart';
import 'api_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RouteService {
  final _api = ApiService();

  // GET /api/v1/routes
  Future<List<Map<String, dynamic>>> getStops() async {
    final res = await _api.get(AppConstants.endpointRoutes);
    return List<Map<String, dynamic>>.from(res);
  }

  // GET /api/v1/routes/navigate/{clientId}
  Future<Map<String, dynamic>> navigateToClient(String clientId) async {
    final res = await _api.get('${AppConstants.endpointRoutes}/navigate/$clientId');
    return Map<String, dynamic>.from(res);
  }

  // DELETE /api/v1/routes/{id}
  Future<void> deleteRoute(String id) async {
    await _api.delete('${AppConstants.endpointRoutes}/$id');
  }

  // PATCH /api/v1/routes/{id}
  Future<Map<String, dynamic>> updateStopStatus(String id, String estado) async {
    final res = await _api.patch(
      '${AppConstants.endpointRoutes}/$id',
      {'status': estado},
    );
    return Map<String, dynamic>.from(res);
  }

  // POST /api/v1/routes/distribute
  Future<Map<String, dynamic>> distributeRoutes() async {
    final res = await _api.post('${AppConstants.endpointRoutes}/distribute', {});
    return Map<String, dynamic>.from(res);
  }

  // GET /api/v1/route-suggestions
  Future<List<Map<String, dynamic>>> getRouteSuggestions() async {
    final res = await _api.get(AppConstants.endpointRouteSuggestions);
    return List<Map<String, dynamic>>.from(res);
  }

  // GET /api/v1/location — Admin
  Future<List<Map<String, dynamic>>> getActiveLocations() async {
    final res = await _api.get(AppConstants.endpointLocation);
    return List<Map<String, dynamic>>.from(res);
  }

  // PATCH /api/v1/route-suggestions/{id}/approve
  Future<Map<String, dynamic>> approveSuggestion(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointRouteSuggestions}/$id/approve', {});
    return Map<String, dynamic>.from(res);
  }

  // PATCH /api/v1/route-suggestions/{id}/reject
  Future<Map<String, dynamic>> rejectSuggestion(
      String id, String documentEmployee) async {
    final res = await _api.patch(
      '${AppConstants.endpointRouteSuggestions}/$id/reject',
      {'document_employee': documentEmployee},
    );
    return Map<String, dynamic>.from(res);
  }

  // ── Google Directions API
  // Retorna lista de LatLng para trazar la ruta dentro del mapa
 // ── Google Directions API usando flutter_polyline_points
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
          mode:        TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) return [];

      return result.points
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Decodifica el polyline encoded de Google
  List<Map<String, double>> _decodePolyline(String encoded) {
    final List<Map<String, double>> points = [];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add({'lat': lat / 1e5, 'lng': lng / 1e5});
    }
    return points;
  }
  // Alias de getStops() — usado por route_screen.dart
  Future<List<Map<String, dynamic>>> getRoutes() async {
    final res = await _api.get(AppConstants.endpointRoutes);
    return List<Map<String, dynamic>>.from(res);
  }

  // Alias de navigateToClient() — usado por route_screen.dart
  Future<Map<String, dynamic>> getClientNavigation(String clientId) async {
    final res = await _api.get(
        '${AppConstants.endpointRoutes}/navigate/$clientId');
    return Map<String, dynamic>.from(res);
  }
}