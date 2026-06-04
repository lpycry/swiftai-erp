import 'dart:convert';
import 'package:http/http.dart' as http;

class FinanceSettingsService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  FinanceSettingsService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ══════════════════════════════════════════
  //  PAYMENT TERMS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listPaymentTerms() async {
    final resp = await http.get(Uri.parse('$_baseUrl/finance-settings/payment-terms'), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createPaymentTerm(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/payment-terms'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updatePaymentTerm(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/payment-terms/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deletePaymentTerm(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/payment-terms/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  INCOTERMS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listIncoterms() async {
    final resp = await http.get(Uri.parse('$_baseUrl/finance-settings/incoterms'), headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createIncoterm(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/incoterms'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateIncoterm(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/incoterms/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteIncoterm(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/incoterms/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  ORG RECONCILIATION ACCOUNTS
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listOrgReconAccounts({String? orgId}) async {
    final params = <String, String>{};
    if (orgId != null) params['org_id'] = orgId;
    final uri = Uri.parse('$_baseUrl/finance-settings/org-recon-accounts').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return ((jsonDecode(resp.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrgReconAccount(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/org-recon-accounts'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  /// Update an existing org recon account (e.g. change account).
  Future<void> updateOrgReconAccount(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/org-recon-accounts/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteOrgReconAccount(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/org-recon-accounts/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  TAX JURISDICTIONS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listTaxJurisdictions({bool activeOnly = false}) async {
    final params = <String, String>{};
    if (activeOnly) params['active_only'] = 'true';
    final uri = Uri.parse('$_baseUrl/finance-settings/tax-jurisdictions').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createTaxJurisdiction(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/tax-jurisdictions'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateTaxJurisdiction(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/tax-jurisdictions/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteTaxJurisdiction(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/tax-jurisdictions/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  TAX NEXUS
  // ══════════════════════════════════════════

  Future<List<dynamic>> listTaxNexus({bool activeOnly = false}) async {
    final params = <String, String>{};
    if (activeOnly) params['active_only'] = 'true';
    final uri = Uri.parse('$_baseUrl/finance-settings/tax-nexus').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createTaxNexus(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/tax-nexus'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateTaxNexus(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/tax-nexus/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteTaxNexus(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/tax-nexus/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  TAX JURISDICTION RULES (Product Category × Tax Code)
  // ══════════════════════════════════════════

  Future<List<dynamic>> listTaxJurisdictionRules() async {
    final uri = Uri.parse('$_baseUrl/finance-settings/tax-jurisdiction-rules');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createTaxJurisdictionRule(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/tax-jurisdiction-rules'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateTaxJurisdictionRule(int ruleId, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/tax-jurisdiction-rules/$ruleId'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteTaxJurisdictionRule(int ruleId) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/tax-jurisdiction-rules/$ruleId'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  // ══════════════════════════════════════════
  //  TAX CATEGORIES
  // ══════════════════════════════════════════

  Future<List<dynamic>> listTaxCategories() async {
    final uri = Uri.parse('$_baseUrl/finance-settings/tax-categories');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    return (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createTaxCategory(Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$_baseUrl/finance-settings/tax-categories'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create failed');
    }
    return jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateTaxCategory(String id, Map<String, dynamic> data) async {
    final resp = await http.put(Uri.parse('$_baseUrl/finance-settings/tax-categories/$id'), headers: _headers, body: jsonEncode(data));
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteTaxCategory(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/finance-settings/tax-categories/$id'), headers: _headers);
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }
}
