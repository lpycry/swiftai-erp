import 'dart:convert';
import 'package:http/http.dart' as http;

class DateFormatService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  DateFormatService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  Future<List<dynamic>> getDateFormats() async {
    final resp = await http.get(Uri.parse('$_baseUrl/date-formats'), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('Failed to load date formats');
    return (jsonDecode(resp.body)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createDateFormat(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/date-formats'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create date format');
    }
    return (jsonDecode(resp.body)['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDateFormat(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/date-formats/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update date format');
    }
    return (jsonDecode(resp.body)['data'] ?? {}) as Map<String, dynamic>;
  }

  Future<void> deleteDateFormat(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/date-formats/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete date format');
    }
  }
}
