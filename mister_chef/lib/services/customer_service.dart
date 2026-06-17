import '../config/constants.dart';
import 'api_service.dart';

/// Servicio para la gestión de clientes en Mister Chef.
///
/// Provee métodos CRUD sobre el endpoint `/api/v1/clients`.
/// Los vendedores solo acceden a sus propios clientes (filtrado en el servidor);
/// los administradores pueden ver y gestionar todos.
///
/// Estructura de un cliente devuelto por la API:
/// ```json
/// {
///   "id_client", "client_name1", "client_name2",
///   "client_last_name1", "client_last_name2",
///   "business_name", "address",
///   "longitude", "latitude", "phone_number",
///   "status": true | false,
///   "document_employee",
///   "city": {
///     "id_city", "city_name",
///     "department": { "id_departament", "department_name" }
///   },
///   "employee": { "name_1", "last_name_1" }
/// }
/// ```
class CustomerService {
  final _api = ApiService();

  /// Obtiene la lista de clientes.
  ///
  /// Si [status] es `true`, devuelve solo clientes activos.
  /// Si es `false`, devuelve solo inactivos. Si es `null`, devuelve todos.
  Future<List<Map<String, dynamic>>> getClients({bool? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.toString();

    final res = await _api.get(
      AppConstants.endpointClients,
      query: params.isEmpty ? null : params,
    );
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene el detalle completo de un cliente por su [id].
  ///
  /// Incluye datos de ciudad, departamento, vendedor asignado
  /// e historial de facturas del cliente.
  Future<Map<String, dynamic>> getClientById(String id) async {
    final res = await _api.get('${AppConstants.endpointClients}/$id');
    return Map<String, dynamic>.from(res);
  }

  /// Crea un nuevo cliente con los datos proporcionados en [data].
  ///
  /// Campos requeridos: `client_name1`, `client_last_name1`, `address`,
  /// `latitude`, `longitude`, `status`, `id_departament`, `id_city`.
  /// Campos opcionales: `client_name2`, `client_last_name2`,
  /// `business_name`, `phone_number`.
  Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.endpointClients, data);
    return Map<String, dynamic>.from(res);
  }

  /// Actualiza los datos de un cliente existente identificado por [id].
  ///
  /// Solo se actualizan los campos presentes en [data].
  Future<Map<String, dynamic>> updateClient(
      String id, Map<String, dynamic> data) async {
    final res = await _api.put('${AppConstants.endpointClients}/$id', data);
    return Map<String, dynamic>.from(res);
  }

  /// Cambia el estado activo/inactivo de un cliente.
  ///
  /// [status] `true` activa el cliente; `false` lo desactiva.
  Future<Map<String, dynamic>> changeClientStatus(
      String id, bool status) async {
    final res = await _api.patch(
      '${AppConstants.endpointClients}/$id/status',
      {'status': status},
    );
    return Map<String, dynamic>.from(res);
  }
}
