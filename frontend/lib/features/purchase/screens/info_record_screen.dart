import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class PurchasingInfoRecordScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const PurchasingInfoRecordScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });

  @override
  State<PurchasingInfoRecordScreen> createState() =>
      _PurchasingInfoRecordScreenState();
}

class _PurchasingInfoRecordScreenState
    extends State<PurchasingInfoRecordScreen> {
  static const _baseUrl = 'http://localhost:8080/api/v1';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];
  List<VendorModel> _vendors = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _incoterms = [];
  List<Map<String, dynamic>> _paymentTerms = [];

  String get _token => widget.authService.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vendors = await widget.purchaseService.listVendors();
      final productsResp = await http.get(
        Uri.parse('$_baseUrl/warehouse/products'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final sitesResp = await http.get(
        Uri.parse('$_baseUrl/sites'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final incotermsResp = await http.get(
        Uri.parse('$_baseUrl/finance-settings/incoterms'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final paymentTermsResp = await http.get(
        Uri.parse('$_baseUrl/finance-settings/payment-terms'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final records = await widget.purchaseService.listInfoRecords(
        query: _searchCtrl.text.trim(),
      );
      final products = productsResp.statusCode < 400
          ? (jsonDecode(productsResp.body)['data'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : <Map<String, dynamic>>[];
      final rawSites = sitesResp.statusCode < 400
          ? jsonDecode(sitesResp.body)['data']
          : [];
      final sites =
          ((rawSites is Map ? rawSites['items'] : rawSites) as List<dynamic>? ??
                  [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((s) => s['site_type']?.toString().toLowerCase() == 'plant')
              .toList();
      final incoterms = incotermsResp.statusCode < 400
          ? (jsonDecode(incotermsResp.body)['data'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : <Map<String, dynamic>>[];
      final paymentTerms = paymentTermsResp.statusCode < 400
          ? (jsonDecode(paymentTermsResp.body)['data'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _products = products;
        _plants = sites;
        _incoterms = incoterms;
        _paymentTerms = paymentTerms;
        _records = records;
      });
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDialog([Map<String, dynamic>? record]) async {
    final isEdit = record != null;
    String? vendorId = record?['vendor_id']?.toString();
    String? productId = record?['product_id']?.toString();
    String? siteId = record?['site_id']?.toString();
    final uomCtrl = TextEditingController(
      text: record?['purchase_uom']?.toString() ?? 'EA',
    );
    final currencyCtrl = TextEditingController(
      text: record?['currency']?.toString() ?? 'USD',
    );
    final priceCtrl = TextEditingController(
      text: _numText(record?['price'], fallback: '0.00'),
    );
    final moqCtrl = TextEditingController(
      text: _numText(record?['min_order_qty']),
    );
    final roundingCtrl = TextEditingController(
      text: _numText(record?['rounding_qty']),
    );
    final leadTimeCtrl = TextEditingController(
      text: record?['lead_time_days']?.toString() ?? '0',
    );
    String? incoterm = _emptyToNull(record?['incoterm']?.toString());
    String? paymentTerms = _emptyToNull(record?['payment_terms']?.toString());
    DateTime? validFrom = _parseDate(record?['valid_from']);
    DateTime? validTo = _parseDate(record?['valid_to']);
    final notesCtrl = TextEditingController(
      text: record?['notes']?.toString() ?? '',
    );
    bool preferred = record?['is_preferred'] == true;
    bool blocked = record?['is_blocked'] == true;
    bool active = record?['is_active'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            isEdit
                ? 'Edit Purchasing Info Record'
                : 'New Purchasing Info Record',
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: vendorId,
                          decoration: const InputDecoration(
                            labelText: 'Vendor *',
                          ),
                          items: _vendors
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Text('${v.vendorCode} - ${v.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: isEdit
                              ? null
                              : (v) => setD(() => vendorId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: productId,
                          decoration: const InputDecoration(
                            labelText: 'Material *',
                          ),
                          items: _products
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p['id']?.toString(),
                                  child: Text(
                                    '${p['sku'] ?? ''} - ${p['name'] ?? ''}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: isEdit
                              ? null
                              : (v) => setD(() => productId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: siteId,
                          decoration: const InputDecoration(labelText: 'Plant'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('(All plants)'),
                            ),
                            ..._plants.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s['id']?.toString(),
                                child: Text(
                                  '${s['site_code'] ?? ''} - ${s['site_name'] ?? ''}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setD(() => siteId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(uomCtrl, 'Purchase UOM')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(currencyCtrl, 'Currency')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(priceCtrl, 'Price', number: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(moqCtrl, 'MOQ', number: true)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          roundingCtrl,
                          'Rounding Qty',
                          number: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          leadTimeCtrl,
                          'Lead Time Days',
                          number: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _hasCode(_incoterms, incoterm)
                              ? incoterm
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Incoterm',
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('(None)'),
                            ),
                            ..._incoterms.map(
                              (i) => DropdownMenuItem<String?>(
                                value: _code(i),
                                child: Text(_optionLabel(i)),
                              ),
                            ),
                          ],
                          onChanged: (v) => setD(() => incoterm = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _hasCode(_paymentTerms, paymentTerms)
                              ? paymentTerms
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Payment Terms',
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('(None)'),
                            ),
                            ..._paymentTerms.map(
                              (pt) => DropdownMenuItem<String?>(
                                value: _code(pt),
                                child: Text(_optionLabel(pt)),
                              ),
                            ),
                          ],
                          onChanged: (v) => setD(() => paymentTerms = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _datePickerField(
                          ctx,
                          label: 'Valid From',
                          value: validFrom,
                          onChanged: (v) => setD(() => validFrom = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _datePickerField(
                          ctx,
                          label: 'Valid To',
                          value: validTo,
                          onChanged: (v) => setD(() => validTo = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: preferred,
                        onChanged: (v) => setD(() => preferred = v ?? false),
                      ),
                      const Text('Preferred'),
                      const SizedBox(width: 18),
                      Checkbox(
                        value: blocked,
                        onChanged: (v) => setD(() => blocked = v ?? false),
                      ),
                      const Text('Blocked'),
                      const SizedBox(width: 18),
                      Checkbox(
                        value: active,
                        onChanged: (v) => setD(() => active = v ?? true),
                      ),
                      const Text('Active'),
                    ],
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (vendorId == null || productId == null) {
                  _snack('Vendor and Material are required', isError: true);
                  return;
                }
                final data = {
                  'vendor_id': vendorId,
                  'product_id': productId,
                  if (siteId != null && siteId!.isNotEmpty) 'site_id': siteId,
                  'purchase_uom': uomCtrl.text.trim(),
                  'currency': currencyCtrl.text.trim(),
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'min_order_qty': double.tryParse(moqCtrl.text) ?? 0,
                  'rounding_qty': double.tryParse(roundingCtrl.text) ?? 0,
                  'lead_time_days': int.tryParse(leadTimeCtrl.text) ?? 0,
                  'incoterm': incoterm ?? '',
                  'payment_terms': paymentTerms ?? '',
                  if (validFrom != null) 'valid_from': _formatDate(validFrom!),
                  if (validTo != null) 'valid_to': _formatDate(validTo!),
                  'is_preferred': preferred,
                  'is_blocked': blocked,
                  'is_active': active,
                  'notes': notesCtrl.text.trim(),
                };
                try {
                  if (isEdit) {
                    await widget.purchaseService.updateInfoRecord(
                      record['id'].toString(),
                      data,
                    );
                  } else {
                    await widget.purchaseService.createInfoRecord(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  _snack('$e', isError: true);
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
    for (final c in [
      uomCtrl,
      currencyCtrl,
      priceCtrl,
      moqCtrl,
      roundingCtrl,
      leadTimeCtrl,
      notesCtrl,
    ]) {
      c.dispose();
    }
    if (saved == true) await _load();
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, isDense: true),
      keyboardType: number ? TextInputType.number : TextInputType.text,
    );
  }

  Widget _datePickerField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 10),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null ? 'Select date' : _formatDate(value),
          style: TextStyle(
            color: value == null ? Colors.grey.shade600 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _viewDialog(Map<String, dynamic> record) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchasing Info Record'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _viewField(
                        'Vendor',
                        '${record['vendor_code'] ?? ''} - ${record['vendor_name'] ?? ''}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Material',
                        '${record['product_sku'] ?? ''} - ${record['product_name'] ?? ''}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _viewField(
                        'Plant',
                        record['site_code']?.toString().isNotEmpty == true
                            ? '${record['site_code']} - ${record['site_name'] ?? ''}'
                            : 'All plants',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Purchase UOM',
                        record['purchase_uom']?.toString() ?? '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Currency',
                        record['currency']?.toString() ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _viewField('Price', _numText(record['price'])),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'MOQ',
                        _numText(record['min_order_qty']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Rounding Qty',
                        _numText(record['rounding_qty']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Lead Time Days',
                        record['lead_time_days']?.toString() ?? '0',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _viewField(
                        'Incoterm',
                        record['incoterm']?.toString() ?? '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Payment Terms',
                        record['payment_terms']?.toString() ?? '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Valid From',
                        _dateText(record['valid_from']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _viewField(
                        'Valid To',
                        _dateText(record['valid_to']),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('Preferred', record['is_preferred'] == true),
                    _statusChip('Blocked', record['is_blocked'] == true),
                    _statusChip('Active', record['is_active'] != false),
                  ],
                ),
                const SizedBox(height: 12),
                _viewField('Notes', record['notes']?.toString() ?? ''),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _saveDialog(record);
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _viewField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(value.isEmpty ? '-' : value),
    );
  }

  Widget _statusChip(String label, bool active) {
    return Chip(
      label: Text(label),
      avatar: Icon(
        active ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 16,
        color: active ? Colors.green : Colors.grey,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Info Record'),
        content: Text(
          'Delete ${record['vendor_code'] ?? ''} / ${record['product_sku'] ?? ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.purchaseService.deleteInfoRecord(record['id'].toString());
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _numText(dynamic value, {String fallback = '0'}) {
    final n = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (n == null) return fallback;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  String _dateText(dynamic value) => Fmt.dateStr(value?.toString());

  String _isoDate(dynamic value) => value?.toString().split('T').first ?? '';

  String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  DateTime? _parseDate(dynamic value) {
    final text = _isoDate(value);
    return text.isEmpty ? null : DateTime.tryParse(text);
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _code(Map<String, dynamic> option) => option['code']?.toString() ?? '';

  bool _hasCode(List<Map<String, dynamic>> options, String? code) {
    if (code == null || code.isEmpty) return false;
    return options.any((option) => _code(option) == code);
  }

  String _optionLabel(Map<String, dynamic> option) {
    final code = _code(option);
    final name = option['name']?.toString() ?? '';
    if (name.isEmpty) return code;
    return '$code - $name';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchasing Info Records'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          FilledButton.icon(
            onPressed: () => _saveDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search vendor or material',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _load,
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('No purchasing info records'))
                : ListView.separated(
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      return ListTile(
                        leading: Icon(
                          r['is_blocked'] == true
                              ? Icons.block
                              : Icons.handshake_outlined,
                          color: r['is_blocked'] == true
                              ? Colors.red
                              : Colors.indigo,
                        ),
                        title: Text(
                          '${r['product_sku'] ?? ''} - ${r['product_name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${r['vendor_code'] ?? ''} - ${r['vendor_name'] ?? ''}'
                          '  Plant ${r['site_code']?.toString().isEmpty == false ? r['site_code'] : 'All'}'
                          '  ${r['currency'] ?? ''} ${_numText(r['price'])}/${r['purchase_uom'] ?? ''}'
                          '  LT ${r['lead_time_days'] ?? 0}d'
                          '  MOQ ${_numText(r['min_order_qty'])}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (r['is_preferred'] == true)
                              const Chip(
                                label: Text('Preferred'),
                                visualDensity: VisualDensity.compact,
                              ),
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () => _viewDialog(r),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _saveDialog(r),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
