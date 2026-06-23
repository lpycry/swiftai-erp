import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart' show DateFormat;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/date_formatter.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

// ════════════════════════════════════════════════════════════
// Typed Data Models (FSD §5 — strong typing for production stability)
// ════════════════════════════════════════════════════════════

class BOMListItem {
  final String bomId;
  final String materialId;
  final String materialName;
  final String materialSKU;
  final String bomVersion;
  final String status;
  final double baseQty;
  final List<BOMItemModel> items;

  BOMListItem.fromJson(Map<String, dynamic> json)
    : bomId = (json['bom_id'] ?? '').toString(),
      materialId = (json['material_id'] ?? '').toString(),
      materialName = (json['material_name'] ?? '').toString(),
      materialSKU = (json['material_sku'] ?? '').toString(),
      bomVersion = (json['bom_version'] ?? '').toString(),
      status = (json['status'] ?? 'NEW').toString(),
      baseQty = (json['base_qty'] as num?)?.toDouble() ?? 0.0,
      items = ((json['items'] as List?) ?? [])
          .map((i) => BOMItemModel.fromJson(i as Map<String, dynamic>))
          .toList();

  Map<String, dynamic> toJson() => {
    'bom_id': bomId,
    'material_id': materialId,
    'material_name': materialName,
    'material_sku': materialSKU,
    'bom_version': bomVersion,
    'status': status,
    'base_qty': baseQty,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class BOMItemModel {
  final String? itemId;
  final String? componentId;
  final String componentName;
  final String componentSKU;
  final double quantity;
  final String uom;
  final double scrapFactor;
  final bool isPhantomItem;
  final String remark;

  BOMItemModel.fromJson(Map<String, dynamic> json)
    : itemId = (json['item_id'] ?? '').toString(),
      componentId = (json['component_id'] ?? '').toString(),
      componentName = (json['component_name'] ?? '').toString(),
      componentSKU = (json['component_sku'] ?? '').toString(),
      quantity = (json['quantity'] as num?)?.toDouble() ?? 0.0,
      uom = (json['unit_of_measure'] ?? 'EA').toString(),
      scrapFactor = (json['scrap_factor'] as num?)?.toDouble() ?? 0.0,
      isPhantomItem = json['is_phantom_item'] == true,
      remark = (json['remark'] ?? '').toString();

  BOMItemModel.create({
    required this.componentId,
    this.componentName = '',
    this.componentSKU = '',
    this.quantity = 1.0,
    this.uom = 'EA',
    this.scrapFactor = 0.0,
    this.isPhantomItem = false,
    this.remark = '',
    this.itemId,
  });

  /// Actual required quantity per industrial standard: Qty / (1 - scrap_factor)
  double get actualRequired =>
      scrapFactor >= 1.0 ? quantity : quantity / (1.0 - scrapFactor);

  Map<String, dynamic> toJson() => {
    if (itemId != null) 'item_id': itemId,
    if (componentId != null) 'component_id': componentId,
    'quantity': quantity,
    'unit_of_measure': uom,
    'scrap_factor': scrapFactor,
    'is_phantom_item': isPhantomItem,
    'remark': remark,
  };
}

// ════════════════════════════════════════════════════════════
// BOM List Screen
// ════════════════════════════════════════════════════════════
class BomScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  const BomScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });
  @override
  State<BomScreen> createState() => _BomScreenState();
}

class _BomScreenState extends State<BomScreen> {
  List<dynamic> _boms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.productionService.listBOMs();
      if (mounted) setState(() => _boms = d);
    } catch (e) {
      if (mounted) _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM Master Data', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () => _openBOMDetail(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No BOMs yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create BOM'),
                    onPressed: () => _openBOMDetail(),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _boms.length,
              itemBuilder: (_, i) => _bomCard(_boms[i]),
            ),
    );
  }

  Widget _bomCard(dynamic e) {
    final status = e['status'] ?? 'NEW';
    final color = status == 'ACTIVE'
        ? Colors.green
        : status == 'INACTIVE'
        ? Colors.red
        : Colors.orange;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openBOMDetail(entry: e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_tree,
                  color: color.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          e['material_name'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: color.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${e['bom_version'] ?? ''} | SKU: ${e['material_sku'] ?? ''} | Qty: ${(e['base_qty'] as num?)?.toStringAsFixed(4) ?? '1.0000'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _openBOMDetail({Map<String, dynamic>? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BOMDetailScreen(
          authService: widget.authService,
          productionService: widget.productionService,
          entry: entry,
          onSaved: _load,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// BOM Detail Screen — FSD §5: Inline Grid Editing + Tree View
// ════════════════════════════════════════════════════════════
class BOMDetailScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  final Map<String, dynamic>? entry;
  final bool viewOnly;
  final VoidCallback onSaved;
  const BOMDetailScreen({
    super.key,
    required this.authService,
    required this.productionService,
    this.entry,
    this.viewOnly = false,
    required this.onSaved,
  });
  @override
  State<BOMDetailScreen> createState() => _BOMDetailScreenState();
}

class _BOMDetailScreenState extends State<BOMDetailScreen> {
  // Header fields
  final _versionCtrl = TextEditingController(text: 'V1.0');
  final _baseQtyCtrl = TextEditingController(text: '1.0000');
  final _descriptionCtrl = TextEditingController();
  String? _materialId, _materialName, _materialSKU;
  String _status = 'NEW';
  DateTime? _validFromDt, _validToDt;
  bool _saving = false;
  String? _selectedRoutingTemplateId;
  List<dynamic> _routingTemplates = [];

  // Items (inline grid)
  List<Map<String, dynamic>> _items = [];
  final List<TextEditingController> _qtyCtrls = [];
  final List<TextEditingController> _scrapCtrls = [];
  final List<TextEditingController> _remarkCtrls = [];
  bool _itemsChanged = false;

  bool get _isEdit => widget.entry != null;
  String? get _bomId => widget.entry?['bom_id']?.toString();
  final _ws = WarehouseService(''); // lazily initialized

  @override
  void initState() {
    super.initState();
    _populate();
    _loadRoutingTemplates();
    // Fetch full BOM with items from API when editing
    if (_isEdit && !widget.viewOnly) _fetchDetail();
  }

  Future<void> _loadRoutingTemplates() async {
    try {
      final rts = await widget.productionService.listRoutingTemplates();
      if (mounted) setState(() => _routingTemplates = rts);
    } catch (_) {}
  }

  Future<void> _fetchDetail() async {
    try {
      final d = await widget.productionService.getBOM(_bomId!);
      if (!mounted) return;
      _populateFromDetail(d);
    } catch (_) {}
  }

  void _populateFromDetail(Map<String, dynamic> d) {
    final items = d['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return;
    _items.clear();
    _qtyCtrls.clear();
    _scrapCtrls.clear();
    _remarkCtrls.clear();
    for (final item in items) {
      _addItemRow(item);
    }
    _itemsChanged = false;
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _baseQtyCtrl.dispose();
    _descriptionCtrl.dispose();
    for (final c in _qtyCtrls) c.dispose();
    for (final c in _scrapCtrls) c.dispose();
    for (final c in _remarkCtrls) c.dispose();
    super.dispose();
  }

  void _populate() {
    final e = widget.entry;
    if (e == null) return;
    _materialId = e['material_id']?.toString();
    _materialName = e['material_name'] ?? '';
    _materialSKU = e['material_sku'] ?? '';
    _versionCtrl.text = e['bom_version'] ?? 'V1.0';
    _status = e['status'] ?? 'NEW';
    _baseQtyCtrl.text = (e['base_qty'] as num?)?.toStringAsFixed(4) ?? '1.0000';
    _descriptionCtrl.text = e['description'] ?? '';
    _selectedRoutingTemplateId = e['routing_template_id']?.toString();
    _validFromDt = e['valid_from'] is String
        ? DateTime.tryParse(e['valid_from'])
        : null;
    _validToDt = e['valid_to'] is String
        ? DateTime.tryParse(e['valid_to'])
        : null;
    // Load items if present
    final items = e['items'] as List<dynamic>?;
    if (items != null) {
      for (final item in items) {
        _addItemRow(item);
      }
    }
  }

  void _addItemRow([dynamic data]) {
    final idx = _items.length;
    _items.add(
      data != null
          ? Map<String, dynamic>.from(data)
          : {
              'item_position': (idx + 1) * 10,
              'component_id': null,
              'component_name': '',
              'component_sku': '',
              'quantity': 1.0000,
              'unit_of_measure': 'EA',
              'scrap_factor': 0.0000,
              'is_phantom_item': false,
              'remark': '',
            },
    );
    _qtyCtrls.add(
      TextEditingController(
        text: (data?['quantity'] as num?)?.toStringAsFixed(4) ?? '1.0000',
      ),
    );
    _scrapCtrls.add(
      TextEditingController(
        text: ((data?['scrap_factor'] as num?) ?? 0).toStringAsFixed(4),
      ),
    );
    _remarkCtrls.add(TextEditingController(text: data?['remark'] ?? ''));
    setState(() {});
  }

  Future<void> _pickComponent(int idx) async {
    final ws = WarehouseService(widget.authService.accessToken ?? '');
    try {
      final products = await ws.listProducts();
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _ProductSelector(products: products),
      );
      if (selected != null && mounted) {
        setState(() {
          _items[idx]['component_id'] = selected['id']?.toString();
          _items[idx]['component_name'] = selected['name'] ?? '';
          _items[idx]['component_sku'] = selected['sku'] ?? '';
          _items[idx]['unit_of_measure'] = selected['unit_of_measure'] ?? 'EA';
          _itemsChanged = true;
        });
      }
    } catch (_) {}
  }

  // ── Save ──
  Future<void> _save() async {
    if (_materialId == null) {
      _showMsg('Select a material');
      return;
    }
    setState(() => _saving = true);
    try {
      // Build items list
      final items = <Map<String, dynamic>>[];
      for (int i = 0; i < _items.length; i++) {
        if (_items[i]['component_id'] == null) continue;
        items.add({
          'item_position': _items[i]['item_position'] ?? (i + 1) * 10,
          'component_id': _items[i]['component_id'],
          'quantity': double.tryParse(_qtyCtrls[i].text) ?? 1,
          'unit_of_measure': _items[i]['unit_of_measure'] ?? 'EA',
          'scrap_factor': double.tryParse(_scrapCtrls[i].text) ?? 0,
          'is_phantom_item': _items[i]['is_phantom_item'] ?? false,
          'remark': _remarkCtrls[i].text,
        });
      }

      final data = {
        'material_id': _materialId,
        'bom_version': _versionCtrl.text.trim(),
        'base_qty': double.tryParse(_baseQtyCtrl.text) ?? 1,
        // Append Z for UTC — backend accepts RFC3339
        'valid_from': _validFromDt != null
            ? '${_validFromDt!.toUtc().toIso8601String().replaceAll('.000', '')}Z'
                  .replaceAll('ZZ', 'Z')
            : DateTime.now().toUtc().toIso8601String(),
        'valid_to': _validToDt != null
            ? '${_validToDt!.toUtc().toIso8601String().replaceAll('.000', '')}Z'
                  .replaceAll('ZZ', 'Z')
            : '2099-12-31T23:59:59Z',
        'description': _descriptionCtrl.text.trim(),
        'is_active': true,
        if (_selectedRoutingTemplateId != null)
          'routing_template_id': _selectedRoutingTemplateId,
        'items': items,
      };

      if (_isEdit && !widget.viewOnly) {
        await widget.productionService.updateBOM(_bomId!, data);
      } else {
        await widget.productionService.createBOM(data);
      }
      widget.onSaved();
      if (mounted) {
        _showMsg('BOM saved');
        Navigator.pop(context);
      }
    } catch (e) {
      _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'BOM: ${widget.entry!['bom_version'] ?? ''}' : 'New BOM',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_isEdit && !widget.viewOnly)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppTheme.errorColor,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete BOM'),
                    content: const Text('Soft delete this BOM?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await widget.productionService.deleteBOM(_bomId!);
                    widget.onSaved();
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    _showMsg('$e', isError: true);
                  }
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Header Panel ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMaterialSelector()),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _versionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Version',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _baseQtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Base Qty',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: 'Valid From',
                        date: _validFromDt,
                        onSelected: (d) => setState(() => _validFromDt = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: 'Valid To',
                        date: _validToDt,
                        onSelected: (d) => setState(() => _validToDt = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _descriptionCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            _routingTemplates.any(
                              (rt) =>
                                  rt['id']?.toString() ==
                                  _selectedRoutingTemplateId,
                            )
                            ? _selectedRoutingTemplateId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Routing Template',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                        items: _routingTemplates.map<DropdownMenuItem<String>>((
                          rt,
                        ) {
                          final rtId = (rt['id'] ?? '').toString();
                          final rtName =
                              '${rt['template_code'] ?? ''} - ${rt['template_name'] ?? ''}';
                          return DropdownMenuItem(
                            value: rtId,
                            child: Text(
                              rtName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: widget.viewOnly
                            ? null
                            : (v) => setState(
                                () => _selectedRoutingTemplateId = v,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                      _saving ? 'Saving...' : 'Save BOM',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: (_saving || widget.viewOnly) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Items Inline Grid (FSD §5.1) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Text(
                  'Components (${_items.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Component',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _addItemRow(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const SizedBox(
                  width: 30,
                  child: Text(
                    '#',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Component',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'SKU',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(
                  width: 70,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(
                  width: 60,
                  child: Text(
                    'UOM',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(
                  width: 60,
                  child: Text(
                    'Scrap %',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
          // Scrollable grid
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 36,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No components yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Add Component',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _addItemRow(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _buildItemRow(i),
                  ),
          ),
          // Footer: calculated total
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text(
                'Total components: ${_items.length} | Phantom: ${_items.where((i) => i['is_phantom_item'] == true).length}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int idx) {
    final item = _items[idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${item['item_position'] ?? (idx + 1) * 10}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: widget.viewOnly ? null : () => _pickComponent(idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: item['component_id'] != null
                      ? Colors.indigo.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item['component_name'] ?? 'Select...',
                  style: TextStyle(
                    fontSize: 11,
                    color: item['component_id'] != null
                        ? Colors.indigo.shade800
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item['component_sku'] ?? '',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qtyCtrls[idx],
              keyboardType: TextInputType.number,
              readOnly: widget.viewOnly,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                item['unit_of_measure'] ?? 'EA',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _scrapCtrls[idx],
              keyboardType: TextInputType.number,
              readOnly: widget.viewOnly,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.red.shade300,
              ),
              onPressed: () {
                setState(() {
                  _items.removeAt(idx);
                  _qtyCtrls[idx].dispose();
                  _qtyCtrls.removeAt(idx);
                  _scrapCtrls[idx].dispose();
                  _scrapCtrls.removeAt(idx);
                  _remarkCtrls[idx].dispose();
                  _remarkCtrls.removeAt(idx);
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialSelector() {
    return GestureDetector(
      onTap: () async {
        final ws = WarehouseService(widget.authService.accessToken ?? '');
        try {
          final products = await ws.listProducts();
          if (!mounted) return;
          final selected = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (ctx) => _ProductSelector(products: products),
          );
          if (selected != null && mounted) {
            setState(() {
              _materialId = selected['id']?.toString();
              _materialName = selected['name'] ?? '';
              _materialSKU = selected['sku'] ?? '';
            });
          }
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: _materialId != null
                ? Colors.indigo.shade300
                : Colors.orange.shade300,
          ),
          borderRadius: BorderRadius.circular(6),
          color: _materialId != null
              ? Colors.indigo.shade50
              : Colors.orange.shade50,
        ),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2,
              size: 16,
              color: _materialId != null
                  ? Colors.indigo.shade600
                  : Colors.orange.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _materialName ?? 'Select Material *',
                style: TextStyle(
                  fontSize: 12,
                  color: _materialId != null
                      ? Colors.indigo.shade800
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_materialSKU != null && _materialSKU!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _materialSKU!,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Product Selector Dialog — Reusable (FSD §5.1 Fuzzy Search)
// ════════════════════════════════════════════════════════════
class _ProductSelector extends StatefulWidget {
  final List<dynamic> products;
  const _ProductSelector({required this.products});
  @override
  State<_ProductSelector> createState() => _ProductSelectorState();
}

class _ProductSelectorState extends State<_ProductSelector> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _filtered = widget.products
        .take(50)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () => _filter(q));
  }

  void _filter(String q) {
    if (!mounted) return;
    final query = q.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.products
            .take(50)
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
      } else {
        _filtered = widget.products
            .where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              final sku = (p['sku'] ?? '').toString().toLowerCase();
              return name.contains(query) || sku.contains(query);
            })
            .take(50)
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select Material',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by Name or SKU...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _onSearchChanged,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2,
                            size: 18,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                        title: Text(
                          p['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'SKU: ${p['sku'] ?? ''}  |  UOM: ${p['unit_of_measure'] ?? ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// BOM Tree View Screen (FSD §5.2)
// ════════════════════════════════════════════════════════════
class BOMTreeViewScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  final Map<String, dynamic> bom;
  const BOMTreeViewScreen({
    super.key,
    required this.authService,
    required this.productionService,
    required this.bom,
  });
  @override
  State<BOMTreeViewScreen> createState() => _BOMTreeViewScreenState();
}

class _BOMTreeViewScreenState extends State<BOMTreeViewScreen> {
  List<Map<String, dynamic>> _exploded = [];
  bool _loading = false;
  bool _showMultiLevel = false;

  @override
  void initState() {
    super.initState();
    _explode();
  }

  Future<void> _explode() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final d = await widget.productionService.explodeBOM(
        materialId: widget.bom['material_id'] ?? '',
        bomVersion: widget.bom['bom_version'],
        explosionType: _showMultiLevel ? 'multi' : 'single',
        requirementQty: (widget.bom['base_qty'] as num?)?.toDouble() ?? 1.0,
      );
      if (!mounted) return;
      setState(() => _exploded = d.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) _showMsg('BOM Explosion Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BOM Tree: ${widget.bom['material_name'] ?? ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showMultiLevel ? Icons.unfold_less : Icons.unfold_more,
              size: 20,
            ),
            tooltip: _showMultiLevel ? 'Single Level' : 'Multi Level',
            onPressed: () {
              setState(() => _showMultiLevel = !_showMultiLevel);
              _explode();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exploded.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No components for this BOM',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Text(
                        'Level',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Component',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 60,
                        child: Text(
                          'Qty',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 60,
                        child: Text(
                          'Scrap',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _exploded.length,
                    itemBuilder: (_, i) {
                      final e = _exploded[i];
                      final level = e['level'] as int? ?? 1;
                      return Container(
                        padding: EdgeInsets.only(
                          left: 8.0 + level * 20,
                          right: 8,
                          top: 6,
                          bottom: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: level == 1
                                    ? Colors.blue.shade50
                                    : level == 2
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '$level',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: level == 1
                                        ? Colors.blue.shade700
                                        : level == 2
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e['component_name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: level == 1
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                (e['quantity'] as num?)?.toStringAsFixed(4) ??
                                    '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                ((e['scrap_factor'] as num?) ?? 0) > 0
                                    ? '${((e['scrap_factor'] as num) * 100).toStringAsFixed(1)}%'
                                    : '-',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                ),
                              ),
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

// ════════════════════════════════════════════════════════════
// _DateField — tappable date display that opens a DatePicker
// Date format comes from Settings > Date Formats (AppDateFormatter)
// ════════════════════════════════════════════════════════════

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;

  const _DateField({
    required this.label,
    required this.date,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = AppDateFormatter();
    final displayText = fmt.formatSync(date);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          suffixIcon: const Icon(Icons.calendar_today, size: 14),
        ),
        child: Text(
          displayText.isEmpty ? 'Select date' : displayText,
          style: TextStyle(
            fontSize: 12,
            color: displayText.isEmpty ? Colors.grey : null,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Keep BomScreen backward compat alias for existing imports
// ════════════════════════════════════════════════════════════
