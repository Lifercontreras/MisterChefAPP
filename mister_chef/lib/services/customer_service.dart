import '../config/constants.dart';
import 'api_service.dart';

class CustomerService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // GET /api/v1/clients
  // Query params opcionales: ?status=true|false
  // Respuesta: lista de clientes con city, city.department, employee
  // Estructura de cada cliente:
  // {
  //   "id_client","client_name1","client_name2",
  //   "client_last_name1","client_last_name2",
  //   "business_name","address",
  //   "longitude","latitude","phone_number",
  //   "status": true|false,
  //   "document_employee",
  //   "city": { "id_city","city_name",
  //             "department": { "id_departament","department_name" } },
  //   "employee": { "name_1","last_name_1" }
  // }
  // Nota: vendedor solo ve sus propios clientes (la API lo filtra)
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getClients({bool? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.toString();

    final res = await _api.get(
      AppConstants.endpointClients,
      query: params.isEmpty ? null : params,
    );
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/clients/{id}
  // Respuesta: cliente completo con city, department, employee e invoices
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> getClientById(String id) async {
    final res = await _api.get('${AppConstants.endpointClients}/$id');
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // POST /api/v1/clients
  // Body requerido:
  // {
  //   "client_name1":      "",
  //   "client_name2":      "",        ← nullable
  //   "client_last_name1": "",
  //   "client_last_name2": "",        ← nullable
  //   "business_name":     "",
  //   "address":           "",
  //   "longitude":         0.0,
  //   "latitude":          0.0,
  //   "phone_number":      "",        ← nullable
  //   "status":            true,
  //   "id_departament":    "",
  //   "id_city":           ""
  // }
  // Respuesta: { "message": "...", "client": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> createClient(
      Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.endpointClients, data);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PUT /api/v1/clients/{id}
  // Body: campos a actualizar (todos opcionales)
  // Respuesta: { "message": "...", "client": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> updateClient(
      String id, Map<String, dynamic> data) async {
    final res = await _api.put('${AppConstants.endpointClients}/$id', data);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/clients/{id}/status
  // Body: { "status": true|false }
  // Respuesta: { "message": "...", "client": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> changeClientStatus(
      String id, bool status) async {
    final res = await _api.patch(
      '${AppConstants.endpointClients}/$id/status',
      {'status': status},
    );
    return Map<String, dynamic>.from(res);
  }
}