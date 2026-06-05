import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  bool _saving = false;
  late TabController _tabCtrl;

  String? _customerId, _employeeId;
  String _currency = 'USD', _paymentTerms = 'Net 30', _orderType = 'OR';

  final _custPOCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();
  final _shipMethodCtrl = TextEditingController();
  final _shipperAcctCtrl = TextEditingController();
  final _insuranceCtrl = TextEditingController();
  final _transportToCtrl = TextEditingController();
  final _payerAcctCtrl = TextEditingController();
  final _billAddrCtrl = TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime? _deliveryDate, _requestedShipDate, _poDate;
  bool _signatureReq = false, _saturdayDel = false, _calculatingTax = false;

  List<dynamic> _customers = [], _products = [], _employees = [];
  final List<_SOLineItem> _items = [];
  final Map<int, String> _atpStatus = {};       // line index → ATP status
  final Map<int, double> _atpAvailable = {};    // line index → available qty
  Timer? _atpTimer;
  List<dynamic> _pricingConditions = [];         // pricing breakdown from engine

  bool get isEdit => widget.order != null;
  String get _token => widget.authService.accessToken ?? '';

  /// 收集已保存的 shipping/bill-to 摘要（仅编辑模式显示）
  Map<String, String> _shippingSummary() {
    final m = <String, String>{};
    if (_carrierCtrl.text.isNotEmpty) m['Carrier'] = _carrierCtrl.text;
    if (_shipMethodCtrl.text.isNotEmpty) m['Method'] = _shipMethodCtrl.text;
    if (_shipperAcctCtrl.text.isNotEmpty) m['Shipper Acct'] = _shipperAcctCtrl.text;
    if ((double.tryParse(_insuranceCtrl.text) ?? 0) > 0) m['Insurance'] = '\$${_insuranceCtrl.text}';
    if (_signatureReq) m['Signature Required'] = 'Yes';
    if (_saturdayDel) m['Saturday Delivery'] = 'Yes';
    if (_transportToCtrl.text.isNotEmpty) m['Transport To'] = _transportToCtrl.text;
    if (_payerAcctCtrl.text.isNotEmpty) m['Payer Account'] = _payerAcctCtrl.text;
    if (_billAddrCtrl.text.isNotEmpty) m['Bill-To Address'] = _billAddrCtrl.text;
    return m;
  }

  static const _orderTypes = <String, String>{
    'OR': 'Standard Order', 'EC': 'E-Commerce', 'CS': 'Cash Sale',
    'RM': 'Return', 'CN': 'Consignment', 'ST': 'Stock Transfer', 'SP': 'Sample'
  };

  // ═══════════════════════════════════════════════
  //  Init & Dispose
  // ═══════════════════════════════════════════════

  @override void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final o = widget.order ?? widget.importQuotation;
    if (o != null) {
      _customerId = o['customer_id']?.toString();
      _employeeId = o['employee_id']?.toString();
      _currency = o['currency'] ?? 'USD';
      _paymentTerms = o['payment_terms'] ?? 'Net 30';
      _orderType = o['order_type'] ?? o['so_type'] ?? o['quotation_type'] ?? 'OR';
      _custPOCtrl.text = o['customer_po_no'] ?? '';
      _discountCtrl.text = (o['discount_pct'] as num?)?.toString() ?? '';
      _notesCtrl.text = o['notes']?.toString() ?? '';
      _carrierCtrl.text = o['carrier'] ?? '';
      _shipMethodCtrl.text = o['shipping_method'] ?? '';
      _shipperAcctCtrl.text = o['shipper_account'] ?? '';
      _insuranceCtrl.text = (o['insurance_amt'] as num?)?.toString() ?? '';
      _transportToCtrl.text = o['transportation_to'] ?? '';
      _payerAcctCtrl.text = o['transport_payer_account'] ?? '';
      _billAddrCtrl.text = o['bill_to_address'] ?? '';
      _signatureReq = o['signature_required'] == true;
      _saturdayDel = o['saturday_delivery'] == true;
      if (o['order_date'] != null) _orderDate = DateTime.tryParse(o['order_date'].toString()) ?? DateTime.now();
      if (o['delivery_date'] != null) _deliveryDate = DateTime.tryParse(o['delivery_date'].toString());
      if (o['requested_ship_date'] != null || o['requested_date'] != null) _requestedShipDate = DateTime.tryParse(o['requested_ship_date']?.toString() ?? o['requested_date']?.toString() ?? '');
      if (o['po_date'] != null) _poDate = DateTime.tryParse(o['po_date'].toString());
      // Import items with controller sync
      final srcItems = (o['items'] as List<dynamic>?) ?? (o['Items'] as List<dynamic>?) ?? [];
      for (final it in srcItems) {
        final item = _SOLineItem(
          productId: it['product_id']?.toString() ?? '', productSku: it['product_sku']?.toString() ?? '',
          productName: it['product_name']?.toString() ?? '', description: it['description']?.toString() ?? '',
          quantity: (it['quantity'] as num?)?.toDouble() ?? 1, uom: it['unit_of_measure']?.toString() ?? 'EA',
          unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0, discountPct: (it['discount_pct'] as num?)?.toDouble() ?? 0,
        );
        // Controllers are synced in the constructor
        _items.add(item);
      }
    }
    _loadLookups();
    if (_items.isEmpty) _addItem();
  }

  @override void dispose() {
    _tabCtrl.dispose();
    _custPOCtrl.dispose(); _discountCtrl.dispose(); _taxCtrl.dispose(); _notesCtrl.dispose();
    _carrierCtrl.dispose(); _shipMethodCtrl.dispose(); _shipperAcctCtrl.dispose();
    _insuranceCtrl.dispose(); _transportToCtrl.dispose(); _payerAcctCtrl.dispose(); _billAddrCtrl.dispose();
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
      ]);
      if (results[0].statusCode < 400) _customers = jsonDecode(results[0].body)['data'] ?? [];
      if (results[1].statusCode < 400) _products = jsonDecode(results[1].body)['data'] ?? [];
      if (results[2].statusCode < 400) _employees = jsonDecode(results[2].body)['data'] ?? [];
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _addItem() => setState(() => _items.add(_SOLineItem(lineNo: _items.length + 1)));

  void _removeItem(int i) {
    if (_items.length > 1) {
      setState(() {
        final removed = _items.removeAt(i);
        removed.dispose(); // 🐛 core fix: prevent memory leak
      });
    }
  }

  double get _totalAmount => _items.fold(0.0, (s, it) => s + it.lineTotal);
  double get _discountAmount => _totalAmount * (double.tryParse(_discountCtrl.text) ?? 0) / 100;
  double get _netAmount => _totalAmount - _discountAmount;
  double get _taxAmount => double.tryParse(_taxCtrl.text) ?? 0;
  double get _grandTotal => _netAmount + _taxAmount + (double.tryParse(_insuranceCtrl.text) ?? 0);

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
            // Sync back recalculated prices
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
      if (mounted) { setState(() => _taxCtrl.text = taxAmount.toStringAsFixed(2)); _msg('Tax: \$${taxAmount.toStringAsFixed(2)} at ${(taxRate*100).toStringAsFixed(1)}% — $source'); }
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
  //  Save
  // ═══════════════════════════════════════════════

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'customer_id': _customerId, 'order_type': _orderType, 'currency': _currency, 'payment_terms': _paymentTerms,
        'customer_po_no': _custPOCtrl.text.trim(),
        'discount_pct': double.tryParse(_discountCtrl.text) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'order_date': '${_orderDate.year}-${_orderDate.month.toString().padLeft(2,'0')}-${_orderDate.day.toString().padLeft(2,'0')}',
        'carrier': _carrierCtrl.text.trim(), 'shipping_method': _shipMethodCtrl.text.trim(), 'shipper_account': _shipperAcctCtrl.text.trim(),
        'signature_required': _signatureReq, 'saturday_delivery': _saturdayDel, 'insurance_amt': double.tryParse(_insuranceCtrl.text) ?? 0,
        'transportation_to': _transportToCtrl.text.trim(), 'transport_payer_account': _payerAcctCtrl.text.trim(), 'bill_to_address': _billAddrCtrl.text.trim(),
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
      if (widget.importQuotation != null) data['quotation_id'] = widget.importQuotation!['id']?.toString();

      final resp = await http.post(
        Uri.parse('$_baseUrl/sales/orders'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode(data)
      );
      if (resp.statusCode >= 400) { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Create failed'); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sales order created successfully'), backgroundColor: Colors.green));
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

  // ═══════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700);
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'SO ${widget.order!['so_number']}' : widget.importQuotation != null ? 'Import from ${widget.importQuotation!['quotation_no']}' : 'New Sales Order'),
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'Main', icon: Icon(Icons.receipt, size: 16)), Tab(text: 'Shipping & Bill-To', icon: Icon(Icons.local_shipping, size: 16))]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        //── TAB 1: MAIN ──
        Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order Header', style: labelStyle), const Divider(),
            DropdownButtonFormField<String>(initialValue: _orderType, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Order Type', isDense: true, prefixIcon: Icon(Icons.category_outlined, size: 18)),
              items: _orderTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} — ${e.value}', style: const TextStyle(fontSize: 11)))).toList(),
              onChanged: (v) => setState(() => _orderType = v ?? 'OR')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(initialValue: _customerId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer *', isDense: true),
              items: _customers.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text('${c['customer_code']} — ${c['name']}', style: const TextStyle(fontSize: 11)))).toList(),
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
                ..._employees.map((e) => DropdownMenuItem(value: e['employee_id']?.toString(), child: Text('${e['employee_code']} — ${e['full_name']}', style: const TextStyle(fontSize: 11))))],
              onChanged: (v) => setState(() => _employeeId = v as String?)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(initialValue: _currency, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Currency', isDense: true), items: ['USD','EUR','GBP','CNY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'USD'))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(initialValue: _paymentTerms, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Payment Terms', isDense: true),
                items: ['Net 30','Net 15','Net 60','COD'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _paymentTerms = v ?? 'Net 30'))),
            ]),
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
          const SizedBox(height: 8),
          TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', isDense: true), maxLines: 2, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: (_customerId == null || _items.isEmpty || _items.any((it) => it.productId.isEmpty)) ? null : _saving ? null : _save,
            child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Order & Run Checks', style: TextStyle(fontSize: 13)))),
        ])),
        //── TAB 2: SHIPPING & BILL-TO ──
        ListView(padding: const EdgeInsets.all(12), children: [
          // 若有已保存数据，在顶部显示摘要
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
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Shipping Details', style: labelStyle), const Divider(),
            TextField(controller: _carrierCtrl, decoration: const InputDecoration(labelText: 'Carrier', isDense: true, hintText: 'FedEx, UPS, etc.'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _shipMethodCtrl, decoration: const InputDecoration(labelText: 'Shipping Method', isDense: true, hintText: 'Ground, Air, Express'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _shipperAcctCtrl, decoration: const InputDecoration(labelText: 'Shipper Account #', isDense: true, hintText: 'Your carrier account'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(width: 120, child: TextField(controller: _insuranceCtrl, decoration: const InputDecoration(labelText: 'Insurance Amt', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12))),
              const Spacer(),
              CheckboxListTile(value: _signatureReq, onChanged: (v) => setState(() => _signatureReq = v ?? false), title: const Text('Signature Required', style: TextStyle(fontSize: 11)), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true),
            ]),
            CheckboxListTile(value: _saturdayDel, onChanged: (v) => setState(() => _saturdayDel = v ?? false), title: const Text('Saturday Delivery', style: TextStyle(fontSize: 11)), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true),
          ]))),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bill-To / Transportation', style: labelStyle), const Divider(),
            TextField(controller: _transportToCtrl, decoration: const InputDecoration(labelText: 'Transportation To', isDense: true, hintText: 'City, State / Destination'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8), TextField(controller: _payerAcctCtrl, decoration: const InputDecoration(labelText: 'Transport Payer Account', isDense: true, hintText: 'Bill party account'), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8), TextField(controller: _billAddrCtrl, decoration: const InputDecoration(labelText: 'Bill-To Address', isDense: true), maxLines: 3, style: const TextStyle(fontSize: 12)),
          ]))),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
//  Line Item — owns its controllers, disposes on removal
// ═══════════════════════════════════════════════

class _SOLineItem {
  String productId, productSku, productName, description, uom;
  double quantity, unitPrice, discountPct, lineTotal;
  int lineNo;

  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final discCtrl = TextEditingController();

  _SOLineItem({
    this.lineNo = 1,
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
    qtyCtrl.text = quantity.toStringAsFixed(0);
    priceCtrl.text = unitPrice.toStringAsFixed(2);
    discCtrl.text = discountPct.toStringAsFixed(0);
  }

  /// Dispose controllers to prevent memory leaks
  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discCtrl.dispose();
  }
}
