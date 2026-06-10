import '../config/constants.dart';
import 'api_service.dart';

class OrderService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // GET /api/v1/invoices
  // Query params opcionales:
  //   ?status=P|C|A   (P=Pendiente, C=Confirmada, A=Anulada)
  //   ?date=YYYY-MM-DD
  // Respuesta: lista de facturas con client y details.product
  // Estructura de cada factura:
  // {
  //   "id_invoice", "date", "total", "status",
  //   "id_client",
  //   "client": { "id_client","client_name1","client_name2",
  //               "client_last_name1","business_name","address",
  //               "phone_number","latitude","longitude" },
  //   "details": [
  //     { "line_number","amount","subtotal","id_product",
  //       "product": { "id_product","product_name","selling_price","stock" } }
  //   ]
  // }
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getInvoices({
    String? status,
    String? date,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (date   != null && date.isNotEmpty)   params['date']   = date;

    final res = await _api.get(
      AppConstants.endpointInvoices,
      query: params.isEmpty ? null : params,
    );
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/invoices/{id}
  // Respuesta: factura completa con client y details.product
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> getInvoiceById(String id) async {
    final res = await _api.get('${AppConstants.endpointInvoices}/$id');
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/invoices/{id}/audit
  // Respuesta: historial de cambios de la factura
  // ══════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getInvoiceAudit(String id) async {
    final res = await _api.get('${AppConstants.endpointInvoices}/$id/audit');
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // POST /api/v1/invoices
  // Body:
  // {
  //   "id_invoice": "FAC01",        ← código único (max 5 chars)
  //   "id_client":  "CLI01",
  //   "details": [
  //     { "id_product": "PRD01", "amount": 3 },
  //     { "id_product": "PRD02", "amount": 1 }
  //   ]
  // }
  // Respuesta: { "message": "...", "invoice": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> createInvoice({
    required String idInvoice,
    required String idClient,
    required List<Map<String, dynamic>> details,
  }) async {
    final res = await _api.post(
      AppConstants.endpointInvoices,
      {
        'id_invoice': idInvoice,
        'id_client':  idClient,
        'details':    details, // [{ "id_product": "", "amount": 0 }]
      },
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/invoices/{id}/confirm
  // Confirma la factura → descuenta stock → status = 'C'
  // Solo facturas en estado 'P' pueden confirmarse
  // Respuesta: { "message": "...", "invoice": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> confirmInvoice(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointInvoices}/$id/confirm',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/invoices/{id}/cancel
  // Anula la factura → status = 'A'
  // Solo empleados con can_modify_invoice = 'S' pueden anular
  // Respuesta: { "message": "...", "invoice": { ... } }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> cancelInvoice(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointInvoices}/$id/cancel',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // Estadísticas del día (calculadas localmente
  // a partir de GET /invoices?date=hoy)
  // TODO: pedir a tu compañero un endpoint
  //       GET /api/v1/invoices/stats si lo necesitan
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> getTodayStats() async {
    final res = await _api.get('${AppConstants.endpointInvoices}/stats');
    return Map<String, dynamic>.from(res);
  }
}