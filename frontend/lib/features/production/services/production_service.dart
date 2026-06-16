import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductionService {
  final String _token;
  final String _baseUrl = 'http://localhost:8080/api/v1/production';

  ProductionService(this._token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  // ── BOM (FSD §6) — routes are at /api/v1/bom
  String get _bomBase => 'http://localhost:8080/api/v1/bom';

  /// Create BOM with nested items per FSD §6.1
  Future<Map<String, dynamic>> createBOM(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_bomBase'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create BOM failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  /// List BOMs (filterable by material_id, status)
  Future<List<dynamic>> listBOMs({String? materialId, String? status}) async {
    final params = <String, String>{};
    if (materialId != null) params['material_id'] = materialId;
    if (status != null) params['status'] = status;
    final uri = Uri.parse(
      '$_bomBase',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  /// Get BOM detail with items
  Future<Map<String, dynamic>> getBOM(String id) async {
    final resp = await http.get(Uri.parse('$_bomBase/$id'), headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  /// Update BOM header
  Future<void> updateBOM(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_bomBase/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  /// Soft delete BOM
  Future<void> deleteBOM(String id) async {
    final resp = await http.delete(
      Uri.parse('$_bomBase/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  /// Add item to BOM
  Future<Map<String, dynamic>> addBOMItem(
    String bomId,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_bomBase/$bomId/items'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Add item failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  /// Update BOM item
  Future<void> updateBOMItem(String itemId, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_bomBase/items/$itemId'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update item failed');
    }
  }

  /// Delete BOM item
  Future<void> deleteBOMItem(String itemId) async {
    final resp = await http.delete(
      Uri.parse('$_bomBase/items/$itemId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete item failed');
  }

  /// BOM Explosion (FSD §4.2)
  Future<List<dynamic>> explodeBOM({
    required String materialId,
    String? bomVersion,
    String explosionType = 'single',
    double requirementQty = 1.0,
  }) async {
    final resp = await http.post(
      Uri.parse('$_bomBase/explode'),
      headers: _headers,
      body: jsonEncode({
        'material_id': materialId,
        'bom_version': bomVersion,
        'explosion_type': explosionType,
        'requirement_qty': requirementQty,
      }),
    );
    if (resp.statusCode >= 400)
      throw Exception('BOM explosion failed: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  // ── Work Centers ──
  Future<List<dynamic>> listWorkCenters() async {
    final resp = await http.get(
      Uri.parse('http://localhost:8080/api/v1/production/work-centers'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createWorkCenter(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('http://localhost:8080/api/v1/production/work-centers'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateWorkCenter(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('http://localhost:8080/api/v1/production/work-centers/${id}'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteWorkCenter(String id) async {
    final resp = await http.delete(
      Uri.parse('http://localhost:8080/api/v1/production/work-centers/${id}'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  // ── Routing Templates ──
  Future<List<dynamic>> listRoutingTemplates() async {
    final resp = await http.get(
      Uri.parse('http://localhost:8080/api/v1/production/routing-templates'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createRoutingTemplate(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('http://localhost:8080/api/v1/production/routing-templates'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateRoutingTemplate(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse(
        'http://localhost:8080/api/v1/production/routing-templates/${id}',
      ),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteRoutingTemplate(String id) async {
    final resp = await http.delete(
      Uri.parse(
        'http://localhost:8080/api/v1/production/routing-templates/${id}',
      ),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  // ── Template Operations ──
  Future<Map<String, dynamic>> createTemplateOperation(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse(
        'http://localhost:8080/api/v1/production/routing-templates/${data['template_id']}/operations',
      ),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deleteTemplateOperation(String id) async {
    final resp = await http.delete(
      Uri.parse(
        'http://localhost:8080/api/v1/production/template-operations/${id}',
      ),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  // ── Production Orders ──
  String get _ordersBase => 'http://localhost:8080/api/v1/production/orders';

  Future<Map<String, dynamic>> createProductionOrder(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse(_ordersBase),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create production order failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> listProductionOrders({
    String? materialId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (materialId != null) params['material_id'] = materialId;
    if (status != null) params['status'] = status;
    final uri = Uri.parse(_ordersBase)
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getProductionOrder(String id) async {
    final resp =
        await http.get(Uri.parse('$_ordersBase/$id'), headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateProductionOrder(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$_ordersBase/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteProductionOrder(String id) async {
    final resp = await http.delete(
      Uri.parse('$_ordersBase/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  Future<Map<String, dynamic>?> getProductionOrderRouting(String poId) async {
    final resp = await http.get(
      Uri.parse('$_ordersBase/$poId/routing'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) return null;
    final body = jsonDecode(resp.body);
    return (body['data'] as Map<String, dynamic>?);
  }
}
