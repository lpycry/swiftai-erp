import 'dart:convert';
import 'package:http/http.dart' as http;

class PositionService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  PositionService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<dynamic>> getPositions({String? search, bool tree = false}) async {
    var url = '$_baseUrl/positions';
    final params = <String>[];
    if (tree) params.add('mode=tree');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeQueryComponent(search)}');
    if (params.isNotEmpty) url += '?${params.join("&")}';
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load positions');
    return jsonDecode(resp.body)['data'] ?? [];
  }

  Future<Map<String, dynamic>> createPosition(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/positions'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create position');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<Map<String, dynamic>> updatePosition(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/positions/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update position');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<void> deletePosition(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/positions/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete position');
    }
  }
}
