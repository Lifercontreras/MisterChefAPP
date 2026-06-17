import '../config/constants.dart';
import 'api_service.dart';

/// Servicio para la gestión del inventario de productos en Mister Chef.
///
/// Provee acceso al endpoint `/api/v1/products` para listar, crear,
/// actualizar y cambiar el estado o stock de los productos.
class ProductService {
  final _api = ApiService();

  /// Obtiene la lista de productos.
  ///
  /// Si [status] es `true`, retorna solo productos activos (disponibles
  /// para nuevos pedidos). Si es `null`, retorna todos.
  Future<List<Map<String, dynamic>>> getProducts({bool? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.toString();
    final res = await _api.get(AppConstants.endpointProducts,
        query: params.isEmpty ? null : params);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene el detalle completo de un producto por su [id].
  Future<Map<String, dynamic>> getProductById(String id) async {
    final res = await _api.get('${AppConstants.endpointProducts}/$id');
    return Map<String, dynamic>.from(res);
  }

  /// Obtiene todos los productos cuyo stock actual está por debajo
  /// del stock mínimo configurado.
  ///
  /// Usado en el dashboard del administrador para alertas de inventario.
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final res = await _api.get(AppConstants.endpointProductsLowStock);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Obtiene los tipos de producto disponibles para clasificar nuevos productos.
  Future<List<Map<String, dynamic>>> getProductTypes() async {
    final res = await _api.get('/product-types');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Crea un nuevo producto con los datos proporcionados en [data].
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.endpointProducts, data);
    return Map<String, dynamic>.from(res);
  }

  /// Actualiza los datos de un producto existente identificado por [id].
  Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> data) async {
    final res = await _api.put('${AppConstants.endpointProducts}/$id', data);
    return Map<String, dynamic>.from(res);
  }

  /// Actualiza el stock disponible de un producto.
  ///
  /// [stock] es la nueva cantidad total en inventario.
  Future<Map<String, dynamic>> updateStock(String id, int stock) async {
    final res = await _api.patch(
        '${AppConstants.endpointProducts}/$id/stock', {'stock': stock});
    return Map<String, dynamic>.from(res);
  }

  /// Cambia el estado activo/inactivo de un producto.
  ///
  /// Los productos inactivos no aparecen en el selector de nuevos pedidos.
  Future<Map<String, dynamic>> changeStatus(String id, bool status) async {
    final res = await _api.patch(
        '${AppConstants.endpointProducts}/$id/status', {'status': status});
    return Map<String, dynamic>.from(res);
  }
}
