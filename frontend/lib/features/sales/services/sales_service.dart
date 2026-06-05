import 'dart:convert';
import 'package:http/http.dart' as http;

class SalesService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  SalesService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ══════════════════════════════════════════
  //  CUSTOMERS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listCustomers({String? query, String? status}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final uri = Uri.parse('$_baseUrl/sales/customers').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/sales/customers'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/sales/customers/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteCustomer(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/sales/customers/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  MATERIAL PRICES
  // ══════════════════════════════════════════

  Future<List<dynamic>> listMaterialPrices({String? productId, bool activeOnly = false}) async {
    final params = <String, String>{};
    if (activeOnly) params['active_only'] = 'true';
    if (productId != null && productId.isNotEmpty) params['product_id'] = productId;
    final uri = Uri.parse('$_baseUrl/sales/material-prices').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createMaterialPrice(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/sales/material-prices'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateMaterialPrice(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/sales/material-prices/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteMaterialPrice(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/sales/material-prices/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  SALES ORDERS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listSalesOrders({String? status, String? orderType}) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (orderType != null && orderType.isNotEmpty) params['type'] = orderType;
    final uri = Uri.parse('$_baseUrl/sales/orders').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createSalesOrder(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/sales/orders'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create SO failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getSalesOrder(String id) async {
    final resp = await http.get(Uri.parse('$_baseUrl/sales/orders/$id'), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load SO');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateSOStatus(String id, String status) async {
    final resp = await http.put(Uri.parse('$_baseUrl/sales/orders/$id/status'), headers: _headers, body: jsonEncode({'status': status}));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Status update failed');
    }
  }

  Future<void> deleteSalesOrder(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/sales/orders/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }
}
