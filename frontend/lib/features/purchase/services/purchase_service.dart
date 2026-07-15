import 'dart:convert';
import 'package:http/http.dart' as http;

class VendorModel {
  final String id;
  final String orgId;
  final String vendorCode;
  final String name;
  final String taxNumber;
  final String currency;
  final String paymentTerms;
  final String status;
  final double aiRating;
  final int leadTimeDays;
  final String address;
  final String contactPerson;
  final String contactEmail;
  final String contactPhone;
  final String? reconciliationAccountId;
  final String reconciliationAccountCode;
  final String reconciliationAccountName;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  VendorModel({
    required this.id,
    required this.orgId,
    required this.vendorCode,
    required this.name,
    this.taxNumber = '',
    this.currency = 'USD',
    this.paymentTerms = 'Net 30',
    this.status = 'active',
    this.aiRating = 0,
    this.leadTimeDays = 0,
    this.address = '',
    this.contactPerson = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.reconciliationAccountId,
    this.reconciliationAccountCode = '',
    this.reconciliationAccountName = '',
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      vendorCode: json['vendor_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      taxNumber: json['tax_number']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      paymentTerms: json['payment_terms']?.toString() ?? 'Net 30',
      status: json['status']?.toString() ?? 'active',
      aiRating: (json['ai_rating'] as num?)?.toDouble() ?? 0,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 0,
      address: json['address']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString() ?? '',
      contactEmail: json['contact_email']?.toString() ?? '',
      contactPhone: json['contact_phone']?.toString() ?? '',
      reconciliationAccountId: json['reconciliation_account_id']?.toString(),
      reconciliationAccountCode:
          json['reconciliation_account_code']?.toString() ?? '',
      reconciliationAccountName:
          json['reconciliation_account_name']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class PurchaseOrderModel {
  final String id;
  final String orgId;
  final String poNumber;
  final String vendorId;
  final String vendorName;
  final String vendorCode;
  final double totalAmount;
  final String currency;
  final String status;
  final String notes;
  final String createdAt;
  final String updatedAt;
  final String? organizationId;
  final String orgCode;
  final String orgName;
  final String poDate;
  final String paymentTermCode;
  final String deliveryAddress;
  final String incotermCode;
  final List<PurchaseOrderItemModel> items;

  PurchaseOrderModel({
    required this.id,
    required this.orgId,
    required this.poNumber,
    required this.vendorId,
    this.vendorName = '',
    this.vendorCode = '',
    this.totalAmount = 0,
    this.currency = 'USD',
    this.status = 'DRAFT',
    this.notes = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.organizationId,
    this.orgCode = '',
    this.orgName = '',
    this.poDate = '',
    this.paymentTermCode = '',
    this.deliveryAddress = '',
    this.incotermCode = '',
    this.items = const [],
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      vendorCode: json['vendor_code']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      status: json['status']?.toString() ?? 'DRAFT',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      organizationId: json['organization_id']?.toString(),
      orgCode: json['org_code']?.toString() ?? '',
      orgName: json['org_name']?.toString() ?? '',
      poDate: json['po_date']?.toString() ?? '',
      paymentTermCode: json['payment_term_code']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      incotermCode: json['incoterm_code']?.toString() ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) =>
                    PurchaseOrderItemModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

class PurchaseOrderItemModel {
  final String id;
  final String poId;
  final String itemId;
  final String itemSku;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double receivedQuantity;
  final double invoicedQuantity;
  final double openInvoiceQty;
  final String unitOfMeasure;
  final double lineTotal;
  final String? expectedDeliveryDate;
  final String deliveryAddress;

  PurchaseOrderItemModel({
    required this.id,
    required this.poId,
    required this.itemId,
    this.itemSku = '',
    this.itemName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.receivedQuantity = 0,
    this.invoicedQuantity = 0,
    this.openInvoiceQty = 0,
    this.unitOfMeasure = 'EA',
    this.lineTotal = 0,
    this.expectedDeliveryDate,
    this.deliveryAddress = '',
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      id: json['id']?.toString() ?? '',
      poId: json['po_id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemSku: json['item_sku']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
      invoicedQuantity: (json['invoiced_quantity'] as num?)?.toDouble() ?? 0,
      openInvoiceQty: (json['open_invoice_qty'] as num?)?.toDouble() ?? 0,
      unitOfMeasure: json['unit_of_measure']?.toString() ?? 'EA',
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      expectedDeliveryDate: json['expected_delivery_date']?.toString(),
      deliveryAddress: json['delivery_address']?.toString() ?? '',
    );
  }
}

class PurchaseReceiptModel {
  final String id;
  final String orgId;
  final String poId;
  final String itemId;
  final String siteId;
  final String? binId;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final String batchNo;
  final String receiptDate;
  final bool isReversed;
  final String? reversedAt;
  final String poNumber;
  final String itemSku;
  final String itemName;
  final String siteCode;
  final String siteName;
  final String receiptSource;

  PurchaseReceiptModel({
    required this.id,
    required this.orgId,
    required this.poId,
    required this.itemId,
    required this.siteId,
    this.binId,
    this.quantity = 0,
    this.unitCost = 0,
    this.totalCost = 0,
    this.batchNo = '',
    this.receiptDate = '',
    this.isReversed = false,
    this.reversedAt,
    this.poNumber = '',
    this.itemSku = '',
    this.itemName = '',
    this.siteCode = '',
    this.siteName = '',
    this.receiptSource = 'PO',
  });

  factory PurchaseReceiptModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      poId: json['po_id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      binId: json['bin_id']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      batchNo: json['batch_no']?.toString() ?? '',
      receiptDate: json['receipt_date']?.toString() ?? '',
      isReversed:
          json['is_reversed'] == true ||
          json['is_reversed']?.toString() == 'true',
      reversedAt: json['reversed_at']?.toString(),
      poNumber: json['po_number']?.toString() ?? '',
      itemSku: json['item_sku']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      siteCode: json['site_code']?.toString() ?? '',
      siteName: json['site_name']?.toString() ?? '',
      receiptSource: json['receipt_source']?.toString() ?? 'PO',
    );
  }

  bool get isWorkOrderReceipt => receiptSource == 'WORK_ORDER';
}

class InvoiceItemModel {
  final String id;
  final String invoiceId;
  final String? poItemId;
  final String itemId;
  final String itemSku;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double grQuantity;
  final double poUnitPrice;
  final double priceDiff;

  InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    this.poItemId,
    required this.itemId,
    this.itemSku = '',
    this.itemName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.grQuantity = 0,
    this.poUnitPrice = 0,
    this.priceDiff = 0,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      poItemId: json['po_item_id']?.toString(),
      itemId: json['item_id']?.toString() ?? '',
      itemSku: json['item_sku']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      grQuantity: (json['gr_quantity'] as num?)?.toDouble() ?? 0,
      poUnitPrice: (json['po_unit_price'] as num?)?.toDouble() ?? 0,
      priceDiff: (json['price_diff'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PurchaseInvoiceModel {
  final String id;
  final String orgId;
  final String invoiceNumber;
  final String vendorId;
  final String? poId;
  final String invoiceDate;
  final double totalAmount;
  final double taxAmount;
  final String currency;
  final String status;
  final String matchStatus;
  final String notes;
  final String vendorName;
  final String poNumber;
  final List<InvoiceItemModel> items;

  PurchaseInvoiceModel({
    required this.id,
    required this.orgId,
    required this.invoiceNumber,
    required this.vendorId,
    this.poId,
    this.invoiceDate = '',
    this.totalAmount = 0,
    this.taxAmount = 0,
    this.currency = 'USD',
    this.status = 'PENDING',
    this.matchStatus = '',
    this.notes = '',
    this.vendorName = '',
    this.poNumber = '',
    this.items = const [],
  });

  factory PurchaseInvoiceModel.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      poId: json['po_id']?.toString(),
      invoiceDate: json['invoice_date']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      status: json['status']?.toString() ?? 'PENDING',
      matchStatus: json['match_status']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PurchaseService {
  final String _baseUrl = 'http://localhost:8080/api/v1';
  String? _token;

  PurchaseService(this._token);

  /// Allow late token update (e.g., when screen is instantiated before token is ready)
  void updateToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  // ══════════════════════════════════════════
  //  VENDORS
  // ══════════════════════════════════════════

  Exception _apiException(http.Response resp, String fallback) {
    try {
      final body = jsonDecode(resp.body);
      return Exception(body['message'] ?? fallback);
    } catch (_) {
      return Exception(fallback);
    }
  }

  Future<List<VendorModel>> listVendors({String? query}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    final uri = Uri.parse(
      '$_baseUrl/purchase/vendors',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => VendorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VendorModel> getVendor(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/vendors/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return VendorModel.fromJson(body['data'] as Map<String, dynamic>? ?? {});
  }

  Future<VendorModel> createVendor(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/vendors'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create vendor failed');
    }
    final body = jsonDecode(resp.body);
    return VendorModel.fromJson(body['data'] as Map<String, dynamic>? ?? {});
  }

  Future<void> updateVendor(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/purchase/vendors/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update vendor failed');
    }
  }

  Future<void> deleteVendor(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/purchase/vendors/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete vendor failed');
    }
  }

  /// Fetch GL accounts with reconciliation_type = 'vendor' for dropdown selection.
  Future<List<Map<String, dynamic>>> listVendorReconciliationAccounts() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/gl/accounts?reconciliation_type=vendor'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    // Filter on client side in case server doesn't support the query param
    return data
        .cast<Map<String, dynamic>>()
        .where((a) => (a['reconciliation_type']?.toString() ?? '') == 'vendor')
        .toList();
  }

  Future<List<Map<String, dynamic>>> recommendVendors({
    String? productId,
  }) async {
    final params = <String, String>{};
    if (productId != null) params['product_id'] = productId;
    final uri = Uri.parse(
      '$_baseUrl/purchase/vendors/recommend',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════
  //  PURCHASE ORDERS
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listInfoRecords({
    String? query,
    String? productId,
    String? vendorId,
    String? siteId,
  }) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (productId != null && productId.isNotEmpty) {
      params['product_id'] = productId;
    }
    if (vendorId != null && vendorId.isNotEmpty) params['vendor_id'] = vendorId;
    if (siteId != null && siteId.isNotEmpty) params['site_id'] = siteId;
    final resp = await http.get(
      Uri.parse(
        '$_baseUrl/purchase/info-records',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      throw Exception('API error: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createInfoRecord(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/info-records'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create info record failed');
    }
    return Map<String, dynamic>.from(jsonDecode(resp.body)['data'] as Map);
  }

  Future<void> updateInfoRecord(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/purchase/info-records/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update info record failed');
    }
  }

  Future<void> deleteInfoRecord(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/purchase/info-records/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Delete info record failed');
    }
  }

  Future<List<Map<String, dynamic>>> listPRs({
    String? status,
    String? query,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (query != null && query.isNotEmpty) params['q'] = query;
    final resp = await http.get(
      Uri.parse(
        '$_baseUrl/purchase/requisitions',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'List PRs failed');
    final data = jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getPR(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/requisitions/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Get PR failed');
    return Map<String, dynamic>.from(jsonDecode(resp.body)['data'] as Map);
  }

  Future<Map<String, dynamic>> createPR(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Create PR failed');
    return Map<String, dynamic>.from(jsonDecode(resp.body)['data'] as Map);
  }

  Future<void> updatePR(String id, Map<String, dynamic> data) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/purchase/requisitions/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Update PR failed');
  }

  Future<void> deletePR(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/purchase/requisitions/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Delete PR failed');
  }

  Future<void> submitPR(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions/$id/submit'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Submit PR failed');
  }

  Future<void> approvePR(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions/$id/approve'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Approve PR failed');
  }

  Future<void> rejectPR(String id, String reason) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions/$id/reject'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Reject PR failed');
  }

  Future<List<dynamic>> convertPRToPO(String id, {bool all = true}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions/$id/convert-to-po'),
      headers: _headers,
      body: jsonEncode({'all': all}),
    );
    if (resp.statusCode >= 400) throw _apiException(resp, 'Convert PR failed');
    return jsonDecode(resp.body)['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> importMRPPRs() async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/requisitions/import-mrp'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      throw _apiException(resp, 'Import MRP PR failed');
    }
    return Map<String, dynamic>.from(jsonDecode(resp.body)['data'] as Map);
  }

  Future<PurchaseOrderModel> createPO(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/orders'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create PO failed');
    }
    final body = jsonDecode(resp.body);
    return PurchaseOrderModel.fromJson(
      body['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<PurchaseOrderModel> updatePO(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/purchase/orders/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update PO failed');
    }
    final body = jsonDecode(resp.body);
    return PurchaseOrderModel.fromJson(
      body['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<List<PurchaseOrderModel>> listPOs({
    String? status,
    String? vendorId,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (vendorId != null && vendorId.isNotEmpty) params['vendor_id'] = vendorId;
    final uri = Uri.parse(
      '$_baseUrl/purchase/orders',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PurchaseOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseOrderModel> getPO(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/orders/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return PurchaseOrderModel.fromJson(
      body['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<void> updatePOStatus(String id, String status) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/purchase/orders/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Update PO status failed');
    }
  }

  // ══════════════════════════════════════════
  //  PURCHASE RECEIPTS
  // ══════════════════════════════════════════

  Future<Map<String, dynamic>> executeGoodsReceipt(
    Map<String, dynamic> data,
  ) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/receipts'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Execute goods receipt failed');
    }
    return jsonDecode(resp.body);
  }

  Future<List<PurchaseReceiptModel>> listReceipts({String? poId}) async {
    final params = <String, String>{};
    if (poId != null && poId.isNotEmpty) params['po_id'] = poId;
    final uri = Uri.parse(
      '$_baseUrl/purchase/receipts',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PurchaseReceiptModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> reverseReceipt(String receiptId) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/receipts/$receiptId/reverse'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Reverse failed');
    }
  }

  // ══════════════════════════════════════════
  //  PURCHASE INVOICES
  // ══════════════════════════════════════════

  Future<void> reverseWorkOrderReceipt(String receiptId) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/work-order-receipts/$receiptId/reverse'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Reverse work order receipt failed');
    }
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/invoices'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Create invoice failed');
    }
    return jsonDecode(resp.body);
  }

  Future<void> postInvoice(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/invoices/$id/post'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Post invoice failed');
    }
  }

  Future<void> cancelInvoice(String id) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/purchase/invoices/$id/cancel'),
      headers: _headers,
    );
    if (resp.statusCode >= 400) {
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Cancel invoice failed');
    }
  }

  Future<List<PurchaseInvoiceModel>> listInvoices({String? vendorId}) async {
    final params = <String, String>{};
    if (vendorId != null && vendorId.isNotEmpty) params['vendor_id'] = vendorId;
    final uri = Uri.parse(
      '$_baseUrl/purchase/invoices',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PurchaseInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseInvoiceModel> getInvoice(String id) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/invoices/$id'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    return PurchaseInvoiceModel.fromJson(
      body['data'] as Map<String, dynamic>? ?? {},
    );
  }

  // ══════════════════════════════════════════
  //  ATTACHMENTS
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listPOAttachments(String poId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/orders/$poId/attachments'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    return ((jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> uploadPOAttachment(
    String poId,
    String filePath,
    String fileName,
  ) async {
    final uri = Uri.parse('$_baseUrl/purchase/orders/$poId/attachments');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );
    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    if (resp.statusCode >= 400)
      throw Exception('Upload failed: ${resp.statusCode}');
  }

  // ══════════════════════════════════════════
  //  PENDING INVOICE POs
  // ══════════════════════════════════════════

  Future<List<PurchaseOrderModel>> listPendingInvoicePOs() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/purchase/pending-invoice-pos'),
      headers: _headers,
    );
    if (resp.statusCode >= 400)
      throw Exception('API error: ${resp.statusCode}');
    final body = jsonDecode(resp.body);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PurchaseOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Format amount with thousand separators
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
