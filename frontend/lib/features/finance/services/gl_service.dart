import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class AccountModel {
  final String id;
  final String code;
  final String name;
  final String type;
  final double balance;
  final String? parentId;
  final int level;
  final bool isActive;
  final bool isLeaf;
  final String? description;
  final String reconciliationType;
  final List<AccountModel>? children;

  AccountModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.balance = 0,
    this.parentId,
    this.level = 1,
    this.isActive = true,
    this.isLeaf = true,
    this.description,
    this.reconciliationType = 'none',
    this.children,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id']?.toString() ?? '',
      code: json['account_code']?.toString() ?? json['code']?.toString() ?? '',
      name: json['account_name']?.toString() ?? json['name']?.toString() ?? '',
      type: json['account_type']?.toString() ?? json['type']?.toString() ?? 'ASSET',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      parentId: json['parent_id']?.toString(),
      level: (json['level'] as int?) ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      isLeaf: json['is_leaf'] as bool? ?? true,
      description: json['description']?.toString(),
      reconciliationType: json['reconciliation_type']?.toString() ?? 'none',
      children: (json['children'] as List<dynamic>?)
          ?.map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// GAAP account type colors
  static Color typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'ASSET':
        return Colors.green;
      case 'LIABILITY':
        return Colors.orange;
      case 'EQUITY':
        return Colors.purple;
      case 'REVENUE':
        return Colors.blue;
      case 'EXPENSE':
        return Colors.red;
      case 'COGS':
        return Colors.brown;
      case 'OTHER_INCOME':
        return Colors.teal;
      case 'OTHER_EXPENSE':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Display name for GAAP account types
  static String typeDisplayName(String type) {
    switch (type.toUpperCase()) {
      case 'ASSET':
        return 'ASSET';
      case 'LIABILITY':
        return 'LIABILITY';
      case 'EQUITY':
        return 'EQUITY';
      case 'REVENUE':
        return 'REVENUE';
      case 'EXPENSE':
        return 'EXPENSE';
      case 'COGS':
        return 'COGS';
      case 'OTHER_INCOME':
        return 'OTHER INCOME';
      case 'OTHER_EXPENSE':
        return 'OTHER EXPENSE';
      default:
        return type;
    }
  }

  /// Reconciliation type display name
  static String reconciliationDisplayName(String recType) {
    switch (recType) {
      case 'customer':
        return 'Customer';
      case 'vendor':
        return 'Vendor';
      case 'asset':
        return 'Asset';
      default:
        return 'None';
    }
  }

  bool get isParent => !isLeaf;
}

class GlService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  GlService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ==================== Chart of Accounts CRUD ====================

  /// Get full account tree
  Future<List<AccountModel>> getAccountTree() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/accounts/tree'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => AccountModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// List all accounts
  Future<List<AccountModel>> getAccounts() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/accounts'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => AccountModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Search accounts by keyword
  Future<List<AccountModel>> searchAccounts(String query) async {
    final uri = Uri.parse('$_baseUrl/gl/accounts/search').replace(
      queryParameters: {'q': query},
    );
    final resp = await http.get(
      uri,
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => AccountModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get single account detail
  Future<AccountModel> getAccount(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/accounts/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return AccountModel.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// Create a new account
  Future<AccountModel> createAccount(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/gl/accounts'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create account');
    }
    final body = jsonDecode(resp.body);
    return AccountModel.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// Update an account
  Future<AccountModel> updateAccount(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/gl/accounts/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update account');
    }
    final body = jsonDecode(resp.body);
    return AccountModel.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// Delete (deactivate) an account
  Future<void> deleteAccount(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/gl/accounts/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to deactivate account');
    }
  }

  /// Reactivate a previously deactivated account
  Future<AccountModel> reactivateAccount(String id) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/gl/accounts/$id/reactivate'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to reactivate account');
    }
    final body = jsonDecode(resp.body);
    return AccountModel.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  // ==================== Journal Entries ====================

  Future<Map<String, dynamic>> createJournalEntry(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/gl/journal-entries'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create journal entry');
    }
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<List<dynamic>> listJournalEntries({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? entryType,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (entryType != null && entryType.isNotEmpty) params['entry_type'] = entryType;
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;

    final uri = Uri.parse('$_baseUrl/gl/journal-entries').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as List<dynamic>? ?? [];
  }

  /// Get single journal entry detail
  Future<Map<String, dynamic>> getJournalEntry(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/journal-entries/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Reverse a posted journal entry
  Future<Map<String, dynamic>> unpostJournalEntry(String id) async {
    final resp = await http.post(
      Uri.parse('\/gl/journal-entries/\/unpost'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to unpost journal entry');
    }
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<Map<String, dynamic>> reverseJournalEntry(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/gl/journal-entries/$id/reverse'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to reverse journal entry');
    }
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Update journal entry status (draft / posted)
  Future<Map<String, dynamic>> updateJournalEntryStatus(String id, String status) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/gl/journal-entries/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update journal entry status');
    }
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Update a draft journal entry (header + lines replacement)
  Future<Map<String, dynamic>> updateJournalEntry(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/gl/journal-entries/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to update journal entry');
    }
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  /// Post a draft journal entry (change status to 'posted', updates gl_account_balances)
  Future<Map<String, dynamic>> postJournalEntry(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/gl/journal-entries/post'),
      headers: _headers,
      body: jsonEncode({'entry_ids': [id]}),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to post journal entry');
    }
    jsonDecode(resp.body); // discard batch post response
    // Return the posted entry detail
    return await getJournalEntry(id);
  }

  /// Delete a draft journal entry
  Future<void> deleteJournalEntry(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/gl/journal-entries/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete journal entry');
    }
  }

  /// Get account ledger (running balance)
  Future<List<dynamic>> getAccountLedger(String accountId, {String? from, String? to, int page = 1, int pageSize = 50}) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final uri = Uri.parse('$_baseUrl/gl/accounts/$accountId/ledger').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as List<dynamic>? ?? [];
  }

  /// Get account balances by period
  Future<List<dynamic>> getAccountBalances({int? year, int? month}) async {
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse('$_baseUrl/gl/balances').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as List<dynamic>? ?? [];
  }

  /// Get balance sheet report
  Future<Map<String, dynamic>> getBalanceSheet({int year = 2026, int month = 0}) async {
    final params = <String, String>{'year': '$year', 'month': '$month'};
    final uri = Uri.parse('$_baseUrl/gl/reports/balance-sheet').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get profit & loss report
  Future<Map<String, dynamic>> getProfitLoss({int year = 2026, int month = 0}) async {
    final params = <String, String>{'year': '$year', 'month': '$month'};
    final uri = Uri.parse('$_baseUrl/gl/reports/profit-loss').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get all attachments for a journal entry
  Future<List<Map<String, dynamic>>> getAttachments(String entryId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/journal-entries/$entryId/attachments'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> uploadAttachments(String entryId, List<PlatformFile> files) async {
    for (final file in files) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/gl/journal-entries/$entryId/attachments'),
        );
        request.headers['Authorization'] = 'Bearer $_token';

        if (file.bytes != null) {
          // Web: use bytes directly
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ));
        } else if (file.path != null) {
          // Mobile/Desktop: use path
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        } else {
          continue; // skip if no data available
        }

        if (file.name.isNotEmpty) {
          request.fields['description'] = file.name;
        }
        final streamed = await request.send();
        if (streamed.statusCode >= 400) {
          throw Exception('Failed to upload attachment: ${file.name}');
        }
      } catch (e) {
        // Log attachment error but don't fail the whole entry save
        debugPrint('Attachment upload skipped for ${file.name}: $e');
      }
    }
  }

  // ==================== AI Suggestion ====================

  Future<Map<String, dynamic>> aiSuggest(String description, double amount) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/gl/ai/suggest'),
      headers: _headers,
      body: jsonEncode({'natural_language': description, 'amount': amount}),
    );
    if (resp.statusCode >= 400) throw Exception('AI suggestion failed: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  // ==================== Dashboard ====================

  Future<void> initializeCoa(String coaType) async {
    final resp = await http.post(
      Uri.parse('${_baseUrl}/gl/initialize-coa'),
      headers: _headers,
      body: jsonEncode({'coa_type': coaType}),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to initialize COA');
    }
  }

  Future<void> resetDatabase() async {
    final resp = await http.post(
      Uri.parse('${_baseUrl}/gl/reset-database'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to reset database');
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    // Get accounts count
    final accounts = await getAccounts();
    final entries = await listJournalEntries();
    return {
      'total_accounts': accounts.length,
      'total_entries': entries.length,
    };
  }

  // ==================== Periods ====================

  /// Check if the period for a given date is open.
  /// Returns true if open, false if closed/locked.
  Future<bool> isPeriodOpenForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_baseUrl/periods').replace(queryParameters: {
      'date': dateStr,
    });
    try {
      final resp = await http.get(uri, headers: _headers);
      if (resp.statusCode >= 400) return false;
      final body = jsonDecode(resp.body);
      final data = body['data'] as List<dynamic>? ?? [];
      if (data.isEmpty) return false;
      // Find the period that contains the given date
      for (final p in data) {
        final start = DateTime.tryParse(p['start_date']?.toString() ?? '');
        final end = DateTime.tryParse(p['end_date']?.toString() ?? '');
        if (start != null && end != null &&
            !date.isBefore(start) && !date.isAfter(end)) {
          return p['is_open'] == true && p['is_locked'] != true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Format a number with thousand separators: 1000000.00 → "1,000,000.00"
  static String fmtAmount(num? value) {
    final v = (value ?? 0).toDouble();
    if (v.isNaN || v.isInfinite) return "0.00";
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }
}
