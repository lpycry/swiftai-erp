import 'dart:convert';
import 'package:http/http.dart' as http;

class OrgService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  OrgService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ==================== Organizations ====================

  Future<List<dynamic>> getOrganizations() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/orgs'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Failed to load organizations');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<Map<String, dynamic>> getOrganization(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/orgs/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Failed to load organization');
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> createOrganization(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/orgs'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create organization');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateOrganization(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/orgs/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update organization');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<void> deactivateOrganization(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/orgs/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to deactivate organization');
    }
  }

  // ==================== Sites ====================

  Future<List<dynamic>> getSitesByOrg(String orgId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/orgs/$orgId/sites'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Failed to load sites');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<Map<String, dynamic>> createSite(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/sites'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create site');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateSite(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/sites/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update site');
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  Future<void> deleteSite(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/sites/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete site');
    }
  }
}
