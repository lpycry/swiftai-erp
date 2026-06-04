import 'dart:convert';
import 'package:http/http.dart' as http;

class CostCenterService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  CostCenterService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<dynamic>> getCostCenters({String? search}) async {
    var url = '$_baseUrl/cost-centers';
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeQueryComponent(search)}';
    }
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load cost centers');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<Map<String, dynamic>> createCostCenter(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/cost-centers'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create cost center');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateCostCenter(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/cost-centers/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update cost center');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<void> deleteCostCenter(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/cost-centers/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete cost center');
    }
  }
}
