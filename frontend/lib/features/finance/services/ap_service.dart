import 'dart:convert';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════
//  Models
// ═══════════════════════════════════════════

class DownPaymentModel {
  final String id;
  final String orgId;
  final String dpNumber;
  final String vendorId;
  final String vendorCode;
  final String vendorName;
  final String poId;
  final String poNumber;
  final double totalAmount;
  final double paidAmount;
  final double refundedAmount;
  final double clearedAmount;
  final double remainingAmount;
  final String currency;
  final double exchangeRate;
  final String apDpAccountId;
  final String apDpAccountCode;
  final String apDpAccountName;
  final String creditAccountId;
  final String creditAccountCode;
  final String creditAccountName;
  final String status;
  final String paymentStatus;
  final String? glJeId;
  final String? paymentGlJeId;
  final String description;
  final String referenceNo;
  final String specialGlIndicator;
  final String? createdBy;
  final String createdAt;
  final String? updatedBy;
  final String updatedAt;
  final String? postedBy;
  final String? postedAt;

  DownPaymentModel({
    required this.id,
    required this.orgId,
    required this.dpNumber,
    required this.vendorId,
    this.vendorCode = '',
    this.vendorName = '',
    required this.poId,
    this.poNumber = '',
    required this.totalAmount,
    this.paidAmount = 0,
    this.refundedAmount = 0,
    this.clearedAmount = 0,
    this.remainingAmount = 0,
    this.currency = 'USD',
    this.exchangeRate = 1,
    required this.apDpAccountId,
    this.apDpAccountCode = '',
    this.apDpAccountName = '',
    required this.creditAccountId,
    this.creditAccountCode = '',
    this.creditAccountName = '',
    this.status = 'DRAFT',
    this.paymentStatus = 'UNPAID',
    this.glJeId,
    this.paymentGlJeId,
    this.description = '',
    this.referenceNo = '',
    this.specialGlIndicator = 'A',
    this.createdBy,
    this.createdAt = '',
    this.updatedBy,
    this.updatedAt = '',
    this.postedBy,
    this.postedAt,
  });

  factory DownPaymentModel.fromJson(Map<String, dynamic> json) {
    return DownPaymentModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      dpNumber: json['dp_number']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      vendorCode: json['vendor_code']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      poId: json['po_id']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (json['refunded_amount'] as num?)?.toDouble() ?? 0,
      clearedAmount: (json['cleared_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1,
      apDpAccountId: json['ap_dp_account_id']?.toString() ?? '',
      apDpAccountCode: json['ap_dp_account_code']?.toString() ?? '',
      apDpAccountName: json['ap_dp_account_name']?.toString() ?? '',
      creditAccountId: json['credit_account_id']?.toString() ?? '',
      creditAccountCode: json['credit_account_code']?.toString() ?? '',
      creditAccountName: json['credit_account_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      paymentStatus: json['payment_status']?.toString() ?? 'UNPAID',
      glJeId: json['gl_je_id']?.toString(),
      paymentGlJeId: json['payment_gl_je_id']?.toString(),
      description: json['description']?.toString() ?? '',
      referenceNo: json['reference_no']?.toString() ?? '',
      specialGlIndicator: json['special_gl_indicator']?.toString() ?? 'A',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
      updatedAt: json['updated_at']?.toString() ?? '',
      postedBy: json['posted_by']?.toString(),
      postedAt: json['posted_at']?.toString(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT': return 'Draft';
      case 'POSTED': return 'Posted';
      case 'PARTIALLY_CLEARED': return 'Partially Cleared';
      case 'FULLY_CLEARED': return 'Fully Cleared';
      case 'PARTIALLY_REFUNDED': return 'Partially Refunded';
      case 'REVERSED': return 'Reversed';
      case 'FULLY_REFUNDED': return 'Fully Refunded';
      default: return status;
    }
  }

  bool get canRefund => status == 'POSTED' || status == 'PARTIALLY_CLEARED';
  bool get canClear => status == 'POSTED' || status == 'PARTIALLY_CLEARED';
  bool get canReverse => status == 'POSTED'; // only clean POSTED DPs can be reversed
}

class JELineModel {
  final String id;
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;
  final String description;

  JELineModel({
    required this.id,
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
    required this.description,
  });

  factory JELineModel.fromJson(Map<String, dynamic> json) {
    return JELineModel(
      id: json['id']?.toString() ?? '',
      accountCode: json['account_code']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }
}

class DPRefundModel {
  final String id;
  final String dpId;
  final double refundAmount;
  final String refundDate;
  final String refundMethod;
  final String sourceAccountId;
  final String sourceAccountCode;
  final String sourceAccountName;
  final String? glJeId;
  final String? paymentGlJeId;
  final String reason;
  final String createdAt;

  DPRefundModel({
    required this.id,
    required this.dpId,
    required this.refundAmount,
    required this.refundDate,
    required this.refundMethod,
    required this.sourceAccountId,
    this.sourceAccountCode = '',
    this.sourceAccountName = '',
    this.glJeId,
    this.paymentGlJeId,
    required this.reason,
    this.createdAt = '',
  });

  factory DPRefundModel.fromJson(Map<String, dynamic> json) {
    return DPRefundModel(
      id: json['id']?.toString() ?? '',
      dpId: json['dp_id']?.toString() ?? '',
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      refundDate: json['refund_date']?.toString() ?? '',
      refundMethod: json['refund_method']?.toString() ?? 'BANK_TRANSFER',
      sourceAccountId: json['source_account_id']?.toString() ?? '',
      sourceAccountCode: json['source_account_code']?.toString() ?? '',
      sourceAccountName: json['source_account_name']?.toString() ?? '',
      glJeId: json['gl_je_id']?.toString(),
      paymentGlJeId: json['payment_gl_je_id']?.toString(),
      reason: json['reason']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class DPClearingModel {
  final String id;
  final String dpId;
  final String invoiceId;
  final String invoiceNumber;
  final double clearingAmount;
  final String currency;
  final String? glJeId;
  final String notes;
  final String createdAt;

  DPClearingModel({
    required this.id,
    required this.dpId,
    required this.invoiceId,
    this.invoiceNumber = '',
    required this.clearingAmount,
    this.currency = 'USD',
    this.glJeId,
    this.notes = '',
    this.createdAt = '',
  });

  factory DPClearingModel.fromJson(Map<String, dynamic> json) {
    return DPClearingModel(
      id: json['id']?.toString() ?? '',
      dpId: json['dp_id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      clearingAmount: (json['clearing_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      glJeId: json['gl_je_id']?.toString(),
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

// ═══════════════════════════════════════════
//  Service
// ═══════════════════════════════════════════

class ApService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  final String? _token;

  ApService(this._token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  // ── Down Payments ──

  Future<DownPaymentModel> createDownPayment(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/down-payments'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create down payment');
    }
    final body = jsonDecode(resp.body);
    return DownPaymentModel.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  Future<List<DownPaymentModel>> listDownPayments({
    String? vendorId,
    String? status,
    String? dateFrom,
    String? dateTo,
    double? minAmount,
    double? maxAmount,
  }) async {
    final params = <String, String>{};
    if (vendorId != null && vendorId.isNotEmpty) params['vendor_id'] = vendorId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (minAmount != null) params['min_amount'] = minAmount.toString();
    if (maxAmount != null) params['max_amount'] = maxAmount.toString();
    final uri = Uri.parse('$_baseUrl/purchase/down-payments').replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => DownPaymentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DownPaymentModel> getDownPayment(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/down-payments/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return DownPaymentModel.fromJson(body['data'] as Map<String, dynamic>? ?? {});
  }

  Future<void> deleteDownPayment(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/purchase/down-payments/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to delete down payment');
    }
  }

  Future<void> postDownPayment(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/down-payments/$id/post'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to post down payment');
    }
  }

  Future<void> reverseDownPayment(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/down-payments/$id/reverse'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to reverse down payment');
    }
  }

  Future<Map<String, dynamic>> refundDownPayment(String id, Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/down-payments/$id/refund'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to refund down payment');
    }
    return jsonDecode(resp.body);
  }

  Future<List<DPClearingModel>> getDPClearings(String dpId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/down-payments/$dpId/clearings'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => DPClearingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Vendor Payments & Open Items ──

  Future<List<OpenItemModel>> getVendorOpenItems(String vendorId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/vendor-open-items?vendor_id=$vendorId'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => OpenItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createVendorPayment(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/vendor-payments'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Failed to create payment');
    }
  }

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

// ═══════════════════════════════════════════
//  Open Item Model
// ═══════════════════════════════════════════

class OpenItemModel {
  final String id;
  final String type; // 'INVOICE' or 'DOWN_PAYMENT'
  final String documentNo;
  final String date;
  final String dueDate;
  final double totalAmount;
  final double openAmount;
  final String currency;
  final bool isDownPayment;
  bool selected;

  OpenItemModel({
    required this.id,
    required this.type,
    required this.documentNo,
    required this.date,
    required this.dueDate,
    required this.totalAmount,
    required this.openAmount,
    required this.currency,
    required this.isDownPayment,
    this.selected = false,
  });

  factory OpenItemModel.fromJson(Map<String, dynamic> json) {
    return OpenItemModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      documentNo: json['document_no']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      openAmount: (json['open_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      isDownPayment: json['is_down_payment'] as bool? ?? false,
    );
  }

  String get typeLabel => isDownPayment ? 'Down Payment' : 'Invoice';
}
