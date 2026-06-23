import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductionService {
  final String _token;

  ProductionService(this._token);

  static const String _host = 'http://localhost:8080/api/v1';

  String get _bomBase => '$_host/bom';
  String get _productionBase => '$_host/production';
  String get _routingBase => '$_productionBase/routing-templates';
  String get _templateOperationBase => '$_productionBase/template-operations';
  String get _ordersBase => '$_productionBase/orders';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  dynamic _decode(http.Response resp) {
    if (resp.body.isEmpty) return null;
    return jsonDecode(resp.body);
  }

  Exception _apiException(http.Response resp, String fallback) {
    try {
      final body = _decode(resp);
      return Exception(body?['message'] ?? fallback);
    } catch (_) {
      return Exception(fallback);
    }
  }

  // ── BOM ──

  Future<Map<String, dynamic>> createBOM(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse(_bomBase),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create BOM failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> listBOMs({String? materialId, String? status}) async {
    final params = <String, String>{};

    if (materialId != null) params['material_id'] = materialId;
    if (status != null) params['status'] = status;

    final uri = Uri.parse(
      _bomBase,
    ).replace(queryParameters: params.isNotEmpty ? params : null);

    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'List BOMs failed');
    }

    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getBOM(String id) async {
    final resp = await http.get(Uri.parse('$_bomBase/$id'), headers: _headers);

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Get BOM failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateBOM(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_bomBase/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update BOM failed');
    }
  }

  Future<void> deleteBOM(String id) async {
    final resp = await http.delete(
      Uri.parse('$_bomBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete BOM failed');
    }
  }

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
      throw _apiException(resp, 'Add BOM item failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateBOMItem(String itemId, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_bomBase/items/$itemId'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update BOM item failed');
    }
  }

  Future<void> deleteBOMItem(String itemId) async {
    final resp = await http.delete(
      Uri.parse('$_bomBase/items/$itemId'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete BOM item failed');
    }
  }

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

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'BOM explosion failed');
    }

    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }

  // ── Work Centers ──

  Future<List<dynamic>> listWorkCenters() async {
    final resp = await http.get(
      Uri.parse('$_productionBase/work-centers'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'List work centers failed');
    }

    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createWorkCenter(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_productionBase/work-centers'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create work center failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getWorkCenter(String id) async {
    final resp = await http.get(
      Uri.parse('$_productionBase/work-centers/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Get work center failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateWorkCenter(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_productionBase/work-centers/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update work center failed');
    }
  }

  Future<void> deleteWorkCenter(String id) async {
    final resp = await http.delete(
      Uri.parse('$_productionBase/work-centers/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete work center failed');
    }
  }

  // ── Routing Templates ──

  Future<List<dynamic>> listRoutingTemplates() async {
    final resp = await http.get(Uri.parse(_routingBase), headers: _headers);

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'List routing templates failed');
    }

    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getRoutingTemplate(String id) async {
    final resp = await http.get(
      Uri.parse('$_routingBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Get routing template failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> createRoutingTemplate(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse(_routingBase),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create routing template failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateRoutingTemplate(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$_routingBase/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update routing template failed');
    }
  }

  Future<void> deleteRoutingTemplate(String id) async {
    final resp = await http.delete(
      Uri.parse('$_routingBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete routing template failed');
    }
  }

  // ── Template Operations ──
  // Optional APIs. Routing Template page should mainly use updateRoutingTemplate()
  // with operations[] instead of calling these one by one.

  Future<Map<String, dynamic>> createTemplateOperation(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse(_templateOperationBase),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create template operation failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateTemplateOperation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$_templateOperationBase/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update template operation failed');
    }
  }

  Future<void> deleteTemplateOperation(String id) async {
    final resp = await http.delete(
      Uri.parse('$_templateOperationBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete template operation failed');
    }
  }

  // ── Production Orders ──

  Future<Map<String, dynamic>> createProductionOrder(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse(_ordersBase),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create production order failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> listProductionOrders({
    String? materialId,
    String? status,
  }) async {
    final params = <String, String>{};

    if (materialId != null) params['material_id'] = materialId;
    if (status != null) params['status'] = status;

    final uri = Uri.parse(
      _ordersBase,
    ).replace(queryParameters: params.isNotEmpty ? params : null);

    final resp = await http.get(uri, headers: _headers);

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'List production orders failed');
    }

    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getProductionOrder(String id) async {
    final resp = await http.get(
      Uri.parse('$_ordersBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Get production order failed');
    }

    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
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
      throw _apiException(resp, 'Update production order failed');
    }
  }

  Future<void> deleteProductionOrder(String id) async {
    final resp = await http.delete(
      Uri.parse('$_ordersBase/$id'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Delete production order failed');
    }
  }

  Future<Map<String, dynamic>?> getProductionOrderRouting(String poId) async {
    final resp = await http.get(
      Uri.parse('$_ordersBase/$poId/routing'),
      headers: _headers,
    );

    if (resp.statusCode >= 400) return null;

    return _decode(resp)?['data'] as Map<String, dynamic>?;
  }

  Future<void> syncPOMaterials(String poId) async {
    final resp = await http.post(
      Uri.parse('$_ordersBase/$poId/sync-materials'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Sync materials failed');
    }
  }

  Future<void> updatePOMaterialIssueQty(
    String materialId,
    double issueQty,
  ) async {
    final resp = await http.put(
      Uri.parse('$_ordersBase/materials/$materialId/issue-qty'),
      headers: _headers,
      body: jsonEncode({'issue_qty': issueQty}),
    );
    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Update issue qty failed');
    }
  }

  Future<Map<String, dynamic>> createTimeConfirmation(
    String productionOrderId,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_ordersBase/$productionOrderId/time-confirmations'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Create time confirmation failed');
    }
    return _decode(resp)?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> listTimeConfirmations(String productionOrderId) async {
    final resp = await http.get(
      Uri.parse('$_ordersBase/$productionOrderId/time-confirmations'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'List time confirmations failed');
    }
    return _decode(resp)?['data'] as List<dynamic>? ?? [];
  }
}
