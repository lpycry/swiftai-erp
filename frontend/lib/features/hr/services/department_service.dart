import 'dart:convert';
import 'package:http/http.dart' as http;

class DepartmentService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  DepartmentService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<dynamic>> getOrgUnits({String? search}) async {
    var url = '$_baseUrl/org-units';
    final params = <String>[];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search)}');
    }
    if (params.isNotEmpty) url += '?${params.join("&")}';
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load departments');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<List<dynamic>> getOrgUnitTree() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/org-units?mode=tree'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Failed to load org tree');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<Map<String, dynamic>> createOrgUnit(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/org-units'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create department');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateOrgUnit(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/org-units/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update department');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<void> deleteOrgUnit(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/org-units/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete department');
    }
  }
}
