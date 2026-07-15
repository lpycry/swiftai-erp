import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class POFormScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  final PurchaseOrderModel? po;
  const POFormScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
    this.po,
  });

  @override
  State<POFormScreen> createState() => _POFormScreenState();
}

class _POFormScreenState extends State<POFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loadingData = true;

  // ── Header Fields ──
  List<VendorModel> _vendors = [];
  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _paymentTerms = [];
  List<Map<String, dynamic>> _incoterms = [];
  List<Map<String, dynamic>> _products = [];
  VendorModel? _selectedVendor;
  String? _selectedOrgId;
  String? _paymentTermCode;
  String? _incotermCode;
  String _currency = 'USD';
  DateTime _poDate = DateTime.now();
  final _deliveryAddrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _items = <_LineItem>[];
  final _attachedFiles = <PlatformFile>[];
  bool get _isEdit => widget.po != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.authService.accessToken}',
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _deliveryAddrCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      _vendors = await widget.purchaseService.listVendors();
      final orgResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/orgs'),
        headers: _headers,
      );
      if (orgResp.statusCode < 400) {
        _organizations =
            ((jsonDecode(orgResp.body)['data'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
        if (_organizations.length == 1) {
          _selectedOrgId = _organizations[0]['id']?.toString();
          _deliveryAddrCtrl.text =
              _organizations[0]['address']?.toString() ?? '';
        }
      }
      final ptResp = await http.get(
        Uri.parse(
          'http://localhost:8080/api/v1/finance-settings/payment-terms',
        ),
        headers: _headers,
      );
      if (ptResp.statusCode < 400) {
        _paymentTerms =
            ((jsonDecode(ptResp.body)['data'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
      }
      final incResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/incoterms'),
        headers: _headers,
      );
      if (incResp.statusCode < 400) {
        _incoterms =
            ((jsonDecode(incResp.body)['data'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
      }
      final prodResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/warehouse/products'),
        headers: _headers,
      );
      if (prodResp.statusCode < 400) {
        _products =
            ((jsonDecode(prodResp.body)['data'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
      }
      _hydrateEditData();
    } catch (_) {}
    if (_items.isEmpty) _items.add(_LineItem());
    if (mounted) setState(() => _loadingData = false);
  }

  void _hydrateEditData() {
    final po = widget.po;
    if (po == null) return;
    _selectedVendor = _vendors.cast<VendorModel?>().firstWhere(
      (v) => v?.id == po.vendorId,
      orElse: () => null,
    );
    _selectedOrgId = po.organizationId;
    _paymentTermCode = po.paymentTermCode.isEmpty ? null : po.paymentTermCode;
    _incotermCode = po.incotermCode.isEmpty ? null : po.incotermCode;
    _currency = po.currency.isEmpty ? 'USD' : po.currency;
    _poDate = _parseDate(po.poDate) ?? DateTime.now();
    _deliveryAddrCtrl.text = po.deliveryAddress;
    _notesCtrl.text = po.notes;
    _items
      ..clear()
      ..addAll(
        po.items.map(
          (item) => _LineItem(
            productId: item.itemId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            uom: item.unitOfMeasure,
            deliveryDate: _parseDate(item.expectedDeliveryDate),
            deliveryAddress: item.deliveryAddress,
          ),
        ),
      );
  }

  DateTime? _parseDate(String? value) {
    final text = value?.split('T').first ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  void _addItem() => setState(() => _items.add(_LineItem()));
  void _removeItem(int i) {
    if (_items.length > 1) setState(() => _items.removeAt(i));
  }

  double get _total =>
      _items.fold(0.0, (s, it) => s + it.quantity * it.unitPrice);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _poDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _poDate = picked);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) setState(() => _attachedFiles.addAll(result.files));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendor == null) {
      _error('Select a vendor');
      return;
    }
    if (_items.every((it) => it.productId == null)) {
      _error('Add at least one item');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'vendor_id': _selectedVendor!.id,
        'currency': _currency,
        'notes': _notesCtrl.text.trim(),
        'organization_id': _selectedOrgId,
        'po_date':
            '${_poDate.year}-${_poDate.month.toString().padLeft(2, '0')}-${_poDate.day.toString().padLeft(2, '0')}',
        'payment_term_code': _paymentTermCode,
        'delivery_address': _deliveryAddrCtrl.text.trim(),
        'incoterm_code': _incotermCode,
        'items': _items.where((it) => it.productId != null).map((it) {
          final item = <String, dynamic>{
            'item_id': it.productId,
            'quantity': it.quantity,
            'unit_price': it.unitPrice,
            'unit_of_measure': it.uom,
          };
          if (it.deliveryDate != null) {
            item['expected_delivery_date'] =
                '${it.deliveryDate!.year}-${it.deliveryDate!.month.toString().padLeft(2, '0')}-${it.deliveryDate!.day.toString().padLeft(2, '0')}';
          }
          if (it.deliveryAddress.isNotEmpty)
            item['delivery_address'] = it.deliveryAddress;
          return item;
        }).toList(),
      };

      final po = _isEdit
          ? await widget.purchaseService.updatePO(widget.po!.id, payload)
          : await widget.purchaseService.createPO(payload);

      if (!_isEdit) {
        for (final file in _attachedFiles) {
          try {
            await widget.purchaseService.uploadPOAttachment(
              po.id,
              file.path!,
              file.name,
            );
          } catch (_) {}
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'Purchase order updated!' : 'Purchase order created!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _error('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String msg) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Purchase Order' : 'New Purchase Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print blank form',
            onPressed: _printBlankPO,
          ),
          if (!_isEdit)
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              tooltip: 'Attach files',
              onPressed: _pickFile,
            ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Header ──
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Header',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedOrgId,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Code',
                                    hintText: 'Select company',
                                  ),
                                  isExpanded: true,
                                  items: _organizations
                                      .map(
                                        (o) => DropdownMenuItem(
                                          value: o['id']?.toString(),
                                          child: Text(
                                            '${o['org_code'] ?? ''} - ${o['org_name'] ?? ''}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedOrgId = v;
                                      final org = _organizations
                                          .cast<Map<String, dynamic>?>()
                                          .firstWhere(
                                            (o) => o?['id'] == v,
                                            orElse: () => null,
                                          );
                                      if (org != null &&
                                          _deliveryAddrCtrl.text.isEmpty) {
                                        _deliveryAddrCtrl.text =
                                            org['address']?.toString() ?? '';
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'PO Date',
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_poDate.year}-${_poDate.month.toString().padLeft(2, '0')}-${_poDate.day.toString().padLeft(2, '0')}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<VendorModel>(
                            value: _selectedVendor,
                            decoration: const InputDecoration(
                              labelText: 'Vendor *',
                            ),
                            items: _vendors
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('${v.vendorCode} - ${v.name}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedVendor = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _paymentTermCode,
                                  decoration: const InputDecoration(
                                    labelText: 'Pay Terms',
                                    isDense: true,
                                  ),
                                  items: _paymentTerms
                                      .map(
                                        (pt) => DropdownMenuItem(
                                          value: pt['code']?.toString(),
                                          child: Text(
                                            '${pt['code']} - ${pt['name']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _paymentTermCode = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: DropdownButtonFormField<String>(
                                  value: _incotermCode,
                                  decoration: const InputDecoration(
                                    labelText: 'Incoterm',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 12,
                                    ),
                                  ),
                                  isExpanded: true,
                                  items: _incoterms
                                      .map(
                                        (i) => DropdownMenuItem(
                                          value: i['code']?.toString(),
                                          child: Text(
                                            '${i['code']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _incotermCode = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: DropdownButtonFormField<String>(
                                  value: _currency,
                                  decoration: const InputDecoration(
                                    labelText: 'Curr',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 12,
                                    ),
                                  ),
                                  isExpanded: true,
                                  items:
                                      [
                                            'USD',
                                            'EUR',
                                            'GBP',
                                            'CNY',
                                            'JPY',
                                            'HKD',
                                            'SGD',
                                          ]
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) =>
                                      setState(() => _currency = v ?? 'USD'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _deliveryAddrCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Address',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Attachments preview ──
                  if (_attachedFiles.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.attach_file,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Attachments (${_attachedFiles.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _attachedFiles.clear()),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            ..._attachedFiles.map(
                              (f) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.description,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        f.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      _fmtSize(f.size),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_attachedFiles.isNotEmpty) const SizedBox(height: 16),

                  // ── Line Items ──
                  Row(
                    children: [
                      const Text(
                        'Line Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                        onPressed: _addItem,
                      ),
                    ],
                  ),
                  ..._items.asMap().entries.map((e) => _buildLineItem(e.key)),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$_currency ${PurchaseService.fmtAmount(_total)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEdit
                                ? 'Update Purchase Order'
                                : 'Create Purchase Order',
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLineItem(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.productId,
                    decoration: InputDecoration(
                      labelText: 'Item ${index + 1} *',
                      isDense: true,
                    ),
                    items: _products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p['id']?.toString(),
                            child: Text(
                              '${p['sku'] ?? ''} - ${p['name'] ?? ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => item.productId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        setState(() => item.quantity = double.tryParse(v) ?? 0),
                    validator: (v) =>
                        (v == null || (double.tryParse(v) ?? 0) <= 0)
                        ? 'Invalid'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(
                      () => item.unitPrice = double.tryParse(v) ?? 0,
                    ),
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? 'Invalid'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.uom,
                    decoration: const InputDecoration(
                      labelText: 'UOM',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => item.uom = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      item.deliveryDate ??
                      _poDate.add(const Duration(days: 14)),
                  firstDate: _poDate,
                  lastDate: _poDate.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => item.deliveryDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expected Delivery',
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 16),
                ),
                child: Text(
                  item.deliveryDate != null
                      ? '${item.deliveryDate!.year}-${item.deliveryDate!.month.toString().padLeft(2, '0')}-${item.deliveryDate!.day.toString().padLeft(2, '0')}'
                      : 'Not set (click to select)',
                  style: TextStyle(
                    fontSize: 13,
                    color: item.deliveryDate != null
                        ? Colors.black
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.deliveryAddress,
              decoration: InputDecoration(
                labelText: 'Delivery Address (override)',
                isDense: true,
                hintText: 'Leave blank to use header address',
              ),
              onChanged: (v) => item.deliveryAddress = v,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Line: ${PurchaseService.fmtAmount(item.quantity * item.unitPrice)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _printBlankPO() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Company: ${_selectedOrgId != null ? (_organizations.firstWhere((o) => o['id'] == _selectedOrgId)['org_name'] ?? '') : '___________'}',
                    ),
                    pw.Text(
                      'Date: ${_poDate.year}-${_poDate.month.toString().padLeft(2, '0')}-${_poDate.day.toString().padLeft(2, '0')}',
                    ),
                    pw.Text('Status: DRAFT'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Vendor: ${_selectedVendor != null ? '${_selectedVendor!.vendorCode} - ${_selectedVendor!.name}' : '___________'}',
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Payment Terms: ${_paymentTermCode ?? '___________'}'),
            pw.Text(
              'Delivery: ${_deliveryAddrCtrl.text.isNotEmpty ? _deliveryAddrCtrl.text : '___________'}',
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9),
              headers: ['#', 'Item', 'Qty', 'UOM', 'Price', 'Total'],
              data: _items
                  .asMap()
                  .entries
                  .map(
                    (e) => [
                      '${e.key + 1}',
                      e.value.productId ?? '___________',
                      '${e.value.quantity}',
                      e.value.uom,
                      '\$${PurchaseService.fmtAmount(e.value.unitPrice)}',
                      '\$${PurchaseService.fmtAmount(e.value.quantity * e.value.unitPrice)}',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: \$${PurchaseService.fmtAmount(_total)}',
                style: pw.TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Purchase_Order_Blank.pdf',
    );
  }
}

class _LineItem {
  String? productId;
  double quantity;
  double unitPrice;
  String uom;
  DateTime? deliveryDate;
  String deliveryAddress;
  _LineItem({
    this.productId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.uom = 'EA',
    this.deliveryDate,
    this.deliveryAddress = '',
  });
}
