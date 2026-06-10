import '../config/constants.dart';
import 'api_service.dart';

class ProductService {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getProducts({bool? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.toString();
    final res = await _api.get(AppConstants.endpointProducts,
        query: params.isEmpty ? null : params);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> getProductById(String id) async {
    final res = await _api.get('${AppConstants.endpointProducts}/$id');
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final res = await _api.get(AppConstants.endpointProductsLowStock);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getProductTypes() async {
    final res = await _api.get('/product-types');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.endpointProducts, data);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> data) async {
    final res = await _api.put('${AppConstants.endpointProducts}/$id', data);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> updateStock(String id, int stock) async {
    final res = await _api.patch(
        '${AppConstants.endpointProducts}/$id/stock', {'stock': stock});
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> changeStatus(String id, bool status) async {
    final res = await _api.patch(
        '${AppConstants.endpointProducts}/$id/status', {'status': status});
    return Map<String, dynamic>.from(res);
  }
}