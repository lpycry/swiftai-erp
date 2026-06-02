import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class InvoiceFormScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  final Map<String, dynamic>? vendors;
  final Map<String, dynamic>? prefillData;
  const InvoiceFormScreen({super.key, required this.authService, required this.purchaseService, this.vendors, this.prefillData});
  @override State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _invNumCtrl = TextEditingController();
  final _totalAmtCtrl = TextEditingController();
  final _taxAmtCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  bool _loading = false;
  bool _submitting = false;
  String? _token;

  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _pos = [];
  String? _selectedVendorId;
  String? _selectedPoId;
  List<Map<String, dynamic>> _poItems = [];

  // Line items for 3-way match
  final List<_InvLineItem> _lineItems = [];
  int _nextLineKey = 0;

  @override
  void initState() {
    super.initState();
    _token = widget.authService.accessToken;
    _load().then((_) => _applyPrefill());
  }

  void _applyPrefill() {
    final pre = widget.prefillData;
    if (pre == null) return;
    
    // Auto-select vendor
    final vId = pre['vendor_id']?.toString();
    if (vId != null) {
      setState(() => _selectedVendorId = vId);
    }
    
    // Auto-select PO and trigger item loading
    final poId = pre['po_id']?.toString();
    if (poId != null) {
      _onPoSelected(poId);
    }
    
    // Pre-fill total and invoice number
    final amt = (pre['total_amount'] as num?)?.toDouble();
    if (amt != null && amt > 0) {
      _totalAmtCtrl.text = amt.toStringAsFixed(2);
    }
    
    // Generate invoice number hint
    final poNum = pre['po_number']?.toString() ?? '';
    if (poNum.isNotEmpty) {
      _invNumCtrl.text = 'INV-${poNum.substring(3)}';
    }
  }

  String get _tokenVal => _token ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vR = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/vendors'),
          headers: {'Authorization': 'Bearer $_tokenVal'});
      if (vR.statusCode < 400) {
        _vendors = ((jsonDecode(vR.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      }

      final poR = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/orders?status=CONFIRMED'),
          headers: {'Authorization': 'Bearer $_tokenVal'});
      if (poR.statusCode < 400) {
        _pos = ((jsonDecode(poR.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      }
      // Also load RECEIVED and PARTIALLY_INVOICED POs
      for (final s in ['RECEIVED', 'PARTIALLY_INVOICED']) {
        final r = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/orders?status=$s'),
            headers: {'Authorization': 'Bearer $_tokenVal'});
        if (r.statusCode < 400) {
          _pos.addAll(((jsonDecode(r.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>());
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onPoSelected(String? poId) async {
    _selectedPoId = poId;
    if (poId == null) { _poItems = []; _lineItems.clear(); if (mounted) setState(() {}); return; }
    try {
      final r = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/orders/$poId'),
          headers: {'Authorization': 'Bearer $_tokenVal'});
      if (r.statusCode < 400) {
        final data = jsonDecode(r.body)['data'] as Map<String, dynamic>? ?? {};
        final items = (data['items'] as List<dynamic>?) ?? [];
        _poItems = items.cast<Map<String, dynamic>>();
        // Auto-create line items
        _lineItems.clear();
        for (final itm in _poItems) {
          final received = (itm['received_quantity'] as num?)?.toDouble() ?? 0;
          final invoiced = (itm['invoiced_quantity'] as num?)?.toDouble() ?? 0;
          final openQty = received - invoiced;
          if (openQty > 0) {
            _lineItems.add(_InvLineItem(
              key: _nextLineKey++,
              itemId: itm['item_id']?.toString() ?? '',
              sku: itm['item_sku'] ?? '',
              name: itm['item_name'] ?? '',
              poItemId: itm['id']?.toString(),
              poQty: (itm['quantity'] as num?)?.toDouble() ?? 0,
              receivedQty: received,
              invoicedQty: invoiced,
              openQty: openQty,
              poPrice: (itm['unit_price'] as num?)?.toDouble() ?? 0,
              invQty: openQty,
              invPrice: (itm['unit_price'] as num?)?.toDouble() ?? 0,
            ));
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_invNumCtrl.text.trim().isEmpty) { _msg('Invoice number required', isError: true); return; }
    if (_selectedVendorId == null) { _msg('Select vendor', isError: true); return; }
    final totalAmt = double.tryParse(_totalAmtCtrl.text) ?? 0;
    if (totalAmt <= 0) { _msg('Enter valid amount', isError: true); return; }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'invoice_number': _invNumCtrl.text.trim(),
        'vendor_id': _selectedVendorId,
        'total_amount': totalAmt,
        'tax_amount': double.tryParse(_taxAmtCtrl.text) ?? 0,
        'currency': 'USD',
        'notes': _notesCtrl.text.trim(),
        'invoice_date': '${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}',
      };
      if (_selectedPoId != null) {
        body['po_id'] = _selectedPoId;
        body['items'] = _lineItems.where((it) => it.invQty > 0).map((it) => {
          'item_id': it.itemId,
          'po_item_id': it.poItemId,
          'quantity': it.invQty,
          'unit_price': it.invPrice,
        }).toList();
      }

      await widget.purchaseService.createInvoice(body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created! 3-way match completed'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Vendor
                DropdownButtonFormField<String>(
                  initialValue: _selectedVendorId,
                  decoration: const InputDecoration(labelText: 'Vendor *', isDense: true,
                    prefixIcon: Icon(Icons.business, size: 18)),
                  isExpanded: true,
                  items: _vendors.map((v) => DropdownMenuItem(value: v['id']?.toString(),
                      child: Text('${v['vendor_code'] ?? ''} - ${v['name'] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _selectedVendorId = v),
                ),
                const SizedBox(height: 12),

                // PO
                DropdownButtonFormField<String>(
                  initialValue: _selectedPoId,
                  decoration: const InputDecoration(labelText: 'Purchase Order (for 3-way match)', isDense: true,
                    prefixIcon: Icon(Icons.description, size: 18)),
                  isExpanded: true,
                  items: _pos.map((po) => DropdownMenuItem(value: po['id']?.toString(),
                      child: Text('${po['po_number'] ?? ''}  ${po['vendor_name'] ?? ''}  \$${(po['total_amount'] as num?)?.toStringAsFixed(2) ?? ''}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace')))).toList(),
                  onChanged: (v) => _onPoSelected(v),
                ),
                const SizedBox(height: 12),

                // Invoice number + date
                Row(children: [
                  Expanded(child: TextField(controller: _invNumCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice Number *', isDense: true,
                      prefixIcon: Icon(Icons.numbers, size: 18)),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _invoiceDate,
                          firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) setState(() => _invoiceDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: 'Date', isDense: true,
                          prefixIcon: Icon(Icons.date_range, size: 16, color: Colors.grey.shade600)),
                        child: Text('${_invoiceDate.year}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.day.toString().padLeft(2, '0')}')),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Amounts
                Row(children: [
                  Expanded(child: TextField(controller: _totalAmtCtrl,
                    decoration: const InputDecoration(labelText: 'Total Amount *', isDense: true,
                      prefixIcon: Icon(Icons.attach_money, size: 18)),
                    keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _taxAmtCtrl,
                    decoration: const InputDecoration(labelText: 'Tax Amount', isDense: true,
                      prefixIcon: Icon(Icons.receipt, size: 18)),
                    keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 12),

                TextField(controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', isDense: true),
                  maxLines: 2, style: const TextStyle(fontSize: 13)),

                // ── 3-way match items ──
                if (_lineItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.compare_arrows, size: 16, color: Colors.indigo.shade600),
                        const SizedBox(width: 6),
                        Text('3-Way Match Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.indigo.shade800)),
                      ]),
                      const SizedBox(height: 8),
                      ..._lineItems.map((item) => _buildMatchRow(item)),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  onPressed: _submitting ? null : _submit,
                  label: Text(_submitting ? 'Processing...' : 'Create Invoice (3-way match)'),
                )),
              ]),
            ),
    );
  }

  Widget _buildMatchRow(_InvLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // SKU + Name
        Row(children: [
          Text(item.sku, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Expanded(child: Text(item.name, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        // PO / GR / Open
        Row(children: [
          _tag('PO: ${item.poQty.toStringAsFixed(0)} @ \$${item.poPrice.toStringAsFixed(2)}', Colors.blue),
          const SizedBox(width: 4),
          _tag('GR: ${item.receivedQty.toStringAsFixed(0)}', Colors.teal),
          const SizedBox(width: 4),
          _tag('Open: ${item.openQty.toStringAsFixed(0)}', Colors.orange),
        ]),
        const SizedBox(height: 6),
        // Invoice qty + price
        Row(children: [
          SizedBox(width: 80, child: TextField(
            decoration: const InputDecoration(labelText: 'Inv Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
            style: const TextStyle(fontSize: 12), keyboardType: TextInputType.number,
            controller: TextEditingController(text: item.invQty.toStringAsFixed(0)),
            onChanged: (v) => item.invQty = double.tryParse(v) ?? 0,
          )),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: TextField(
            decoration: const InputDecoration(labelText: 'Inv Price', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
            style: const TextStyle(fontSize: 12), keyboardType: TextInputType.number,
            controller: TextEditingController(text: item.invPrice.toStringAsFixed(2)),
            onChanged: (v) => item.invPrice = double.tryParse(v) ?? 0,
          )),
          const SizedBox(width: 8),
          // Price diff visualization
          if (item.invPrice != item.poPrice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: item.invPrice > item.poPrice ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(3)),
              child: Text('${item.invPrice > item.poPrice ? '+' : ''}\$${((item.invPrice - item.poPrice) * item.invQty).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: item.invPrice > item.poPrice ? Colors.red.shade700 : Colors.green.shade700)),
            ),
        ]),
      ]),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: color, fontFamily: 'monospace')),
    );
  }
}

class _InvLineItem {
  final int key;
  final String itemId;
  final String sku;
  final String name;
  final String? poItemId;
  final double poQty;
  final double receivedQty;
  final double invoicedQty;
  double openQty;
  double poPrice;
  double invQty;
  double invPrice;

  _InvLineItem({
    required this.key, required this.itemId, required this.sku, required this.name,
    this.poItemId, required this.poQty, required this.receivedQty, required this.invoicedQty,
    required this.openQty, required this.poPrice, required this.invQty, required this.invPrice,
  });
}
