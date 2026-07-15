import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  AdminService(this._token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  // ---- Users ----

  Future<List<dynamic>> getUsers({String? search, String? status}) async {
    final params = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null && status != 'all') params['status'] = status;
    final uri = Uri.parse(
      '$_baseUrl/admin/users',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http.get(uri, headers: _headers);
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getUser(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/admin/users/$id'),
      headers: _headers,
    );
    return _handleData(resp);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/admin/users'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleData(resp);
  }

  Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/admin/users/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleData(resp);
  }

  Future<void> setUserActive(String id, bool isActive) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/admin/users/$id/status'),
      headers: _headers,
      body: jsonEncode({'is_active': isActive}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Set status failed: ${resp.statusCode}');
    }
  }

  Future<void> resetUserPassword(String id, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/admin/users/$id/reset-password'),
      headers: _headers,
      body: jsonEncode({'password': password}),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Reset password failed: ${resp.statusCode}');
    }
  }

  // ---- Auth Objects ----

  Future<List<dynamic>> getAuthObjects({String? classFilter}) async {
    final uri = Uri.parse('$_baseUrl/admin/auth-objects').replace(
      queryParameters: classFilter != null ? {'class': classFilter} : null,
    );
    final resp = await http.get(uri, headers: _headers);
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getAuthObject(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/admin/auth-objects/$id'),
      headers: _headers,
    );
    return _handleData(resp);
  }

  Future<Map<String, dynamic>> createAuthObject(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/admin/auth-objects'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleData(resp);
  }

  Future<void> updateAuthObject(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/admin/auth-objects/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Update failed');
  }

  Future<void> deleteAuthObject(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/admin/auth-objects/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  Future<Map<String, dynamic>> addAuthObjectField(
    String objectId,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/admin/auth-objects/$objectId/fields'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleData(resp);
  }

  Future<void> deleteAuthObjectField(String objectId, String fieldId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/admin/auth-objects/$objectId/fields/$fieldId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete field failed');
  }

  // ---- Roles ----

  Future<List<dynamic>> getRoles({String? category}) async {
    final uri = Uri.parse('$_baseUrl/role-master').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final resp = await http.get(uri, headers: _headers);
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getRole(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/role-master/$id'),
      headers: _headers,
    );
    return _handleData(resp);
  }

  Future<Map<String, dynamic>> createRole(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/role-master'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleData(resp);
  }

  Future<void> deleteRole(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/role-master/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Delete failed');
  }

  // ---- Auth Values ----

  Future<List<dynamic>> getAuthValues(String roleId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/role-master/$roleId/auth-values'),
      headers: _headers,
    );
    return _handleList(resp);
  }

  Future<void> setAuthValue(String roleId, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/role-master/$roleId/auth-values'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Set auth value failed');
  }

  // ---- User-Role Assignment ----

  Future<void> assignRole(String userId, String roleId) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/user-roles/assign'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'role_id': roleId}),
    );
    if (resp.statusCode >= 400) throw Exception('Assign failed');
  }

  Future<void> removeRole(String userId, String roleId) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/user-roles/$userId/$roleId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('Remove failed');
  }

  // ---- Permission Check ----

  Future<bool> checkPermission(String object, String activity) async {
    final resp = await http.get(
      Uri.parse(
        '$_baseUrl/permissions/check?object=$object&activity=$activity',
      ),
      headers: _headers,
    );
    if (resp.statusCode == 200) return true;
    return false;
  }

  // ---- Helpers ----

  List<dynamic> _handleList(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw Exception(_errorMessage(resp));
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Map<String, dynamic> _handleData(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw Exception(_errorMessage(resp));
    }
    final body = jsonDecode(resp.body);
    return body['data'] ?? {};
  }

  String _errorMessage(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      final msg = body['message'] ?? body['error'] ?? body['details'];
      if (msg != null) return 'API error ${resp.statusCode}: $msg';
    } catch (_) {}
    return 'API error: ${resp.statusCode}';
  }
}
