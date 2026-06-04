import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class ProductMasterScreen extends StatefulWidget {
  final AuthService authService; final WarehouseService warehouseService;
  const ProductMasterScreen({super.key, required this.authService, required this.warehouseService});
  @override State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  List<dynamic> _products = []; bool _loading = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load({String? query}) async {
    setState(() => _loading = true);
    try { final d = await widget.warehouseService.listProducts(query: query); if (mounted) setState(() => _products = d); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Product', style: TextStyle(fontSize: 16)),
      content: const Text('Delete this product? Cannot be undone.'), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), child: const Text('Delete')),
    ]));
    if (confirm != true) return;
    try { await widget.warehouseService.deleteProduct(id); if (mounted) { _showMsg('Product deleted'); _load(); } }
    catch (e) { if (mounted) _showMsg('$e', isError: true); }
  }

  void _showMsg(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {}, title: 'Product Master',
      body: Column(children: [
        // Search + New
        Container(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: _searchCtrl,
            decoration: InputDecoration(hintText: 'Search SKU, name, barcode...', hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 13), onSubmitted: (v) => _load(query: v), textInputAction: TextInputAction.search,
          )),
          const SizedBox(width: 8), Text('${_products.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(width: 8),
          ElevatedButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('New Product', style: TextStyle(fontSize: 12)),
              onPressed: () => _openDetail(), style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12))),
        ])),
        const Divider(height: 1),
        // Column headers
        if (_products.isNotEmpty)
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), color: Colors.grey.shade100, child: Row(children: [
            const Expanded(flex: 2, child: Text('SKU', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            const Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            const Expanded(flex: 1, child: Text('UOM', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            const Expanded(flex: 1, child: Text('Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300), const SizedBox(height: 8),
                Text('No products', style: TextStyle(color: Colors.grey.shade500)),
              ]))
            : ListView.builder(padding: const EdgeInsets.symmetric(vertical: 2), itemCount: _products.length,
                itemBuilder: (_, i) => _ProductRow(
                  entry: _products[i],
                  onTap: () => _openDetail(entry: _products[i]),
                  onDelete: () => _delete(_products[i]['id'].toString()),
                ))),
      ]),
    );
  }

  /// Opens the full tabbed detail screen
  void _openDetail({Map<String, dynamic>? entry}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ProductDetailScreen(
      authService: widget.authService, warehouseService: widget.warehouseService, entry: entry, onSaved: _load,
    )));
  }
}

// ════════════════════════════════════════════════════════════
//  Product Detail Screen — Tabbed Multi-View (per SRD §4)
// ════════════════════════════════════════════════════════════

class _ProductDetailScreen extends StatefulWidget {
  final AuthService authService; final WarehouseService warehouseService;
  final Map<String, dynamic>? entry; final VoidCallback onSaved;
  const _ProductDetailScreen({required this.authService, required this.warehouseService, this.entry, required this.onSaved});

  @override State<_ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<_ProductDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _skuCtrl = TextEditingController(), _nameCtrl = TextEditingController(), _descCtrl = TextEditingController();
  final _dimLCtrl = TextEditingController(), _dimWCtrl = TextEditingController(), _dimHCtrl = TextEditingController();
  final _grossWCtrl = TextEditingController(), _netWCtrl = TextEditingController();
  final _stdCostCtrl = TextEditingController(), _movAvgCtrl = TextEditingController(), _lastCostCtrl = TextEditingController();
  final _hsCodeCtrl = TextEditingController(), _originCtrl = TextEditingController();
  final _maxStockCtrl = TextEditingController(), _safetyStockCtrl = TextEditingController();
  final _reorderPointCtrl = TextEditingController(), _reorderQtyCtrl = TextEditingController();
  final _leadTimeCtrl = TextEditingController();
  final _taxExemptReasonCtrl = TextEditingController();

  String _dimUnit = 'cm', _weightUnit = 'kg', _uom = 'EA', _abcClass = '';
  String _procurementType = '', _storageCondition = '', _valuationClass = '';
  String? _taxCategory;
  String? _defaultTaxJurisdictionId;
  bool _batchTracked = false, _serialTracked = false, _isSerialized = false;
  int? _shelfLife;
  bool _saving = false;

  bool get _isEdit => widget.entry != null;
  String? _savedProductId;
  String? get _productId => _savedProductId ?? widget.entry?['id']?.toString();

  List<dynamic> _barcodes = [];
  List<dynamic> _photos = [];
  List<dynamic> _taxJurisdictions = [];
  bool _loadingJurisdictions = true;
  List<Map<String, dynamic>> _taxCategoryOptions = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 6, vsync: this);
    _populateFromEntry();
    if (_productId != null) { _loadBarcodes(); _loadPhotos(); }
    _loadTaxJurisdictions();
    _loadTaxCategories();
  }

  @override void dispose() { _tc.dispose(); _skuCtrl.dispose(); _nameCtrl.dispose(); _descCtrl.dispose(); _dimLCtrl.dispose(); _dimWCtrl.dispose(); _dimHCtrl.dispose(); _grossWCtrl.dispose(); _netWCtrl.dispose(); _stdCostCtrl.dispose(); _movAvgCtrl.dispose(); _lastCostCtrl.dispose(); _hsCodeCtrl.dispose(); _originCtrl.dispose(); _maxStockCtrl.dispose(); _safetyStockCtrl.dispose(); _reorderPointCtrl.dispose(); _reorderQtyCtrl.dispose(); _leadTimeCtrl.dispose(); _taxExemptReasonCtrl.dispose(); super.dispose(); }

  void _populateFromEntry() {
    final e = widget.entry; if (e == null) return;
    _skuCtrl.text = e['sku'] ?? '';
    _nameCtrl.text = e['name'] ?? '';
    _descCtrl.text = e['description'] ?? '';
    _uom = e['unit_of_measure'] ?? 'EA';
    _batchTracked = e['batch_tracked'] ?? false;
    _serialTracked = e['serial_tracked'] ?? false;
    _isSerialized = e['is_serialized'] ?? false;
    _shelfLife = e['shelf_life_days'] as int?;
    _taxCategory = e['tax_category']?.toString();
    _taxExemptReasonCtrl.text = e['tax_exempt_reason']?.toString() ?? '';
    _defaultTaxJurisdictionId = e['default_tax_jurisdiction_id']?.toString();
    _dimLCtrl.text = e['dimension_length']?.toString() ?? '';
    _dimWCtrl.text = e['dimension_width']?.toString() ?? '';
    _dimHCtrl.text = e['dimension_height']?.toString() ?? '';
    _dimUnit = e['dimension_unit'] ?? 'cm';
    _grossWCtrl.text = e['gross_weight']?.toString() ?? '';
    _netWCtrl.text = e['net_weight']?.toString() ?? '';
    _weightUnit = e['weight_unit'] ?? 'kg';
    _stdCostCtrl.text = (e['standard_cost'] as num?)?.toStringAsFixed(2) ?? '0';
    _movAvgCtrl.text = (e['moving_avg_cost'] as num?)?.toStringAsFixed(2) ?? '0';
    _lastCostCtrl.text = (e['last_cost'] as num?)?.toStringAsFixed(2) ?? '0';
    _abcClass = e['abc_classification'] ?? '';
    _valuationClass = e['valuation_class'] ?? '';
    _hsCodeCtrl.text = e['hs_code'] ?? '';
    _originCtrl.text = e['country_of_origin'] ?? '';
    _procurementType = e['procurement_type'] ?? '';
    _storageCondition = e['storage_condition'] ?? '';
    _safetyStockCtrl.text = (e['min_stock_qty'] as num?)?.toStringAsFixed(2) ?? '';
    _maxStockCtrl.text = (e['max_stock_qty'] as num?)?.toStringAsFixed(2) ?? '';
    _reorderPointCtrl.text = (e['reorder_point'] as num?)?.toStringAsFixed(2) ?? '';
    _reorderQtyCtrl.text = (e['reorder_qty'] as num?)?.toStringAsFixed(2) ?? '';
    _leadTimeCtrl.text = e['lead_time_days']?.toString() ?? '';
  }

  Future<void> _loadTaxJurisdictions() async {
    try {
      final token = widget.authService.accessToken ?? '';
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode < 400) {
        _taxJurisdictions = ((jsonDecode(resp.body)['data'] as List?) ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingJurisdictions = false);
  }

  Future<void> _loadTaxCategories() async {
    try {
      final token = widget.authService.accessToken ?? '';
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode < 400) {
        _taxCategoryOptions = ((jsonDecode(resp.body)['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCategories = false);
  }

  Future<void> _loadBarcodes() async {
    if (_productId == null) return;
    try { final d = await widget.warehouseService.listBarcodes(_productId!); if (mounted) setState(() => _barcodes = d); }
    catch (_) {}
  }

  Future<void> _loadPhotos() async {
    if (_productId == null) return;
    try { final d = await widget.warehouseService.listPhotos(_productId!); if (mounted) setState(() => _photos = d); }
    catch (_) {}
  }

  Future<String?> _save({bool returnProductId = false}) async {
    if (_skuCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) { _msg('SKU and Name required'); return null; }
    if (_saving) return null;
    setState(() => _saving = true);
    String? newId;
    final data = {
      'sku': _skuCtrl.text.trim(), 'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim(),
      'unit_of_measure': _uom,
      'batch_tracked': _batchTracked, 'serial_tracked': _serialTracked,
      'is_serialized': _isSerialized,
      'shelf_life_days': _shelfLife,
      'abc_classification': _abcClass, 'valuation_class': _valuationClass,
      'hs_code': _hsCodeCtrl.text.trim(), 'country_of_origin': _originCtrl.text.trim(),
      'procurement_type': _procurementType, 'storage_condition': _storageCondition,
      'dimension_length': double.tryParse(_dimLCtrl.text),
      'dimension_width': double.tryParse(_dimWCtrl.text),
      'dimension_height': double.tryParse(_dimHCtrl.text),
      'dimension_unit': _dimUnit,
      'gross_weight': double.tryParse(_grossWCtrl.text),
      'net_weight': double.tryParse(_netWCtrl.text),
      'weight_unit': _weightUnit,
      'standard_cost': double.tryParse(_stdCostCtrl.text) ?? 0,
      'moving_avg_cost': double.tryParse(_movAvgCtrl.text) ?? 0,
      'last_cost': double.tryParse(_lastCostCtrl.text) ?? 0,
      'safety_stock': double.tryParse(_safetyStockCtrl.text),
      'max_stock_qty': double.tryParse(_maxStockCtrl.text),
      'reorder_point': double.tryParse(_reorderPointCtrl.text),
      'reorder_qty': double.tryParse(_reorderQtyCtrl.text),
      'lead_time_days': int.tryParse(_leadTimeCtrl.text),
      'tax_exempt_reason': _taxExemptReasonCtrl.text.trim(),
      'default_tax_jurisdiction_id': (_defaultTaxJurisdictionId != null && _defaultTaxJurisdictionId!.isNotEmpty) ? _defaultTaxJurisdictionId : null,
    };
    if (_taxCategory != null) {
      data['tax_category'] = _taxCategory;
    }
    try {
      Map<String, dynamic>? result;
      if (_isEdit) {
        await widget.warehouseService.updateProduct(_productId!, data);
      } else {
        result = await widget.warehouseService.createProduct(data);
        newId = result?['id']?.toString();
      }
      widget.onSaved();
      if (returnProductId && !_isEdit && newId != null) {
        _savedProductId = newId;
        if (mounted) _msg('Product created');
      } else {
        if (mounted) { _msg(_isEdit ? 'Updated' : 'Created'); Navigator.pop(context); }
      }
    } catch (e) { if (mounted) _msg('$e', isError: true); }
    finally { if (mounted) setState(() => _saving = false); }
    return newId;
  }

  void _msg(String m, {bool isError = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));

  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {}, title: _isEdit ? _skuCtrl.text : 'New Product',
      body: Column(children: [
        // Action bar
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
          Text(_isEdit ? _skuCtrl.text : 'New Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade800)),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.save, size: 16),
            label: Text(_saving ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 12)),
            onPressed: _saving ? null : () => _save(),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
        ])),
        const Divider(height: 1),
        // Tabs
        Container(color: Colors.white, child: TabBar(
          controller: _tc, isScrollable: true, labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey.shade600, indicatorColor: AppTheme.accentBlue,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 16), child: Text('Basic', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.straighten, size: 16), child: Text('Dimensions', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.attach_money, size: 16), child: Text('Costing', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.qr_code, size: 16), child: Text('Barcodes', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.photo_library, size: 16), child: Text('Photos', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.receipt, size: 16), child: Text('Taxability', style: TextStyle(fontSize: 12))),
          ],
        )),
        const Divider(height: 1),
        Expanded(child: TabBarView(controller: _tc, children: [
          _buildBasicTab(), _buildDimTab(), _buildCostTab(), _buildBarcodeTab(), _buildPhotoTab(), _buildTaxTab(),
        ])),
      ]),
    );
  }

  // ── Tab 1: Basic Info ──
  Widget _buildBasicTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _label('Basic Information'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _skuCtrl, decoration: const InputDecoration(labelText: 'SKU *', isDense: true), style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _uom, decoration: const InputDecoration(labelText: 'UOM', isDense: true),
          items: ['EA','KG','M','L','BOX','PCS','SET','M2','M3'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _uom = v!),
        )),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name *', isDense: true), style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 12),
      TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), maxLines: 3, style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 16),
      _label('Classification & Tracking'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _abcClass, decoration: const InputDecoration(labelText: 'ABC Class', isDense: true),
          items: ['','A','B','C'].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? '(none)' : v, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _abcClass = v!),
        )),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _hsCodeCtrl, decoration: const InputDecoration(labelText: 'HS Code', isDense: true), style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _originCtrl, decoration: const InputDecoration(labelText: 'Origin', isDense: true), style: const TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 16),
      _label('Inventory Planning & Safety Stock'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _safetyStockCtrl, decoration: const InputDecoration(labelText: 'Safety Stock', isDense: true, hintText: '0.00'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _maxStockCtrl, decoration: const InputDecoration(labelText: 'Max Stock', isDense: true, hintText: '0.00'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _reorderPointCtrl, decoration: const InputDecoration(labelText: 'Reorder Point', isDense: true, hintText: '0.00'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _reorderQtyCtrl, decoration: const InputDecoration(labelText: 'Reorder Qty', isDense: true, hintText: '0'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: TextField(controller: _leadTimeCtrl, decoration: const InputDecoration(labelText: 'Lead Time (days)', isDense: true, hintText: '0'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          initialValue: _procurementType, decoration: const InputDecoration(labelText: 'Procurement', isDense: true),
          items: ['','in-house','external','both'].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? '(none)' : v, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _procurementType = v!),
        )),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Checkbox(value: _batchTracked, onChanged: (v) => setState(() => _batchTracked = v!), activeColor: AppTheme.accentBlue),
        const Text('Batch Tracked', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 20),
        if (_batchTracked) ...[
          Checkbox(value: _serialTracked, onChanged: (v) => setState(() => _serialTracked = v!), activeColor: AppTheme.accentBlue),
          const Text('Serial Tracked', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: TextField(decoration: const InputDecoration(labelText: 'Shelf Life(d)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
              keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(fontSize: 12),
              onChanged: (v) => _shelfLife = int.tryParse(v))),
        ],
      ]),
    ]));
  }

  // ── Tab 2: Dimensions & Weight ──
  Widget _buildDimTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _label('Package Dimensions (REQ-MM-011~018)'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _dimLCtrl, decoration: const InputDecoration(labelText: 'Length', isDense: true, hintText: '0.00'),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _dimWCtrl, decoration: const InputDecoration(labelText: 'Width', isDense: true, hintText: '0.00'),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _dimHCtrl, decoration: const InputDecoration(labelText: 'Height', isDense: true, hintText: '0.00'),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: DropdownButtonFormField<String>(
          initialValue: _dimUnit, decoration: const InputDecoration(labelText: 'Unit', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
          items: ['cm','mm','m','inch','ft'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _dimUnit = v!),
        )),
      ]),
      const SizedBox(height: 20),
      _label('Weight'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _grossWCtrl, decoration: const InputDecoration(labelText: 'Gross Weight', isDense: true, hintText: '0.00'),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _netWCtrl, decoration: const InputDecoration(labelText: 'Net Weight', isDense: true, hintText: '0.00'),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: DropdownButtonFormField<String>(
          initialValue: _weightUnit, decoration: const InputDecoration(labelText: 'Unit', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
          items: ['kg','g','lb','oz'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _weightUnit = v!),
        )),
      ]),
    ]));
  }

  // ── Tab 3: Costing ──
  Widget _buildCostTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _label('Costing (REQ-MM-019~027)'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _stdCostCtrl, decoration: const InputDecoration(labelText: 'Standard Cost', isDense: true, prefixText: '\$ '),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: _movAvgCtrl, decoration: const InputDecoration(labelText: 'Moving Avg Cost', isDense: true, prefixText: '\$ '),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _lastCostCtrl, decoration: const InputDecoration(labelText: 'Last Cost', isDense: true, prefixText: '\$ '),
            keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
        const Spacer(),
      ]),
    ]));
  }

  // ── Tab 4: Barcodes ──
  Widget _buildBarcodeTab() {
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), child: Row(children: [
        Text('${_barcodes.length} barcode(s)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        OutlinedButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add Barcode', style: TextStyle(fontSize: 11)),
          onPressed: () => _addBarcode(),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8))),
      ])),
      const Divider(height: 1),
      Expanded(child: _barcodes.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No barcodes. Add EAN-13, UPC-A, Code128 or QR.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _barcodes.length,
            itemBuilder: (_, i) => _buildBarcodeRow(_barcodes[i]))),
    ]);
  }

  Widget _buildBarcodeRow(dynamic b) {
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(Icons.qr_code, size: 22, color: Colors.indigo.shade300),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['barcode'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          Text(b['barcode_type'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ])),
        if (b['is_primary'] == true) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)),
          child: Text('PRIMARY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.blue.shade700))),
        IconButton(icon: Icon(Icons.delete, size: 16, color: Colors.red.shade300), padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28),
          onPressed: () async {
            final bid = b['id']?.toString(); if (bid == null) return;
            try { await widget.warehouseService.deleteBarcode(_productId!, bid); _loadBarcodes(); }
            catch (e) { _msg('$e', isError: true); }
          }),
      ]),
    );
  }

  Future<void> _addBarcode() async {
    // If creating new product, save it first
    if (_productId == null) {
      final saved = await _save(returnProductId: true);
      if (saved == null) { _msg('Please save the product first', isError: true); return; }
    }
    if (_productId == null) { _msg('Cannot add barcode: product ID missing', isError: true); return; }
    final codeCtrl = TextEditingController();
    String type = 'EAN-13';
    await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(title: const Text('Add Barcode', style: TextStyle(fontSize: 16)),
        content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Barcode *', isDense: true), style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: type, decoration: const InputDecoration(labelText: 'Type', isDense: true),
            items: ['EAN-13','EAN-8','UPC-A','Code128','QR','SSCC'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setD(() => type = v!),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (codeCtrl.text.trim().isEmpty) return;
            try { await widget.warehouseService.createBarcode(_productId!, {'barcode': codeCtrl.text.trim(), 'barcode_type': type}); if (ctx.mounted) Navigator.pop(ctx, true); _loadBarcodes(); }
            catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor)); }
          }, child: const Text('Add')),
        ],
      ),
    ));
  }

  // ── Tab 5: Photos ──
  Widget _buildPhotoTab() {
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), child: Row(children: [
        Text('${_photos.length} photo(s)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        OutlinedButton.icon(icon: const Icon(Icons.upload_file, size: 16), label: const Text('Upload Photo', style: TextStyle(fontSize: 11)),
          onPressed: _uploadPhoto,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8))),
      ])),
      const Divider(height: 1),
      Expanded(child: _photos.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No photos. Upload product images (JPEG/PNG).', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]))
        : GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1),
            itemCount: _photos.length,
            itemBuilder: (_, i) => _buildPhotoCard(_photos[i]))),
    ]);
  }

  Widget _buildPhotoCard(dynamic p) {
    final filePath = p['file_path']?.toString() ?? '';
    final hasImage = filePath.isNotEmpty;
    final imgUrl = hasImage ? 'http://localhost:8080/$filePath' : null;
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
          image: imgUrl != null
            ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
            : null,
          color: Colors.grey.shade100),
        child: !hasImage
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.image, size: 28, color: Colors.grey.shade400),
              const SizedBox(height: 4),
              Text(p['file_name'] ?? '', style: TextStyle(fontSize: 8, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]))
          : null,
      ),
      if (_productId != null)
        Positioned(top: 2, right: 2, child: GestureDetector(
          onTap: () async {
            final delId = p['id']?.toString(); if (delId == null) return;
            try { await widget.warehouseService.deletePhoto(_productId!, delId); _loadPhotos(); }
            catch (e) { _msg('$e', isError: true); }
          },
          child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 14, color: Colors.white)),
        )),
      // Primary badge
      if (p['is_primary'] == true)
        Positioned(bottom: 2, left: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(3)),
          child: const Text('PRIMARY', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600)),
        )),
    ]);
  }

  Future<void> _uploadPhoto() async {
    // If creating new product, save it first
    if (_productId == null) {
      final saved = await _save(returnProductId: true);
      if (saved == null) return;
      // _productId will be available after save sets the entry
    }
    if (_productId == null) { _msg('Cannot upload: product ID missing', isError: true); return; }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      // Use try-catch for file.path (throws on web)
      String? filePath;
      try { filePath = file.path; } catch (_) {}
      if (filePath != null) {
        // Desktop — file path available
        await widget.warehouseService.uploadPhoto(_productId!, filePath, file.name);
      } else {
        // Web — use bytes
        if (file.bytes == null) { _msg('No file data available', isError: true); return; }
        final uri = Uri.parse('http://localhost:8080/api/v1/warehouse/products/$_productId/photos');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer ${widget.authService.accessToken ?? ""}';
        request.files.add(http.MultipartFile.fromBytes('photo', file.bytes!, filename: file.name));
        final streamedResp = await request.send();
        final resp = await http.Response.fromStream(streamedResp);
        if (resp.statusCode >= 400) {
          final body = jsonDecode(resp.body);
          throw Exception(body['message'] ?? 'Upload failed');
        }
      }
      _msg('Photo uploaded');
      _loadPhotos();
    } catch (e) {
      _msg('Upload failed: $e', isError: true);
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  Tab 6: Taxability
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildTaxTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Tax Classification'),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _taxCategoryOptions.any((c) => c['code'] == _taxCategory) ? _taxCategory : null,
        decoration: const InputDecoration(labelText: 'Tax Category', isDense: true),
        items: _loadingCategories
          ? [const DropdownMenuItem(value: null, child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)))]
          : [
              if (_taxCategory != null && !_taxCategoryOptions.any((c) => c['code'] == _taxCategory))
                const DropdownMenuItem(value: null, child: Text('Select a tax category', style: TextStyle(fontSize: 12, color: Colors.grey))),
              ..._taxCategoryOptions.map((c) => DropdownMenuItem(
                  value: c['code']?.toString(),
                  child: Text('${c['code']} — ${c['description']}', style: const TextStyle(fontSize: 12)),
                )).toList(),
          ],
        onChanged: _loadingCategories ? null : (v) => setState(() => _taxCategory = v),
      ),
      const SizedBox(height: 16),

      if (_taxCategory == 'EXEMPT' || _taxCategory == 'EXP') ...[const SizedBox(height: 8),
        _label('Tax Exemption Details'),
        const SizedBox(height: 8),
        TextField(
          controller: _taxExemptReasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Exemption Reason', isDense: true,
            hintText: 'RESALE, GOVERNMENT, NON_PROFIT, CHARITABLE, OTHER',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
      ],

      if (!_loadingJurisdictions) ...[
        _label('Default Tax Jurisdiction'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _defaultTaxJurisdictionId,
          decoration: const InputDecoration(
            labelText: 'Jurisdiction', isDense: true,
            hintText: 'Optional â€” override for this product',
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: '', child: Text('None (use default)', style: TextStyle(fontSize: 12))),
            ..._taxJurisdictions.map((j) {
              final state = j['state']?.toString() ?? '';
              final county = j['county']?.toString() ?? '';
              final rate = ((j['tax_rate'] as num?)?.toDouble() ?? 0) * 100;
              return DropdownMenuItem(
                value: j['id']?.toString(),
                child: Text('$state - ${county.isNotEmpty ? "$county " : ""}(${rate.toStringAsFixed(2)}%)', style: const TextStyle(fontSize: 12)),
              );
            }),
          ],
          onChanged: (v) => setState(() => _defaultTaxJurisdictionId = v),
        ),
      ],
      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (_taxCategory == 'EXEMPT' || _taxCategory == 'EXP') ? Colors.green.withValues(alpha: 0.06) : Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: (_taxCategory == 'EXEMPT' || _taxCategory == 'EXP') ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon((_taxCategory == 'EXEMPT' || _taxCategory == 'EXP') ? Icons.check_circle : Icons.info_outline, size: 18,
              color: (_taxCategory == 'EXEMPT' || _taxCategory == 'EXP') ? Colors.green : Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(
            (_taxCategory == 'EXEMPT' || _taxCategory == 'EXP')
              ? 'This product is marked as tax-exempt. Sales to customers will not include tax when this item is sold.'
              : 'Tax will be calculated based on the customer\'s tax jurisdiction and product category.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          )),
        ]),
      ),
    ]));
  }

  Widget _label(String t) => Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700));
}

// ════════════════════════════════════════════════════════════
//  Product Row (List View)
// ════════════════════════════════════════════════════════════

class _ProductRow extends StatelessWidget {
  final dynamic entry; final VoidCallback? onTap; final VoidCallback? onDelete;
  const _ProductRow({required this.entry, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sku = entry['sku'] ?? ''; final name = entry['name'] ?? ''; final uom = entry['unit_of_measure'] ?? 'EA';
    final abc = entry['abc_classification'] ?? ''; final qty = entry['total_stock_qty'] ?? entry['stock_qty'] ?? '-';
    return InkWell(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))),
        child: Row(children: [
          Expanded(flex: 2, child: Row(children: [
            if (abc == 'A') Icon(Icons.star, size: 12, color: Colors.amber),
            if (abc == 'B') Icon(Icons.circle, size: 8, color: Colors.blue.shade400),
            if (abc == 'C') Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Expanded(child: Text(sku, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
          ])),
          Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: Text(uom, style: const TextStyle(fontSize: 11))),
          Expanded(flex: 1, child: abc.isNotEmpty
            ? Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: abc == 'A' ? Colors.amber.shade50 : abc == 'B' ? Colors.blue.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                child: Text(abc, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: abc == 'A' ? Colors.amber.shade800 : Colors.grey.shade600)))
            : const SizedBox()),
          Expanded(flex: 1, child: Text('$qty', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
          if (onDelete != null) PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade400),
            onSelected: (v) { if (v == 'delete') onDelete?.call(); },
            itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete, size: 16, color: AppTheme.errorColor), title: Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.errorColor)), contentPadding: EdgeInsets.zero))],
          ),
        ]),
      ),
    );
  }
}
