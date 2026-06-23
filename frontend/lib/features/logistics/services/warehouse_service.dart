import 'dart:convert';
import 'package:http/http.dart' as http;

class WarehouseService {
  final String _token;
  final String _baseUrl = 'http://localhost:8080/api/v1';

  WarehouseService(this._token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  // ── Products (REQ-WM-002) ──

  Future<List<dynamic>> listProducts({String? query}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    final uri = Uri.parse(
      '$_baseUrl/warehouse/products',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getProduct(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/products/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/products'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create product failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/warehouse/products/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update product failed');
    }
  }

  Future<void> deleteProduct(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/warehouse/products/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete product failed');
  }

  // ── Warehouses ──

  Future<List<dynamic>> listWarehouses() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/warehouses'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createWarehouse(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/warehouses'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create warehouse failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getWarehouse(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/warehouses/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateWarehouse(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/warehouse/warehouses/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update warehouse failed');
    }
  }

  Future<void> deleteWarehouse(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/warehouse/warehouses/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete warehouse failed');
    }
  }

  // ── Product Barcodes (REQ-MM-031) ──

  Future<List<dynamic>> listBarcodes(String productId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/products/$productId/barcodes'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createBarcode(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/products/$productId/barcodes'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Create barcode failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deleteBarcode(String productId, String barcodeId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/warehouse/products/$productId/barcodes/$barcodeId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete barcode failed');
  }

  // ── Product Photos (REQ-MM-001~010) ──

  Future<List<dynamic>> listPhotos(String productId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/products/$productId/photos'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<void> uploadPhoto(
    String productId,
    String filePath,
    String fileName,
  ) async {
    final uri = Uri.parse('$_baseUrl/warehouse/products/$productId/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      await http.MultipartFile.fromPath('photo', filePath, filename: fileName),
    );
    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    if (resp.statusCode >= 400) throw Exception('Upload photo failed');
  }

  Future<void> deletePhoto(String productId, String photoId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/warehouse/products/$productId/photos/$photoId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete photo failed');
  }

  // ── Zones ──

  Future<List<dynamic>> listZones(String warehouseId) async {
    final uri = Uri.parse(
      '$_baseUrl/warehouse/zones',
    ).replace(queryParameters: {'warehouse_id': warehouseId});
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createZone(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/zones'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Create zone failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Bins ──

  Future<List<dynamic>> listBins({
    String? zoneId,
    String? warehouseId,
    String? siteId,
  }) async {
    final params = <String, String>{};
    if (zoneId != null && zoneId.isNotEmpty) params['zone_id'] = zoneId;
    if (warehouseId != null && warehouseId.isNotEmpty) {
      params['warehouse_id'] = warehouseId;
    }
    if (siteId != null && siteId.isNotEmpty) params['site_id'] = siteId;
    final uri = Uri.parse(
      '$_baseUrl/warehouse/bins',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createBin(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/bins'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Create bin failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Stock Movements ──

  Future<Map<String, dynamic>> postMovement(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/movements'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Post movement failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> listMovements({
    String? warehouseId,
    String? binId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (warehouseId != null) params['warehouse_id'] = warehouseId;
    if (binId != null) params['bin_id'] = binId;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse(
      '$_baseUrl/warehouse/movements',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> listStock({
    String? productId,
    String? warehouseId,
    String? binId,
    bool? groupBySku,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (productId != null) params['product_id'] = productId;
    if (warehouseId != null) params['warehouse_id'] = warehouseId;
    if (binId != null) params['bin_id'] = binId;
    if (groupBySku == true) params['group_by_sku'] = 'true';
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse(
      '$_baseUrl/warehouse/stock',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  // ── Goods Receipt (REQ-IB-005~014) ──

  Future<List<dynamic>> listGRs() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/gr'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createGR(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/gr'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create GR failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> postGR(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/gr/$id/post'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Post GR failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Outbound (REQ-OB-001~018) ──

  Future<List<dynamic>> listOutbound() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/outbound'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createOutbound(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/outbound'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create outbound failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateOutbound(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/warehouse/outbound/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update outbound failed');
    }
  }

  Future<Map<String, dynamic>> shipOutbound(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/outbound/$id/ship'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Ship failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> reverseOutbound(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/outbound/$id/reverse'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Reverse failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getOutboundJournal(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/outbound/$id/journal'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'No journal entry found');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Cycle Count (REQ-CC-001~008) ──

  Future<List<dynamic>> listCycleCounts() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/warehouse/cycle-counts'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createCycleCount(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/cycle-counts'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Create cycle count failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> aiSuggestCycleCounts() async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/cycle-counts/ai-suggest'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('AI suggest failed');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  // ── Warehouse Tasks (REQ-IO-014~018) ──

  Future<List<dynamic>> listTasks({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final uri = Uri.parse(
      '$_baseUrl/warehouse/tasks',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> completeTask(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/warehouse/tasks/$id/complete'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Complete task failed');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }
}
