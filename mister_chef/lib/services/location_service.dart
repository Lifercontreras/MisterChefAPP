import '../config/constants.dart';
import 'api_service.dart';

/// Servicio de geolocalización y datos geográficos de Mister Chef.
///
/// Provee dos funciones:
/// 1. Obtener listas de departamentos y ciudades de Colombia para
///    formularios de registro de clientes.
/// 2. Enviar y desactivar la ubicación GPS del vendedor para que
///    el administrador pueda rastrearlo en tiempo real.
class LocationService {
  final _api = ApiService();

  /// Obtiene la lista de todos los departamentos de Colombia.
  ///
  /// Usado en el formulario de creación/edición de clientes para
  /// seleccionar el departamento antes de filtrar las ciudades.
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final res = await _api.get('/departments');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene las ciudades del departamento identificado por [idDepartment].
  ///
  /// Se llama después de que el usuario selecciona un departamento
  /// para cargar las ciudades disponibles en ese departamento.
  Future<List<Map<String, dynamic>>> getCities(String idDepartment) async {
    final res = await _api.get('/cities', query: {'id_departament': idDepartment});
    return List<Map<String, dynamic>>.from(res);
  }

  /// Envía la ubicación GPS actual del vendedor al servidor.
  ///
  /// Llamado periódicamente (cada [AppConstants.locationIntervalSeconds])
  /// mientras el vendedor tiene la app abierta, para que el administrador
  /// pueda ver su posición en el mapa de entrega en tiempo real.
  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _api.post(
      AppConstants.endpointLocation,
      {'latitude': latitude, 'longitude': longitude},
    );
  }

  /// Desactiva el rastreo de ubicación del vendedor en el servidor.
  ///
  /// Se llama cuando el vendedor cierra la app o desactiva manualmente
  /// el rastreo, para que no aparezca en el mapa del administrador.
  Future<void> deactivateLocation() async {
    await _api.post(AppConstants.endpointLocationDeactivate, {});
  }
}
