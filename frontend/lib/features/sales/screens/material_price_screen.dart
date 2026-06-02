import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class MaterialPriceListScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  const MaterialPriceListScreen({super.key, required this.authService, required this.salesService});

  @override
  State<MaterialPriceListScreen> createState() => _MaterialPriceListScreenState();
}

class _MaterialPriceListScreenState extends State<MaterialPriceListScreen> {
  List<dynamic> _prices = [];
  List<dynamic> _products = [];
  List<dynamic> _customers = [];
  bool _loading = true;
  bool _loadingProducts = true;
  bool _loadingCustomers = true;
  bool _activeOnly = false;

  @override void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_activeOnly) params['active_only'] = 'true';
      final uri = Uri.parse('http://localhost:8080/api/v1/sales/material-prices').replace(queryParameters: params);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        _prices = ((jsonDecode(resp.body)['data'] as List?) ?? []);
      }
      await _loadProducts();
      await _loadCustomers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    try {
      final prodResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/warehouse/products'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (prodResp.statusCode < 400) { _products = ((jsonDecode(prodResp.body)['data'] as List?) ?? []); }
    } catch (_) {}
    if (mounted) { _loadingProducts = false; setState(() {}); }
  }

  Future<void> _loadCustomers() async {
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/sales/customers'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) { _customers = ((jsonDecode(resp.body)['data'] as List?) ?? []); }
    } catch (_) {}
    if (mounted) { _loadingCustomers = false; setState(() {}); }
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MaterialPriceDialog(
        existing: existing, products: _products, customers: _customers,
        token: _token, authService: widget.authService,
      ),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await widget.salesService.createMaterialPrice(result);
      } else {
        await widget.salesService.updateMaterialPrice(existing['id'].toString(), result);
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Price'), content: Text('Delete $label?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red))],
    ));
    if (ok != true) return;
    try {
      await widget.salesService.deleteMaterialPrice(id);
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  String _fmtPrice(dynamic p) {
    final amount = (p['price'] as num?)?.toDouble() ?? 0;
    final currency = p['currency']?.toString() ?? 'USD';
    final unit = (p['price_unit'] as int?) ?? 1;
    final symbol = currency == 'USD' ? '\$' : currency;
    if (unit > 1) return '$symbol${amount.toStringAsFixed(2)} / $unit';
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'STANDARD': return Colors.blue;
      case 'PROMOTIONAL': return Colors.orange;
      case 'VOLUME': return Colors.green;
      case 'CONTRACT': return Colors.purple;
      case 'CUSTOMER_SPECIFIC': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Prices'),
        actions: [
          FilterChip(label: const Text('Active', style: TextStyle(fontSize: 10)), selected: _activeOnly,
            onSelected: (v) { setState(() => _activeOnly = v); _load(); }, visualDensity: VisualDensity.compact),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'New Price',
            onPressed: () => _upsert(null)),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _prices.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_money_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No material prices', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text('Add a sales price for a product', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _prices.length,
                itemBuilder: (_, i) => _buildRow(_prices[i]),
              ),
            ),
    );
  }

  Widget _buildRow(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final prodName = p['product_name']?.toString() ?? '';
    final prodSku = p['product_sku']?.toString() ?? '';
    final type = p['price_type']?.toString() ?? 'STANDARD';
    final validFrom = p['valid_from']?.toString() ?? '';
    final validTo = p['valid_to']?.toString() ?? '';
    final active = p['is_active'] == true;
    final custName = p['customer_name']?.toString() ?? '';
    final custCode = p['customer_code']?.toString() ?? '';
    final color = _typeColor(type);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _upsert(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(type[0], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(prodSku, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(type.replaceAll('_', ' '), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(prodName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Row(children: [
                Text(_fmtPrice(p), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.teal.shade700)),
                if (custName.isNotEmpty) ...[const SizedBox(width: 8),
                  Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                  Text('$custCode - $custName', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ]),
              Row(children: [
                Text('From: ${validFrom.length >= 10 ? validFrom.substring(0, 10) : validFrom}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                if (validTo.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('To: ${validTo.length >= 10 ? validTo.substring(0, 10) : validTo}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ]),
            ])),
            Column(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Colors.green : Colors.grey),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _delete(id, '$prodSku $_fmtPrice'),
                child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Material Price Dialog (Create / Edit)
// ═══════════════════════════════════════════════

class _MaterialPriceDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> products;
  final List<dynamic> customers;
  final String token;
  final AuthService authService;
  const _MaterialPriceDialog({this.existing, required this.products, required this.customers, required this.token, required this.authService});

  @override State<_MaterialPriceDialog> createState() => _MaterialPriceDialogState();
}

class _MaterialPriceDialogState extends State<_MaterialPriceDialog> {
  String? _productId;
  String? _customerId;
  String _priceType = 'STANDARD';
  final _priceCtrl = TextEditingController();
  String _currency = 'USD';
  final _priceUnitCtrl = TextEditingController(text: '1');
  String _uom = '';
  DateTime _validFrom = DateTime.now();
  DateTime? _validTo;

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _productId = e['product_id']?.toString();
      _customerId = e['customer_id']?.toString();
      _priceType = e['price_type']?.toString() ?? 'STANDARD';
      _priceCtrl.text = (e['price'] as num?)?.toStringAsFixed(2) ?? '';
      _currency = e['currency']?.toString() ?? 'USD';
      _priceUnitCtrl.text = ((e['price_unit'] as int?) ?? 1).toString();
      _uom = e['uom']?.toString() ?? '';
      if (e['valid_from'] != null) { _validFrom = DateTime.parse(e['valid_from'].toString()); }
      if (e['valid_to'] != null) { _validTo = DateTime.parse(e['valid_to'].toString()); }
    }
  }

  @override void dispose() { _priceCtrl.dispose(); _priceUnitCtrl.dispose(); super.dispose(); }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Material Price' : 'New Material Price'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Product
            DropdownButtonFormField<String>(
              value: _productId,
              decoration: const InputDecoration(labelText: 'Product *', isDense: true),
              isExpanded: true,
              items: widget.products.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(
                value: p['id']?.toString(),
                child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (v) => setState(() => _productId = v),
              style: const TextStyle(fontSize: 12),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 8),

            // Price Type
            DropdownButtonFormField<String>(
              value: _priceType,
              decoration: const InputDecoration(labelText: 'Price Type', isDense: true),
              items: const [
                DropdownMenuItem(value: 'STANDARD', child: Text('Standard', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'PROMOTIONAL', child: Text('Promotional', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'VOLUME', child: Text('Volume', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'CONTRACT', child: Text('Contract', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'CUSTOMER_SPECIFIC', child: Text('Customer Specific', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _priceType = v ?? 'STANDARD'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),

            // Price Amount
            Row(children: [
              Expanded(flex: 2, child: TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price *', isDense: true),
                keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency', isDense: true),
                items: ['USD', 'EUR', 'GBP', 'CNY', 'JPY'].map((c) =>
                    DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                style: const TextStyle(fontSize: 12),
              )),
            ]),
            const SizedBox(height: 8),

            // Customer
            DropdownButtonFormField<String>(
              value: _customerId,
              decoration: const InputDecoration(labelText: 'Customer (optional)', isDense: true),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('All customers (standard price)', style: TextStyle(fontSize: 12))),
                ...widget.customers.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                  value: c['id']?.toString(),
                  child: Text('${c['customer_code']} - ${c['name']}', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() => _customerId = v),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),

            // Price Unit + UOM
            Row(children: [
              Expanded(child: TextField(
                controller: _priceUnitCtrl,
                decoration: const InputDecoration(labelText: 'Price Unit', isDense: true, hintText: '1'),
                keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: TextEditingController(text: _uom),
                decoration: const InputDecoration(labelText: 'UOM (override)', isDense: true, hintText: 'EA'),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => _uom = v,
              )),
            ]),
            const SizedBox(height: 8),

            // Valid From / To
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _validFrom, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _validFrom = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Valid From *', isDense: true),
                  child: Text('${_validFrom.year}-${_validFrom.month.toString().padLeft(2,'0')}-${_validFrom.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              )),
              const SizedBox(width: 8),
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _validTo ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _validTo = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Valid To', isDense: true),
                  child: Builder(builder: (ctx) { final d = _validTo; return Text(d == null ? 'No end' : '${d!.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')); }),
                ),
              )),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_productId == null || _priceCtrl.text.isEmpty) return;
          final price = double.tryParse(_priceCtrl.text);
          if (price == null || price <= 0) return;
          final data = <String, dynamic>{
            'product_id': _productId,
            'price_type': _priceType,
            'price': price,
            'currency': _currency,
            'price_unit': int.tryParse(_priceUnitCtrl.text) ?? 1,
            'valid_from': '${_validFrom.year}-${_validFrom.month.toString().padLeft(2,'0')}-${_validFrom.day.toString().padLeft(2,'0')}',
          };
          if (_customerId != null && _customerId!.isNotEmpty) data['customer_id'] = _customerId!;
          if (_uom.isNotEmpty) data['uom'] = _uom;
          if (_validTo != null) data['valid_to'] = '${_validTo!.year}-${_validTo!.month.toString().padLeft(2,'0')}-${_validTo!.day.toString().padLeft(2,'0')}';
          Navigator.pop(context, data);
        }, child: Text(_isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}
