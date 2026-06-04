import 'dart:convert';
import 'package:http/http.dart' as http;

class EmployeeService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  EmployeeService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<dynamic>> getEmployees({String? search}) async {
    var url = '$_baseUrl/employees?mode=current';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeQueryComponent(search)}';
    }
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load employees');
    final body = jsonDecode(resp.body);
    return body['data'] ?? [];
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/employees'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create employee');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<Map<String, dynamic>> getEmployeeDetail(String id) async {
    final resp = await http.get(Uri.parse('$_baseUrl/employees/$id?include=all'), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load employee');
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/employees/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update employee');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<void> deleteEmployee(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/employees/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete employee');
    }
  }

  // ── Data History (Infotype) ──

  Future<List<dynamic>> getDataHistory(String employeeId, {String? infotype}) async {
    var url = '$_baseUrl/employees/$employeeId/history';
    if (infotype != null && infotype.isNotEmpty) {
      url += '?infotype=$infotype';
    }
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load history');
    return jsonDecode(resp.body)['data'] ?? [];
  }

  Future<Map<String, dynamic>> createDataHistory(Map<String, dynamic> data) async {
    final empId = data['employee_id'];
    // Remove employee_id from body since it's taken from URL
    final body = Map<String, dynamic>.from(data)..remove('employee_id');
    final resp = await http.post(Uri.parse('$_baseUrl/employees/$empId/history'), headers: _headers, body: jsonEncode(body));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create record');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<Map<String, dynamic>> updateDataHistory(String recordId, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/employee-records/$recordId'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update record');
    }
    return jsonDecode(resp.body)['data'] ?? {};
  }

  Future<void> deleteDataHistory(String recordId) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/employee-records/$recordId'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete record');
    }
  }
}
