import '../config/constants.dart';
import 'api_service.dart';

/// Servicio para gestión de facturas (pedidos) de Mister Chef.
///
/// Proporciona métodos para listar, consultar, crear, confirmar
/// y anular facturas a través de la API `/api/v1/invoices`.
///
/// Estructura de una factura completa devuelta por la API:
/// ```json
/// {
///   "id_invoice": "FAC01",
///   "date": "2024-01-15",
///   "total": 150000,
///   "status": "P",            // P=Pendiente, C=Confirmada, A=Anulada
///   "id_client": "CLI01",
///   "client": {
///     "id_client", "client_name1", "client_last_name1",
///     "business_name", "address", "phone_number",
///     "latitude", "longitude"
///   },
///   "details": [
///     {
///       "line_number", "amount", "subtotal",
///       "id_product",
///       "product": { "id_product", "product_name", "selling_price", "stock" }
///     }
///   ]
/// }
/// ```
class OrderService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // GET /api/v1/invoices
  // Parámetros opcionales de filtro:
  //   ?status=P|C|A   (Pendiente, Confirmada, Anulada)
  //   ?date=YYYY-MM-DD  (facturas de una fecha específica)
  // ══════════════════════════════════════════

  /// Obtiene la lista de facturas del empleado autenticado.
  ///
  /// Parámetros opcionales:
  /// - [status]: filtra por estado ('P', 'C' o 'A').
  /// - [date]: filtra facturas de la fecha indicada (formato YYYY-MM-DD).
  ///
  /// Los vendedores solo ven sus propias facturas; los admins ven todas.
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
  // ══════════════════════════════════════════

  /// Obtiene el detalle completo de una factura por su [id].
  ///
  /// La respuesta incluye el cliente y todos los productos del pedido
  /// con cantidades, subtotales y datos del producto.
  Future<Map<String, dynamic>> getInvoiceById(String id) async {
    final res = await _api.get('${AppConstants.endpointInvoices}/$id');
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/invoices/{id}/audit
  // ══════════════════════════════════════════

  /// Obtiene el historial de cambios (auditoría) de una factura por su [id].
  ///
  /// Útil para rastrear confirmaciones, anulaciones y quién las realizó.
  Future<List<Map<String, dynamic>>> getInvoiceAudit(String id) async {
    final res = await _api.get('${AppConstants.endpointInvoices}/$id/audit');
    return List<Map<String, dynamic>>.from(res);
  }

  // ══════════════════════════════════════════
  // POST /api/v1/invoices
  //
  // Cuerpo esperado:
  // {
  //   "id_invoice": "FAC01",    ← código único (máximo 5 caracteres)
  //   "id_client":  "CLI01",
  //   "details": [
  //     { "id_product": "PRD01", "amount": 3 },
  //     { "id_product": "PRD02", "amount": 1 }
  //   ]
  // }
  // La API calcula subtotales y total automáticamente.
  // ══════════════════════════════════════════

  /// Crea una nueva factura con los productos y cliente indicados.
  ///
  /// Parámetros:
  /// - [idInvoice]: código único de la factura (máx. 5 caracteres).
  /// - [idClient]: identificador del cliente al que se le factura.
  /// - [details]: lista de productos con `id_product` y `amount`.
  ///
  /// La factura se crea en estado Pendiente ('P'). Para descuentar stock
  /// debe confirmarse con [confirmInvoice].
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
        'details':    details,
      },
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/invoices/{id}/confirm
  //
  // Solo facturas en estado Pendiente pueden confirmarse.
  // Al confirmar: descuenta stock y cambia status a 'C'.
  // ══════════════════════════════════════════

  /// Confirma la factura con el [id] indicado.
  ///
  /// Solo funciona sobre facturas en estado Pendiente ('P').
  /// Tras confirmar, el stock de los productos se descuenta automáticamente
  /// y el estado cambia a Confirmada ('C').
  Future<Map<String, dynamic>> confirmInvoice(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointInvoices}/$id/confirm',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PATCH /api/v1/invoices/{id}/cancel
  //
  // Solo empleados con can_modify_invoice = 'S' pueden anular.
  // Cambia el status a 'A' (Anulada).
  // ══════════════════════════════════════════

  /// Anula la factura con el [id] indicado.
  ///
  /// Solo los empleados con permiso `can_modify_invoice = 'S'` pueden anular.
  /// Una factura anulada no puede reactivarse.
  Future<Map<String, dynamic>> cancelInvoice(String id) async {
    final res = await _api.patch(
      '${AppConstants.endpointInvoices}/$id/cancel',
      {},
    );
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // GET /api/v1/invoices/stats
  //
  // Devuelve estadísticas del día: total de pedidos, ventas totales
  // y clientes visitados.
  // ══════════════════════════════════════════

  /// Obtiene las estadísticas del día para el dashboard principal.
  ///
  /// Retorna un mapa con:
  /// - `total_pedidos`: cantidad de facturas creadas hoy.
  /// - `total_ventas`: suma de los totales de las facturas.
  /// - `clientes_visitados`: número de clientes con al menos una factura hoy.
  Future<Map<String, dynamic>> getTodayStats() async {
    final res = await _api.get('${AppConstants.endpointInvoices}/stats');
    return Map<String, dynamic>.from(res);
  }
}
