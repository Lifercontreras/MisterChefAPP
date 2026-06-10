import '../config/constants.dart';
import 'api_service.dart';

class LocationService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // GET /api/v1/departments
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final res = await _api.get('/departments');
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/cities?id_departament=54
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getCities(String idDepartment) async {
    final res = await _api.get('/cities', query: {'id_departament': idDepartment});
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // POST — enviar ubicación del vendedor
  // ══════════════════════════════════════════
  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _api.post(
      AppConstants.endpointLocation,
      {'latitude': latitude, 'longitude': longitude},
    );
  }

  // ══════════════════════════════════════════
  // DELETE/PATCH — desactivar ubicación
  // ══════════════════════════════════════════
  Future<void> deactivateLocation() async {
    await _api.post(AppConstants.endpointLocationDeactivate, {});
  }
}