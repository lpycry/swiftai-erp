import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class SalesOrderFormScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? importQuotation;
  const SalesOrderFormScreen({super.key, required this.authService, required this.salesService, this.order, this.importQuotation});
  @override State<SalesOrderFormScreen> createState() => _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState extends State<SalesOrderFormScreen> with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════
  //  Constants & Config
  // ═══════════════════════════════════════════════
  static const String _baseUrl = 'http://localhost:8080/api/v1';

  final _formKey = GlobalKey<FormState>();
  bool _saving = false, _loadingEdit = false;
  late TabController _tabCtrl;

  String? _customerId, _employeeId, _orderId;
  String _currency = 'USD', _paymentTerms = 'Net 30', _orderType = 'OR';

  final _custPOCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _carrier, _serviceType;
  final _shipperAcctCtrl = TextEditingController();
  final _payerAcctCtrl = TextEditingController();
  final _billAddrCtrl = TextEditingController();
  String? _shipToCustomerId;
  bool _insuranceEnabled = false;
  String _transportationTo = 'Shipper';

  DateTime _orderDate = DateTime.now();
  DateTime? _deliveryDate, _requestedShipDate, _poDate;
  bool _signatureReq = false, _saturdayDel = false, _calculatingTax = false;

  List<dynamic> _customers = [], _products = [], _employees = [], _deliveryBlocks = [], _carrierServiceTypes = [], _incoterms = [], _paymentTermsList = [];
  String _incoterm = '';
  String _orderStatus = '';
  String? _deliveryBlockId;
  final List<_SOLineItem> _items = [];
  final Map<int, String> _atpStatus = {};       // line index → ATP status
  final Map<int, double> _atpAvailable = {};    // line index → available qty
  Timer? _atpTimer;
  List<dynamic> _pricingConditions = [];         // pricing breakdown from engine

  bool get isEdit => _orderId != null;
  String get _token => widget.authService.accessToken ?? '';

    /// 从 carrier_service_types 中提取唯一运商列表
  List<String> get _uniqueCarriers {
    final set = <String>{};
    for (final item in _carrierServiceTypes) {
      final c = item['carrier']?.toString();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  /// 当前选中 ship-to 客户的 shipping address 文本
  String get _selectedShipToAddress {
    final id = _shipToCustomerId ?? _customerId;
    if (id == null) return '';
    final cust = _customers.cast<Map<String,dynamic>?>().firstWhere(
      (c) => c?['id']?.toString() == id, orElse: () => null);
    if (cust == null) return '';
    final parts = <String>[
      cust['name'] ?? '',
      cust['shipping_street'] ?? '',
      cust['shipping_city'] ?? '',
      cust['shipping_state'] ?? '',
      cust['shipping_zip'] ?? '',
      cust['shipping_country'] ?? '',
    ]..removeWhere((s) => s.isEmpty);
    return parts.join(', ');
  }

  /// 当前选中 carrier 对应的 service type 列表
  List<String> get _serviceTypesForCarrier {
    if (_carrier == null) return [];
    return _carrierServiceTypes
        .where((item) => item['carrier']?.toString() == _carrier && item['is_active'] == true)
        .map((item) => item['service_type']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList()..sort();
  }

  /// 收集已保存的 shipping/bill-to 摘要(仅编辑模式显示)
  Map<String, String> _shippingSummary() {
    final m = <String, String>{};
    if (_carrier != null) m['Carrier'] = _carrier!;
    if (_serviceType != null) m['Service Type'] = _serviceType!;
    if (_shipperAcctCtrl.text.isNotEmpty) m['Shipper Acct'] = _shipperAcctCtrl.text;
    if (_insuranceEnabled) m['Insurance'] = 'Yes';
    if (_signatureReq) m['Signature Required'] = 'Yes';
    if (_saturdayDel) m['Saturday Delivery'] = 'Yes';
    if (_transportationTo.isNotEmpty) m['Transport To'] = _transportationTo;
    if (_payerAcctCtrl.text.isNotEmpty) m['Payer Account'] = _payerAcctCtrl.text;
    if (_billAddrCtrl.text.isNotEmpty) m['Bill-To Address'] = _billAddrCtrl.text;
    if (_deliveryBlockId != null) {
      final db = _deliveryBlocks.cast<Map<String,dynamic>?>().firstWhere((d) => d?['id']?.toString() == _deliveryBlockId, orElse: () => null);
      if (db != null) m['Delivery Block'] = '${db['block_code']} - ${db['description']}';
    }
    return m;
  }

  List<dynamic> _orderTypes = [];
  /// Attachments for the Notes tab
  final List<PlatformFile> _attachedFiles = [];

  // ═══════════════════════════════════════════════
  //  Init & Dispose
  // ═══════════════════════════════════════════════

  @override void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    // Determine order id from passed-in order data
    final o = widget.order ?? widget.importQuotation;
    if (o != null) {
      _orderId = o['id']?.toString();
      _customerId = o['customer_id']?.toString();
      _employeeId = o['employee_id']?.toString();
      _currency = o['currency'] ?? 'USD';
      _paymentTerms = o['payment_terms'] ?? 'Net 30';
      _orderType = o['order_type'] ?? o['so_type'] ?? o['quotation_type'] ?? 'OR';
      _custPOCtrl.text = o['customer_po_no'] ?? '';
      _discountCtrl.text = (o['discount_pct'] as num?)?.toString() ?? '';
      _notesCtrl.text = o['notes']?.toString() ?? '';
      _incoterm = o['incoterm'] ?? '';
      _carrier = o['carrier'];
      _serviceType = o['shipping_method'];  // actually shipping_method in backend
      _shipperAcctCtrl.text = o['shipper_account'] ?? '';
      _insuranceEnabled = ((o['insurance_amt'] as num?)?.toDouble() ?? 0) > 0;
      _transportationTo = o['transportation_to'] ?? 'Shipper';
      _shipToCustomerId = o['ship_to_customer_id']?.toString();
      _payerAcctCtrl.text = o['transport_payer_account'] ?? '';
      _billAddrCtrl.text = o['bill_to_address'] ?? '';
      _signatureReq = o['signature_required'] == true;
      _saturdayDel = o['saturday_delivery'] == true;
      if (o['order_date'] != null) _orderDate = DateTime.tryParse(o['order_date'].toString()) ?? DateTime.now();
      _deliveryDate = DateTime.tryParse(o['delivery_date']?.toString() ?? '');
      _requestedShipDate = DateTime.tryParse(o['requested_ship_date']?.toString() ?? o['requested_date']?.toString() ?? '');
      _poDate = DateTime.tryParse(o['po_date']?.toString() ?? '');
      _deliveryBlockId = o['delivery_block_id']?.toString();

      // Import items (if present in passed data - list API doesn't include them)
      final srcItems = (o['items'] as List<dynamic>?) ?? (o['Items'] as List<dynamic>?) ?? [];
      for (final it in srcItems) {
        _items.add(_SOLineItem(
          productId: it['product_id']?.toString() ?? '', productSku: it['product_sku']?.toString() ?? '',
          productName: it['product_name']?.toString() ?? '', description: it['description']?.toString() ?? '',
          quantity: (it['quantity'] as num?)?.toDouble() ?? 1, uom: it['unit_of_measure']?.toString() ?? 'EA',
          unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0, discountPct: (it['discount_pct'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    _loadLookups();
  }

  @override void dispose() {
    _tabCtrl.dispose();
    _custPOCtrl.dispose(); _discountCtrl.dispose(); _taxCtrl.dispose(); _notesCtrl.dispose();
    _attachedFiles.clear();
    _shipperAcctCtrl.dispose(); _payerAcctCtrl.dispose(); _billAddrCtrl.dispose();
    _atpTimer?.cancel();
    _pricingTimer?.cancel();
    for (final it in _items) { it.dispose(); }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/sales/customers'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/warehouse/products'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/employees?mode=current'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/sales/order-types?active_only=true'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/sales/delivery-blocks?active_only=true'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/sales/carrier-service-types'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/finance-settings/incoterms'), headers: {'Authorization': 'Bearer $_token'}),
        http.get(Uri.parse('$_baseUrl/finance-settings/payment-terms'), headers: {'Authorization': 'Bearer $_token'}),
      ]);
      if (results[0].statusCode < 400) _customers = jsonDecode(results[0].body)['data'] ?? [];
      if (results[1].statusCode < 400) _products = jsonDecode(results[1].body)['data'] ?? [];
      if (results[2].statusCode < 400) _employees = jsonDecode(results[2].body)['data'] ?? [];
      if (results[3].statusCode < 400) _orderTypes = jsonDecode(results[3].body)['data'] ?? [];
      if (results[4].statusCode < 400) _deliveryBlocks = jsonDecode(results[4].body)['data'] ?? [];
      if (results[5].statusCode < 400) _carrierServiceTypes = jsonDecode(results[5].body)['data'] ?? [];
      if (results[6].statusCode < 400) _incoterms = jsonDecode(results[6].body)['data'] ?? [];
      if (results[7].statusCode < 400) _paymentTermsList = jsonDecode(results[7].body)['data'] ?? [];
    } catch (_) {}

    // If editing an existing order from list (no items), fetch full detail
    if (widget.order != null && widget.importQuotation == null && _orderId != null && _items.isEmpty) {
      await _fetchFullOrder();
    }

    // Add a blank line item only if no items were loaded
    if (_items.isEmpty) _addItem();
    if (mounted) setState(() {});
  }

  /// Fetch complete order with items from backend (GET /orders/:id)
  Future<void> _fetchFullOrder() async {
    setState(() => _loadingEdit = true);
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/sales/orders/$_orderId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) {
        final data = (jsonDecode(resp.body)['data'] as Map<String, dynamic>?) ?? {};
        _populateFromOrderData(data);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingEdit = false);
  }

  /// Populate form fields from full order data (including items with prices)
  void _populateFromOrderData(Map<String, dynamic> o) {
    _customerId = o['customer_id']?.toString();
    _employeeId = o['employee_id']?.toString();
    _currency = o['currency'] ?? 'USD';
    _paymentTerms = o['payment_terms'] ?? 'Net 30';
    _orderType = o['so_type'] ?? o['order_type'] ?? 'OR';
    _custPOCtrl.text = o['customer_po_no'] ?? '';
    _discountCtrl.text = (o['discount_pct'] as num?)?.toString() ?? '';
    _notesCtrl.text = o['notes']?.toString() ?? '';
    _incoterm = o['incoterm'] ?? '';
    _carrier = o['carrier'];
    _serviceType = o['shipping_method'];
    _shipperAcctCtrl.text = o['shipper_account'] ?? '';
    _insuranceEnabled = ((o['insurance_amt'] as num?)?.toDouble() ?? 0) > 0;
    _transportationTo = o['transportation_to'] ?? 'Shipper';
    _shipToCustomerId = o['ship_to_customer_id']?.toString();
    _payerAcctCtrl.text = o['transport_payer_account'] ?? '';
    _billAddrCtrl.text = o['bill_to_address'] ?? '';
    _signatureReq = o['signature_required'] == true;
    _saturdayDel = o['saturday_delivery'] == true;
    _orderDate = DateTime.tryParse(o['order_date']?.toString() ?? o['valid_from']?.toString() ?? '') ?? DateTime.now();
    _deliveryDate = DateTime.tryParse(o['delivery_date']?.toString() ?? '');
    _requestedShipDate = DateTime.tryParse(o['requested_ship_date']?.toString() ?? o['requested_date']?.toString() ?? '');
    _poDate = DateTime.tryParse(o['po_date']?.toString() ?? '');
    _deliveryBlockId = o['delivery_block_id']?.toString();

    // Dispose old items and rebuild from full API data with prices
    for (final it in _items) { it.dispose(); }
    _items.clear();

    final srcItems = (o['items'] as List<dynamic>?) ?? (o['Items'] as List<dynamic>?) ?? [];
    for (final it in srcItems) {
      final unitPrice = (it['unit_price'] as num?)?.toDouble() ?? 0;
      final qty = (it['quantity'] as num?)?.toDouble() ?? 1;
      final disc = (it['discount_pct'] as num?)?.toDouble() ?? 0;
      _items.add(_SOLineItem(
        productId: it['product_id']?.toString() ?? '',
        productSku: it['product_sku']?.toString() ?? '',
        productName: it['product_name']?.toString() ?? '',
        description: it['description']?.toString() ?? '',
        quantity: qty, uom: it['unit_of_measure']?.toString() ?? 'EA',
        unitPrice: unitPrice, discountPct: disc,
        itemCode: (it['item_code'] as num?)?.toInt() ?? 100 + _items.length,
        lineTotal: (it['line_total'] as num?)?.toDouble() ?? (qty * unitPrice * (1 - disc / 100)),
        lineNo: (it['line_no'] as num?)?.toInt() ?? _items.length + 1,
      ));
    }
    // Regenerate sequential item codes after loading all items
    for (var j = 0; j < _items.length; j++) {
      _items[j].itemCode = j == 0 ? 100 : _items[j - 1].itemCode + 1;
      _items[j].itemCodeCtrl.text = _items[j].itemCode.toString();
    }
  }

  void _addItem() {
    final maxCode = _items.isEmpty ? 100 : _items.map((it) => it.itemCode).reduce((a, b) => a > b ? a : b) + 1;
    setState(() => _items.add(_SOLineItem(lineNo: _items.length + 1, itemCode: maxCode)));
  }

  void _onItemCodeChanged(int index, String value) {
    final code = int.tryParse(value);
    if (code == null) return;
    setState(() {
      _items[index].itemCode = code;
      // Auto-increment subsequent items from the edited value
      for (var j = index + 1; j < _items.length; j++) {
        _items[j].itemCode = _items[j - 1].itemCode + 1;
        _items[j].itemCodeCtrl.text = _items[j].itemCode.toString();
      }
    });
  }

  void _removeItem(int i) {
    if (_items.length > 1) {
      setState(() {
        final removed = _items.removeAt(i);
        removed.dispose();
      });
    }
  }

  double get _totalAmount => _items.fold(0.0, (s, it) => s + it.lineTotal);
  double get _discountAmount => _totalAmount * (double.tryParse(_discountCtrl.text) ?? 0) / 100;
  double get _netAmount => _totalAmount - _discountAmount;
  double get _taxAmount => double.tryParse(_taxCtrl.text) ?? 0;
  double get _grandTotal => _netAmount + _taxAmount + (_insuranceEnabled ? 1.0 : 0.0);

  void _recalc(_SOLineItem it) {
    final qty = double.tryParse(it.qtyCtrl.text) ?? 1;
    final price = double.tryParse(it.priceCtrl.text) ?? 0;
    final disc = double.tryParse(it.discCtrl.text) ?? 0;
    it.lineTotal = qty * price * (1 - disc / 100);
    setState(() {});
    _debouncedAtpCheck();
    _debouncedPricing();
  }

  Timer? _pricingTimer;
  bool _loadingPricing = false;

  void _debouncedAtpCheck() {
    _atpTimer?.cancel();
    _atpTimer = Timer(const Duration(milliseconds: 600), () => _runAtpCheck());
  }

  Future<void> _runAtpCheck() async {
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.productId.isEmpty) continue;
      final qty = double.tryParse(it.qtyCtrl.text) ?? 1;
      try {
        final resp = await http.get(
          Uri.parse('$_baseUrl/sales/atp-check?product_id=${it.productId}&quantity=$qty'),
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (resp.statusCode < 400) {
          final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>? ?? {};
          if (mounted) setState(() {
            _atpStatus[i] = data['status'] as String? ?? 'UNKNOWN';
            _atpAvailable[i] = (data['available'] as num?)?.toDouble() ?? 0;
          });
        }
      } catch (_) {}
    }
  }

  void _debouncedPricing() {
    _pricingTimer?.cancel();
    _pricingTimer = Timer(const Duration(milliseconds: 600), () => _runPricing());
  }

  Future<void> _runPricing() async {
    if (_customerId == null || _items.isEmpty || _items.every((it) => it.productId.isEmpty)) return;
    setState(() => _loadingPricing = true);
    try {
      final items = _items.where((it) => it.productId.isNotEmpty).map((it) => <String, dynamic>{
        'product_id': it.productId,
        'quantity': double.tryParse(it.qtyCtrl.text) ?? 1,
        'base_price': double.tryParse(it.priceCtrl.text) ?? 0,
        'discount_pct': double.tryParse(it.discCtrl.text) ?? 0,
      }).toList();
      if (items.isEmpty) return;
      final resp = await http.post(
        Uri.parse('$_baseUrl/sales/calculate-price'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'customer_id': _customerId, 'items': items}),
      );
      if (resp.statusCode < 400) {
        final data = (jsonDecode(resp.body)['data'] as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(() {
            _pricingConditions = data['conditions'] as List<dynamic>? ?? [];
            final resultItems = data['items'] as List<dynamic>? ?? [];
            for (int i = 0; i < resultItems.length && i < _items.length; i++) {
              _items[i].unitPrice = (resultItems[i]['base_price'] as num?)?.toDouble() ?? _items[i].unitPrice;
              final newDisc = (resultItems[i]['discount_pct'] as num?)?.toDouble() ?? _items[i].discountPct;
              if (newDisc != _items[i].discountPct) {
                _items[i].discountPct = newDisc;
                _items[i].discCtrl.text = newDisc.toStringAsFixed(0);
              }
              _items[i].lineTotal = (resultItems[i]['line_total'] as num?)?.toDouble() ?? _items[i].lineTotal;
            }
          });
        }
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingPricing = false); }
  }

  // ═══════════════════════════════════════════════
  //  Tax Calculation
  // ═══════════════════════════════════════════════

  Future<void> _calculateTax() async {
    if (_customerId == null) return;
    setState(() => _calculatingTax = true);
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/sales/quotations/calculate-tax'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'customer_id': _customerId, 'net_amount': _netAmount}),
      );
      if (resp.statusCode >= 400) { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Tax calc failed'); }
      final data = (jsonDecode(resp.body)['data'] as Map<String, dynamic>?) ?? {};
      final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
      final taxRate = (data['tax_rate'] as num?)?.toDouble() ?? 0;
      final source = data['source'] as String? ?? '';
      if (mounted) { setState(() => _taxCtrl.text = taxAmount.toStringAsFixed(2)); _msg('Tax: \$${taxAmount.toStringAsFixed(2)} at ${(taxRate*100).toStringAsFixed(1)}% - $source'); }
    } catch (e) { if (mounted) _msg('Tax calc error: $e', isError: true); }
    finally { if (mounted) setState(() => _calculatingTax = false); }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  // ═══════════════════════════════════════════════
  //  Date Picker Helper
  // ═══════════════════════════════════════════════

  Widget _dateField(String label, DateTime? dt, ValueChanged<DateTime> onSet, {bool optional = false}) {
    return InkWell(onTap: () async {
      final d = await showDatePicker(context: context, initialDate: dt ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
      if (d != null) onSet(d);
    }, child: InputDecorator(decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(dt == null ? (optional ? '(Optional)' : 'Select') : Fmt.d(dt), style: TextStyle(fontSize: 11, color: dt == null && optional ? Colors.grey.shade400 : null))));
  }

  // ═══════════════════════════════════════════════
  //  Build common save payload
  // ═══════════════════════════════════════════════

  Map<String, dynamic> _buildSavePayload() {
    final data = <String, dynamic>{
      'customer_id': _customerId, 'order_type': _orderType, 'currency': _currency, 'payment_terms': _paymentTerms,
      'customer_po_no': _custPOCtrl.text.trim(),
      'discount_pct': double.tryParse(_discountCtrl.text) ?? 0,
      'notes': _notesCtrl.text.trim(),
      'order_date': '${_orderDate.year}-${_orderDate.month.toString().padLeft(2,'0')}-${_orderDate.day.toString().padLeft(2,'0')}',
      'incoterm': _incoterm, 'carrier': _carrier ?? '', 'shipping_method': _serviceType ?? '', 'shipper_account': _shipperAcctCtrl.text.trim(),
      'signature_required': _signatureReq, 'saturday_delivery': _saturdayDel, 'insurance_amt': _insuranceEnabled ? 1.0 : 0.0,
      'transportation_to': _transportationTo, 'transport_payer_account': _payerAcctCtrl.text.trim(), 'bill_to_address': _billAddrCtrl.text.trim(),
      'tax_amount': double.tryParse(_taxCtrl.text) ?? 0,
      'items': _items.map((it) => <String, dynamic>{
        'product_id': it.productId, 'description': it.description,
        'quantity': double.tryParse(it.qtyCtrl.text) ?? 1, 'unit_of_measure': it.uom,
        'unit_price': double.tryParse(it.priceCtrl.text) ?? 0, 'discount_pct': double.tryParse(it.discCtrl.text) ?? 0,
      }).toList(),
    };
    if (_employeeId != null) data['employee_id'] = _employeeId;
    if (_deliveryDate != null) data['delivery_date'] = '${_deliveryDate!.year}-${_deliveryDate!.month.toString().padLeft(2,'0')}-${_deliveryDate!.day.toString().padLeft(2,'0')}';
    if (_requestedShipDate != null) data['requested_ship_date'] = '${_requestedShipDate!.year}-${_requestedShipDate!.month.toString().padLeft(2,'0')}-${_requestedShipDate!.day.toString().padLeft(2,'0')}';
    if (_poDate != null) data['po_date'] = '${_poDate!.year}-${_poDate!.month.toString().padLeft(2,'0')}-${_poDate!.day.toString().padLeft(2,'0')}';
    data['status'] = _orderStatus;
    if (widget.importQuotation != null) data['quotation_id'] = widget.importQuotation!['id']?.toString();
    if (_deliveryBlockId != null) data['delivery_block_id'] = _deliveryBlockId;
    if (_shipToCustomerId != null) data['ship_to_customer_id'] = _shipToCustomerId;
    return data;
  }

  // ═══════════════════════════════════════════════
  //  Save (Create or Update)
  // ═══════════════════════════════════════════════

  Future<void> _save() async {
    // Form only exists on Main tab — skip validate when on other tabs
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;

    // ── Determine status from OTC auto_confirm_so ──
    final otc = _orderTypes.cast<Map<String,dynamic>?>().firstWhere(
      (ot) => ot?['order_type'] == _orderType, orElse: () => null);
    final autoConfirm = otc?['auto_confirm_so'] == true;
    _orderStatus = autoConfirm ? 'CONFIRMED' : 'DRAFT';

    // ── Validation: Third Party Payer requires Bill-To fields ──
    if (_transportationTo == 'Third Party') {
      if (_payerAcctCtrl.text.trim().isEmpty && _billAddrCtrl.text.trim().isEmpty) {
        _msg('Payer is Third Party — Transport Payer Account and Bill-To Address are required', isError: true);
        return;
      }
      if (_payerAcctCtrl.text.trim().isEmpty) {
        _msg('Payer is Third Party — Transport Payer Account is required', isError: true);
        return;
      }
      if (_billAddrCtrl.text.trim().isEmpty) {
        _msg('Payer is Third Party — Bill-To Address is required', isError: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final data = _buildSavePayload();

      final http.Response resp;
      if (isEdit) {
        // ── UPDATE existing order ──
        resp = await http.put(
          Uri.parse('$_baseUrl/sales/orders/$_orderId'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(data)
        );
      } else {
        // ── CREATE new order ──
        resp = await http.post(
          Uri.parse('$_baseUrl/sales/orders'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(data)
        );
      }

      if (resp.statusCode >= 400) { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Save failed'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? 'Sales order updated successfully' : 'Sales order created successfully'),
          backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  // ═══════════════════════════════════════════════
  //  Line Item Builder
  // ═══════════════════════════════════════════════

  Widget _buildLineItem(int i, _SOLineItem it) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Row(children: [
            SizedBox(
              width: 55,
              child: TextField(
                controller: it.itemCodeCtrl,
                decoration: const InputDecoration(labelText: 'Item', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                onChanged: (v) => _onItemCodeChanged(i, v),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: it.productId.isEmpty ? null : it.productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Product', isDense: true),
                items: _products.map((p) => DropdownMenuItem(value: p['id']?.toString(), child: Text('${p['sku'] ?? ''}', style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (v) async {
                  it.productId = v ?? '';
                  setState(() {});
                  final prod = _products.firstWhere((p) => p['id']?.toString() == v, orElse: () => null);
                  double defaultPrice = 0;
                  it.uom = 'EA';
                  if (prod != null) {
                    it.productSku = prod['sku'] ?? '';
                    it.productName = prod['name'] ?? '';
                    it.uom = prod['unit_of_measure'] ?? 'EA';
                    defaultPrice = (prod['price'] as num?)?.toDouble() ?? 0;
                  }
                  // Auto-fetch customer-specific price from Material Price master
                  if (v != null && _customerId != null) {
                    try {
                      final mpResp = await http.get(
                        Uri.parse('$_baseUrl/sales/material-prices/lookup?customer_id=$_customerId&product_id=$v'),
                        headers: {'Authorization': 'Bearer $_token'},
                      );
                      if (mpResp.statusCode < 400) {
                        final mp = (jsonDecode(mpResp.body)['data'] as Map<String, dynamic>?) ?? {};
                        if (mp['price'] != null) {
                          defaultPrice = (mp['price'] as num).toDouble();
                        }
                      }
                    } catch (_) {}
                  }
                  it.priceCtrl.text = defaultPrice.toStringAsFixed(2);
                  it.unitPrice = defaultPrice;
                  _recalc(it);
                },
              ),
            ),
            if (_items.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                onPressed: () => _removeItem(i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: it.qtyCtrl, decoration: const InputDecoration(labelText: 'Qty', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), onChanged: (_) => _recalc(it))),
            const SizedBox(width: 6),
            SizedBox(width: 30, child: Text(it.uom, style: const TextStyle(fontSize: 10, color: Colors.grey))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: it.priceCtrl, decoration: const InputDecoration(labelText: 'Price', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), onChanged: (_) => _recalc(it))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: it.discCtrl, decoration: const InputDecoration(labelText: 'Disc %', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), onChanged: (_) => _recalc(it))),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: Text('\$${it.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
          ]),
          // ATP status warning
          if (_atpStatus.containsKey(i) && _atpStatus[i] != 'AVAILABLE')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(_atpStatus[i] == 'UNAVAILABLE' ? Icons.error_outline : Icons.warning_amber_outlined, size: 12, color: _atpStatus[i] == 'UNAVAILABLE' ? Colors.red : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  _atpStatus[i] == 'UNAVAILABLE'
                      ? '⚠ No stock available'
                      : '⚠ Only ${_atpAvailable[i]?.toStringAsFixed(0) ?? '0'} available',
                  style: TextStyle(fontSize: 9, color: _atpStatus[i] == 'UNAVAILABLE' ? Colors.red : Colors.orange),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  /// The save button widget (shared between tabs)
  Widget _buildSaveButton() {
    final canSave = _customerId != null && _items.isNotEmpty && !_items.any((it) => it.productId.isEmpty) && !_saving && !_loadingEdit;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canSave ? _save : null,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(isEdit ? Icons.save : Icons.add_circle_outline, size: 16),
          label: Text(isEdit ? 'Update Order' : 'Create Order & Run Checks', style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? 'Edit SO ${widget.order!['so_number'] ?? ''}'
            : widget.importQuotation != null
                ? 'Import from ${widget.importQuotation!['quotation_no']}'
                : 'New Sales Order'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(text: 'Main', icon: Icon(Icons.receipt, size: 16)),
          Tab(text: 'Shipping Information', icon: Icon(Icons.local_shipping, size: 16)),
          Tab(text: 'Notes', icon: Icon(Icons.note_alt_outlined, size: 16)),
        ]),
      ),
      body: _loadingEdit
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
        //── TAB 1: MAIN ──
        Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order Header', style: labelStyle), const Divider(),
            DropdownButtonFormField<String>(initialValue: _orderType, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Order Type', isDense: true, prefixIcon: Icon(Icons.category_outlined, size: 18)),
              items: _orderTypes.map((ot) => DropdownMenuItem(value: ot['order_type'] as String?, child: Text('${ot['order_type']} - ${ot['description']}', style: const TextStyle(fontSize: 11)))).toList(),
              onChanged: (v) => setState(() => _orderType = v ?? 'OR')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(initialValue: _customerId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer *', isDense: true),
              items: _customers.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text('${c['customer_code']} - ${c['name']}', style: const TextStyle(fontSize: 11)))).toList(),
              onChanged: (v) => setState(() => _customerId = v), validator: (v) => v == null ? 'Required' : null),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dateField('Order Date', _orderDate, (d) => setState(() => _orderDate = d))),
              const SizedBox(width: 6), Expanded(child: _dateField('Delivery Date', _deliveryDate, (d) => setState(() => _deliveryDate = d), optional: true)),
              const SizedBox(width: 6), Expanded(child: _dateField('Request Ship', _requestedShipDate, (d) => setState(() => _requestedShipDate = d), optional: true)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _custPOCtrl, decoration: const InputDecoration(labelText: 'Customer PO #', isDense: true), style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 6), Expanded(child: _dateField('PO Date', _poDate, (d) => setState(() => _poDate = d), optional: true)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(initialValue: _employeeId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Salesperson', isDense: true, prefixIcon: Icon(Icons.person_outline, size: 18)),
              items: [const DropdownMenuItem(value: null, child: Text('(None)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._employees.map((e) => DropdownMenuItem(value: e['employee_id']?.toString(), child: Text('${e['employee_code']} - ${e['full_name']}', style: const TextStyle(fontSize: 11))))],
              onChanged: (v) => setState(() => _employeeId = v as String?)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(initialValue: _currency, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Currency', isDense: true), items: ['USD','EUR','GBP','CNY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'USD'))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String?>(
                initialValue: _paymentTermsList.isEmpty ? 'Net 30' : (_paymentTermsList.any((pt) => pt['code'] == _paymentTerms) ? _paymentTerms : null),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Payment Terms', isDense: true),
                items: [
                  if (_paymentTermsList.isEmpty) const DropdownMenuItem(value: 'Net 30', child: Text('Net 30', style: TextStyle(fontSize: 11))),
                  ..._paymentTermsList.map((pt) => DropdownMenuItem(
                      value: pt['code']?.toString(),
                      child: Text('${pt['code']} - ${pt['name'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    )).toList(),
                ],
                onChanged: (v) => setState(() => _paymentTerms = v ?? 'Net 30'))),
            ]),
            const SizedBox(height: 8),
            // ── Incoterm dropdown (from Finance Settings) ──
            DropdownButtonFormField<String>(
              value: _incoterm.isEmpty ? null : _incoterm,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Incoterm', isDense: true, prefixIcon: Icon(Icons.map, size: 18)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(None)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._incoterms.map((t) => DropdownMenuItem(
                  value: t['code']?.toString(),
                  child: Text('${t['code']} — ${t['name']}', style: const TextStyle(fontSize: 11)),
                )),
              ],
              onChanged: (v) => setState(() => _incoterm = v ?? ''),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _deliveryBlockId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Delivery Block', isDense: true, prefixIcon: Icon(Icons.block, size: 16)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(None)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._deliveryBlocks.map((db) => DropdownMenuItem(
                  value: db['id']?.toString(),
                  child: Text('${db['block_code']} - ${db['description']}', style: const TextStyle(fontSize: 11)),
                )),
              ],
              onChanged: (v) => setState(() => _deliveryBlockId = v),
            ),
          ]))),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('Order Items', style: labelStyle), const Spacer(), TextButton.icon(icon: const Icon(Icons.add, size: 16), onPressed: _addItem, label: const Text('Add Item', style: TextStyle(fontSize: 11)))]),
            const Divider(),
            ..._items.asMap().entries.map((e) => _buildLineItem(e.key, e.value)),
            const Divider(),
            Row(children: [const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Total: \$${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              Row(children: [const Text('Discount %:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                SizedBox(width: 50, child: TextField(controller: _discountCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.right, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4)), onChanged: (_) => setState(() {})))]),
              // Pricing conditions breakdown
            if (_pricingConditions.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: _pricingConditions.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text('${c['label'] ?? ''}: \$${(c['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(fontSize: 10, color: ((c['amount'] as num?)?.toDouble() ?? 0) < 0 ? Colors.green : Colors.grey.shade600)),
              )).toList()),
            const SizedBox(height: 4),
            Text('Net: \$${_netAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 80, child: TextField(controller: _taxCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'Tax', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4)), onChanged: (_) => setState(() {}))),
                const SizedBox(width: 4),
                TextButton(onPressed: (_customerId == null || _calculatingTax) ? null : _calculateTax, child: _calculatingTax ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Calc Tax', style: TextStyle(fontSize: 9))),
              ]),
              Text('Grand Total: \$${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
            ])]),
          ]))),
          _buildSaveButton(),
        ])),
        //── TAB 2: SHIPPING INFORMATION ──
        ListView(padding: const EdgeInsets.all(12), children: [
          // 若有已保存数据,在顶部显示摘要
          if (isEdit && _shippingSummary().isNotEmpty)
            Card(
              color: Theme.of(context).cardColor,
              child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Shipping Summary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade700)),
                const Divider(),
                ..._shippingSummary().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                    Expanded(child: Text(e.value, style: const TextStyle(fontSize: 11))),
                  ]),
                )),
              ])),
            ),
          if (isEdit && _shippingSummary().isNotEmpty) const SizedBox(height: 8),
          // ── Ship To (from customer master) ──
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ship To', style: labelStyle), const Divider(),
            DropdownButtonFormField<String?>(
              value: _shipToCustomerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ship To Customer', isDense: true, prefixIcon: Icon(Icons.pin_drop, size: 18)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(Same as Sold-To)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._customers.map((c) => DropdownMenuItem(
                  value: c['id']?.toString(),
                  child: Text('${c['customer_code']} - ${c['name']}', style: const TextStyle(fontSize: 11)),
                )),
              ],
              onChanged: (v) => setState(() => _shipToCustomerId = v),
            ),
            if (_selectedShipToAddress.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Shipping Address', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                  const SizedBox(height: 4),
                  Text(_selectedShipToAddress, style: const TextStyle(fontSize: 11)),
                ]),
              ),
            ],
          ]))),
          if (isEdit && _shippingSummary().isNotEmpty) const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shipping Details', style: labelStyle), const Divider(),
            const SizedBox(height: 4),
            // ── Carrier dropdown (from config) ──
            DropdownButtonFormField<String?>(
              value: _carrier,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Carrier *', isDense: true, prefixIcon: Icon(Icons.local_shipping, size: 18)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(Select Carrier)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._uniqueCarriers.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() { _carrier = v; _serviceType = null; }),
            ),
            const SizedBox(height: 8),
            // ── Service Type dropdown (filtered by carrier) ──
            DropdownButtonFormField<String?>(
              value: _serviceType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Service Type *', isDense: true, prefixIcon: Icon(Icons.route, size: 18)),
              items: [
                const DropdownMenuItem(value: null, child: Text('(Select Service Type)', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ..._serviceTypesForCarrier.map((st) => DropdownMenuItem(
                  value: st,
                  child: Text(st, style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() => _serviceType = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _shipperAcctCtrl, decoration: const InputDecoration(labelText: 'Shipper Account #', isDense: true, hintText: 'Your carrier account'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 24, height: 24, child: Checkbox(value: _insuranceEnabled, onChanged: (v) => setState(() => _insuranceEnabled = v ?? false))),
                const SizedBox(width: 4),
                const Text('Insurance', style: TextStyle(fontSize: 11)),
              ]),
              const Spacer(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 24, height: 24, child: Checkbox(value: _signatureReq, onChanged: (v) => setState(() => _signatureReq = v ?? false))),
                const SizedBox(width: 4),
                const Text('Signature Required', style: TextStyle(fontSize: 11)),
              ]),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 24, height: 24, child: Checkbox(value: _saturdayDel, onChanged: (v) => setState(() => _saturdayDel = v ?? false))),
              const SizedBox(width: 4),
              const Text('Saturday Delivery', style: TextStyle(fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _transportationTo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Payer', isDense: true, prefixIcon: Icon(Icons.route, size: 18)),
              items: const [
                DropdownMenuItem(value: 'Shipper', child: Text('Shipper', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Third Party', child: Text('Third Party', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Receiver', child: Text('Receiver', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _transportationTo = v ?? 'Shipper'),
            ),
          ]))),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bill-To', style: labelStyle),
            if (_transportationTo == 'Third Party')
              Padding(padding: const EdgeInsets.only(top: 2), child: Text('Required when Payer is Third Party', style: TextStyle(fontSize: 9, color: Colors.red.shade400))),
            const Divider(),
            TextField(controller: _payerAcctCtrl, decoration: InputDecoration(
              labelText: _transportationTo == 'Third Party' ? 'Transport Payer Account *' : 'Transport Payer Account',
              isDense: true, hintText: 'Bill party account',
              labelStyle: TextStyle(fontSize: 12, color: _transportationTo == 'Third Party' ? Colors.red.shade700 : null),
            ), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _billAddrCtrl, decoration: InputDecoration(
              labelText: _transportationTo == 'Third Party' ? 'Bill-To Address *' : 'Bill-To Address',
              isDense: true,
              labelStyle: TextStyle(fontSize: 12, color: _transportationTo == 'Third Party' ? Colors.red.shade700 : null),
            ), maxLines: 3, style: const TextStyle(fontSize: 12)),
          ]))),
          const SizedBox(height: 8),
          _buildSaveButton(),
        ]),
        //── TAB 3: NOTES ──
        ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notes', style: labelStyle), const Divider(),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', isDense: true, hintText: 'Internal notes / remarks'),
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(fontSize: 12),
            ),
          ]))),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Attachments', style: labelStyle),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                onPressed: _pickFiles,
                label: Text(_attachedFiles.isEmpty ? 'Add Attachment' : 'Add More', style: const TextStyle(fontSize: 11)),
              ),
            ]),
            const Divider(),
            if (_attachedFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Column(children: [
                  Icon(Icons.upload_file, size: 32, color: Colors.grey.shade300),
                  const SizedBox(height: 4),
                  Text('Tap "Add Attachment" to attach files', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
              )
            else
              ..._attachedFiles.asMap().entries.map((e) => _buildAttachmentItem(e.key, e.value)),
          ]))),
          const SizedBox(height: 8),
          _buildSaveButton(),
        ]),
      ]),
    );
  }

  // ── File picker ──
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachedFiles.addAll(result.files));
      _msg('${result.files.length} file(s) selected');
    }
  }

  // ── Remove attachment ──
  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  // ── Attachment item widget ──
  Widget _buildAttachmentItem(int index, PlatformFile file) {
    final isImage = file.extension != null && ['jpg','jpeg','png','gif','bmp','webp'].contains(file.extension!.toLowerCase());
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: isImage && file.path != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(file.path!), width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,_,_) => Icon(Icons.insert_drive_file, size: 22, color: Colors.grey)),
            )
          : Icon(Icons.insert_drive_file, size: 22, color: Colors.grey.shade600),
      title: Text(file.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
      subtitle: file.size > 0
          ? Text(_formatFileSize(file.size), style: TextStyle(fontSize: 9, color: Colors.grey.shade500))
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16, color: Colors.red),
        onPressed: () => _removeFile(index),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ═══════════════════════════════════════════════
//  Line Item - owns its controllers, disposes on removal
// ═══════════════════════════════════════════════

class _SOLineItem {
  String productId, productSku, productName, description, uom;
  double quantity, unitPrice, discountPct, lineTotal;
  int lineNo, itemCode;

  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final discCtrl = TextEditingController();
  final itemCodeCtrl = TextEditingController();

  _SOLineItem({
    this.lineNo = 1,
    this.itemCode = 100,
    this.productId = '',
    this.productSku = '',
    this.productName = '',
    this.description = '',
    this.quantity = 1.0,
    this.uom = 'EA',
    this.unitPrice = 0.0,
    this.discountPct = 0.0,
    this.lineTotal = 0.0,
  }) {
    // Core fix: sync controller text with incoming data
    itemCodeCtrl.text = itemCode.toString();
    qtyCtrl.text = quantity.toStringAsFixed(0);
    priceCtrl.text = unitPrice.toStringAsFixed(2);
    discCtrl.text = discountPct.toStringAsFixed(0);
  }

  /// Dispose controllers to prevent memory leaks
  void dispose() {
    itemCodeCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discCtrl.dispose();
  }
}
