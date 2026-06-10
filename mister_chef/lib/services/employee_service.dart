import '../config/constants.dart';
import 'api_service.dart';

class EmployeeService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // GET /api/v1/employees
  // Respuesta: lista de empleados
  // {
  //   "document_employee","name_1","name_2",
  //   "last_name_1","last_name_2","phone_number",
  //   "status","email","type","commission_percentage",
  //   "hire_date","can_modify_invoice"
  // }
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getEmployees() async {
    final res = await _api.get(AppConstants.endpointEmployees);
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/employees/{id}
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> getEmployeeById(String doc) async {
    final res =
        await _api.get('${AppConstants.endpointEmployees}/$doc');
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // POST /api/v1/employees
  // Body requerido:
  // {
  //   "document_employee","name_1","last_name_1",
  //   "email","type" (A|V)
  // }
  // Body opcional:
  // {
  //   "name_2","last_name_2","phone_number",
  //   "commission_percentage","can_modify_invoice" (S|N)
  // }
  // Respuesta:
  // {
  //   "message": "...",
  //   "employee": { ... },
  //   "temp_password": "Mister@XXXX"  ← mostrar UNA sola vez
  // }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> createEmployee(
      Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.endpointEmployees, data);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PUT /api/v1/employees/{id}
  // Body: campos a actualizar
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> updateEmployee(
      String doc, Map<String, dynamic> data) async {
    final res = await _api.put(
        '${AppConstants.endpointEmployees}/$doc', data);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/employees/{id}/status
  // Body: { "status": "A" | "I" }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> changeStatus(
      String doc, String status) async {
    final res = await _api.patch(
      '${AppConstants.endpointEmployees}/$doc/status',
      {'status': status},
    );
    return Map<String, dynamic>.from(res);
  }
}