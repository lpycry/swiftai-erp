import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart' show DateFormat;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/date_formatter.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

// ════════════════════════════════════════════════════════════
// Typed Data Model for Production Orders
// ════════════════════════════════════════════════════════════

class ProductionOrderItem {
  final String? orderId;
  final String orderNumber;
  final String? materialId;
  final String materialName;
  final String materialSKU;
  final double orderQty;
  final String status;
  final String priority;
  final String? bomId;
  final String? bomVersion;
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final String notes;

  ProductionOrderItem.fromJson(Map<String, dynamic> json)
    : orderId = json['id']?.toString(),
      orderNumber = (json['order_number'] ?? '').toString(),
      materialId = json['material_id']?.toString(),
      materialName = (json['material_name'] ?? '').toString(),
      materialSKU = (json['material_sku'] ?? '').toString(),
      orderQty = (json['order_qty'] as num?)?.toDouble() ?? 0.0,
      status = (json['status'] ?? 'DRAFT').toString(),
      priority = (json['priority'] ?? 'MEDIUM').toString(),
      bomId = json['bom_id']?.toString(),
      bomVersion = json['bom_version']?.toString(),
      plannedStartDate = json['planned_start_date'] is String
          ? DateTime.tryParse(json['planned_start_date'])
          : null,
      plannedEndDate = json['planned_end_date'] is String
          ? DateTime.tryParse(json['planned_end_date'])
          : null,
      notes = (json['notes'] ?? '').toString();
}

// ════════════════════════════════════════════════════════════
// Production Order List Screen
// ════════════════════════════════════════════════════════════
class ProductionOrderScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  const ProductionOrderScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });
  @override
  State<ProductionOrderScreen> createState() => _ProductionOrderScreenState();
}

class _ProductionOrderScreenState extends State<ProductionOrderScreen> {
  List<dynamic> _orders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.productionService.listProductionOrders();
      if (mounted) setState(() => _orders = d);
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

  Future<void> _deleteOrder(Map<String, dynamic> e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Production Order'),
        content: Text('Delete production order ${e['order_number'] ?? ''} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.productionService.deleteProductionOrder(
          (e['order_id']?.toString() ?? e['id']?.toString()) ?? '',
        );
        _showMsg('Production order deleted');
        _load();
      } catch (e) {
        _showMsg('$e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Orders', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => _openDetail()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No production orders yet', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Order'),
                    onPressed: () => _openDetail(),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _orders.length,
              itemBuilder: (_, i) => _orderCard(_orders[i]),
            ),
    );
  }

  Widget _orderCard(dynamic e) {
    final status = e['status'] ?? 'DRAFT';
    final priority = e['priority'] ?? 'MEDIUM';
    Color statusColor;
    switch (status) {
      case 'COMPLETED': statusColor = Colors.green; break;
      case 'IN_PROCESS':
      case 'PARTIALLY_PRODUCED': statusColor = Colors.blue; break;
      case 'RELEASED': statusColor = Colors.orange; break;
      case 'CANCELLED': statusColor = Colors.red; break;
      case 'CLOSED': statusColor = Colors.purple; break;
      default: statusColor = Colors.grey;
    }
    Color priorityColor;
    switch (priority) {
      case 'URGENT': priorityColor = Colors.red; break;
      case 'HIGH': priorityColor = Colors.orange; break;
      case 'LOW': priorityColor = Colors.grey; break;
      default: priorityColor = Colors.blue;
    }
    final fmt = AppDateFormatter();
    final startDateStr = fmt.formatStringSync(e['planned_start_date'] as String?);
    final endDateStr = fmt.formatStringSync(e['planned_end_date'] as String?);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(e['order_number'] ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                const SizedBox(width: 6),
                _chip(status, statusColor),
                const SizedBox(width: 4),
                _chip(priority, priorityColor),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(e['material_name'] ?? 'N/A', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(2)),
                  child: Text('Qty: ${(e['order_qty'] as num?)?.toStringAsFixed(2) ?? '0'}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'monospace')),
                ),
              ],
            ),
            if ((e['sales_order_number'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.shopping_cart, size: 11, color: Colors.teal.shade400),
                  const SizedBox(width: 3),
                  Text('SO: ${e['sales_order_number']}',
                      style: TextStyle(fontSize: 10, color: Colors.teal.shade700)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(startDateStr.isEmpty ? 'TBD' : startDateStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(endDateStr.isEmpty ? 'TBD' : endDateStr,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _openDetail(entry: e, viewOnly: true),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _openDetail(entry: e),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 14, color: AppTheme.errorColor),
                  label: Text('Delete', style: TextStyle(fontSize: 11, color: AppTheme.errorColor)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _deleteOrder(e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
  );

  void _openDetail({Map<String, dynamic>? entry, bool viewOnly = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionOrderDetailScreen(
          authService: widget.authService,
          productionService: widget.productionService,
          entry: entry,
          viewOnly: viewOnly,
          onSaved: _load,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Production Order Detail Screen
// ════════════════════════════════════════════════════════════
class ProductionOrderDetailScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  final Map<String, dynamic>? entry;
  final bool viewOnly;
  final VoidCallback onSaved;
  const ProductionOrderDetailScreen({
    super.key,
    required this.authService,
    required this.productionService,
    this.entry,
    this.viewOnly = false,
    required this.onSaved,
  });
  @override
  State<ProductionOrderDetailScreen> createState() => _ProductionOrderDetailState();
}

class _ProductionOrderDetailState extends State<ProductionOrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // General tab controllers
  final _orderNumberCtrl = TextEditingController();
  final _orderQtyCtrl = TextEditingController(text: '1.00');
  double _completedQty = 0.0;
  final _notesCtrl = TextEditingController();
  final _bomIdCtrl = TextEditingController();
  final _bomVersionCtrl = TextEditingController();

  // Material fields
  String? _materialId, _materialName, _materialSKU;
  String _status = 'DRAFT';
  String _priority = 'MEDIUM';
  DateTime? _plannedStartDate, _plannedEndDate;
  bool _saving = false;
  List<dynamic> _bomOptions = [];

  // Sales Order fields
  String? _salesOrderId, _salesOrderNumber;
  String? _soItemId;
  int? _soItemLineNo;
  String? _soItemProductName;
  List<dynamic> _soOptions = [];
  List<dynamic> _soItemOptions = [];

  // Routing tab
  Map<String, dynamic>? _routingInfo;
  bool _routingLoading = false;

  // Materials tab
  List<dynamic> _materials = [];
  bool _materialsLoading = false;

  bool get _isEdit => widget.entry != null;
  String? get _orderId =>
      widget.entry?['order_id']?.toString() ?? widget.entry?['id']?.toString();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _populate();
    if (_isEdit) {
      _fetchDetail();
      _loadBOMOptions();
    }
    _loadSalesOrders();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && _routingInfo == null && _orderId != null) {
      _loadRoutingInfo();
    }
    if (_tabController.index == 2 && _materials.isEmpty && _orderId != null) {
      _loadMaterials();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _orderNumberCtrl.dispose();
    _orderQtyCtrl.dispose();
    _notesCtrl.dispose();
    _bomIdCtrl.dispose();
    _bomVersionCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    try {
      final d = await widget.productionService.getProductionOrder(_orderId!);
      if (!mounted) return;
      _populateFromDetail(d);
    } catch (_) {}
  }

  void _populateFromDetail(Map<String, dynamic> d) {
    if (!mounted) return;
    setState(() {
      _materialId = d['material_id']?.toString();
      _materialName = d['material_name'] ?? '';
      _materialSKU = d['material_sku'] ?? '';
      _orderNumberCtrl.text = d['order_number'] ?? '';
      _orderQtyCtrl.text = (d['order_qty'] as num?)?.toStringAsFixed(2) ?? '1.00';
      _completedQty = (d['completed_qty'] as num?)?.toDouble() ?? 0.0;
      _status = d['status'] ?? 'DRAFT';
      _priority = d['priority'] ?? 'MEDIUM';
      _plannedStartDate = d['planned_start_date'] is String
          ? DateTime.tryParse(d['planned_start_date']) : null;
      _plannedEndDate = d['planned_end_date'] is String
          ? DateTime.tryParse(d['planned_end_date']) : null;
      _notesCtrl.text = d['notes'] ?? '';
      _bomIdCtrl.text = d['bom_id']?.toString() ?? '';
      _bomVersionCtrl.text = d['bom_version']?.toString() ?? '';
      // Sales order
      _salesOrderId = d['sales_order_id']?.toString();
      _salesOrderNumber = d['sales_order_number']?.toString();
      _soItemId = d['so_item_id']?.toString();
      _soItemLineNo = d['so_item_line_no'] as int?;
      _soItemProductName = d['so_item_product_name']?.toString();
      // Materials
      final mats = d['materials'];
      if (mats is List) _materials = mats;
    });
    // Load SO items if SO is set
    if (_salesOrderId != null && _salesOrderId!.isNotEmpty) {
      _loadSOItems();
    }
  }

  void _populate() {
    final e = widget.entry;
    if (e == null) return;
    _materialId = e['material_id']?.toString();
    _materialName = e['material_name'] ?? '';
    _materialSKU = e['material_sku'] ?? '';
    _orderNumberCtrl.text = e['order_number'] ?? '';
    _orderQtyCtrl.text = (e['order_qty'] as num?)?.toStringAsFixed(2) ?? '1.00';
    _completedQty = (e['completed_qty'] as num?)?.toDouble() ?? 0.0;
    _status = e['status'] ?? 'DRAFT';
    _priority = e['priority'] ?? 'MEDIUM';
    _plannedStartDate = e['planned_start_date'] is String
        ? DateTime.tryParse(e['planned_start_date']) : null;
    _plannedEndDate = e['planned_end_date'] is String
        ? DateTime.tryParse(e['planned_end_date']) : null;
    _notesCtrl.text = e['notes'] ?? '';
    _bomIdCtrl.text = e['bom_id']?.toString() ?? '';
    _bomVersionCtrl.text = e['bom_version']?.toString() ?? '';
    _salesOrderId = e['sales_order_id']?.toString();
    _salesOrderNumber = e['sales_order_number']?.toString();
    _soItemId = e['so_item_id']?.toString();
    final mats = e['materials'];
    if (mats is List) _materials = mats;
  }

  Future<void> _loadBOMOptions() async {
    if (_materialId == null) return;
    try {
      final boms = await widget.productionService.listBOMs(materialId: _materialId);
      if (mounted) setState(() => _bomOptions = boms);
    } catch (_) {}
  }

  Future<void> _loadSalesOrders() async {
    try {
      final ss = SalesService(widget.authService.accessToken ?? '');
      final orders = await ss.listSalesOrders();
      if (mounted) setState(() => _soOptions = orders);
    } catch (_) {}
  }

  Future<void> _loadSOItems() async {
    if (_salesOrderId == null || _salesOrderId!.isEmpty) return;
    try {
      final ss = SalesService(widget.authService.accessToken ?? '');
      final so = await ss.getSalesOrder(_salesOrderId!);
      final items = so['items'] as List? ?? so['order_items'] as List? ?? [];
      if (mounted) setState(() => _soItemOptions = items);
    } catch (_) {}
  }

  Future<void> _loadRoutingInfo() async {
    if (_orderId == null) return;
    setState(() => _routingLoading = true);
    try {
      final rt = await widget.productionService.getProductionOrderRouting(_orderId!);
      if (mounted) setState(() => _routingInfo = rt);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _routingLoading = false);
    }
  }

  Future<void> _loadMaterials() async {
    if (_orderId == null) return;
    setState(() => _materialsLoading = true);
    try {
      final po = await widget.productionService.getProductionOrder(_orderId!);
      final mats = po['materials'] as List? ?? [];
      if (mounted) setState(() => _materials = mats);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _materialsLoading = false);
    }
  }

  Future<void> _syncMaterials() async {
    if (_orderId == null) return;
    setState(() => _materialsLoading = true);
    try {
      await widget.productionService.syncPOMaterials(_orderId!);
      await _loadMaterials();
      if (mounted) _showMsg('Materials synced from BOM');
    } catch (e) {
      if (mounted) _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _materialsLoading = false);
    }
  }

  Future<void> _save() async {
    if (_materialId == null) { _showMsg('Select a material'); return; }
    final prevBomId = widget.entry?['bom_id']?.toString();
    final newBomId = _bomIdCtrl.text.isNotEmpty ? _bomIdCtrl.text : null;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'material_id': _materialId,
        'material_name': _materialName,
        'order_qty': double.tryParse(_orderQtyCtrl.text) ?? 1,
        'priority': _priority,
        'status': _status,
        if (_plannedStartDate != null) 'planned_start_date': _plannedStartDate!.toIso8601String(),
        if (_plannedEndDate != null) 'planned_end_date': _plannedEndDate!.toIso8601String(),
        'notes': _notesCtrl.text.trim(),
      };
      if (newBomId != null && _bomVersionCtrl.text.isNotEmpty) {
        data['bom_id'] = newBomId;
        data['bom_version'] = _bomVersionCtrl.text;
      }
      if (_salesOrderId != null && _salesOrderId!.isNotEmpty) data['sales_order_id'] = _salesOrderId;
      if (_soItemId != null && _soItemId!.isNotEmpty) data['so_item_id'] = _soItemId;

      if (_isEdit && !widget.viewOnly) {
        await widget.productionService.updateProductionOrder(_orderId!, data);
        // Sync materials if BOM changed
        if (newBomId != null && newBomId != prevBomId) {
          await widget.productionService.syncPOMaterials(_orderId!);
          await _loadMaterials();
        }
      } else {
        await widget.productionService.createProductionOrder(data);
      }
      widget.onSaved();
      if (mounted) { _showMsg('Production order saved'); Navigator.pop(context); }
    } catch (e) {
      _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ));

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return Colors.green;
      case 'IN_PROCESS':
      case 'PARTIALLY_PRODUCED': return Colors.blue;
      case 'RELEASED': return Colors.orange;
      case 'CANCELLED': return Colors.red;
      case 'CLOSED': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _pickMaterial() async {
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
          _bomOptions = [];
          _bomIdCtrl.text = '';
          _bomVersionCtrl.text = '';
        });
        _loadBOMOptions();
      }
    } catch (_) {}
  }

  Future<void> _pickSalesOrder() async {
    if (_soOptions.isEmpty) await _loadSalesOrders();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SalesOrderPickerDialog(orders: _soOptions),
    );
    if (selected != null && mounted) {
      setState(() {
        _salesOrderId = selected['id']?.toString();
        _salesOrderNumber = selected['so_number']?.toString();
        _soItemId = null;
        _soItemLineNo = null;
        _soItemProductName = null;
        _soItemOptions = [];
      });
      _loadSOItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Order: ${widget.entry!['order_number'] ?? ''}' : 'New Production Order',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_isEdit && !widget.viewOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Production Order'),
                    content: const Text('Delete this production order?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await widget.productionService.deleteProductionOrder(_orderId!);
                    widget.onSaved();
                    if (mounted) Navigator.pop(context);
                  } catch (e) { _showMsg('$e', isError: true); }
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Routing'),
            Tab(text: 'Materials'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildRoutingTab(),
          _buildMaterialsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: General ──
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 12),
          TextField(
            controller: _orderNumberCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Order Number (auto-generated)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              prefixIcon: Icon(Icons.tag, size: 18),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          _buildMaterialSelector(),
          const SizedBox(height: 12),
          _buildBOMSelector(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _orderQtyCtrl,
                readOnly: widget.viewOnly,
                decoration: const InputDecoration(
                  labelText: 'Order Qty',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  prefixIcon: Icon(Icons.view_agenda, size: 18),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'].map((v) =>
                  DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: widget.viewOnly ? null : (v) => setState(() => _priority = v!),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // ── Completed Qty (read-only, updated by GR) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(6),
              color: Colors.blue.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text('Completed Qty',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                const Spacer(),
                Text(
                  _completedQty.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 6),
                Text('/ ${_orderQtyCtrl.text}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade400)),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Updated automatically by Goods Receipt',
                  child: Icon(Icons.info_outline, size: 14, color: Colors.blue.shade300),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _statusColor(_status).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
              color: _statusColor(_status).withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _statusColor(_status)),
                const SizedBox(width: 8),
                Text('Status: $_status',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(_status))),
                const Spacer(),
                if (_isEdit && !widget.viewOnly)
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 11, color: _statusColor(_status)),
                      items: ['DRAFT', 'RELEASED', 'IN_PROCESS', 'PARTIALLY_PRODUCED', 'COMPLETED', 'CLOSED', 'CANCELLED'].map((v) =>
                        DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _DateField(
              label: 'Planned Start Date', date: _plannedStartDate,
              onSelected: (d) => setState(() => _plannedStartDate = d),
              readOnly: widget.viewOnly,
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateField(
              label: 'Planned End Date', date: _plannedEndDate,
              onSelected: (d) => setState(() => _plannedEndDate = d),
              readOnly: widget.viewOnly,
            )),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            readOnly: widget.viewOnly,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.notes, size: 18),
              ),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          // ── Sales Order Selector ──
          _buildSOSelector(),
          const SizedBox(height: 8),
          // ── SO Line Item Selector ──
          _buildSOItemSelector(),
          const SizedBox(height: 16),
          if (!widget.viewOnly)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: Text(_saving ? 'Saving...' : _isEdit ? 'Update Order' : 'Create Order',
                    style: const TextStyle(fontSize: 12)),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Status Bar (top of General tab) ──
  Widget _buildStatusBar() {
    const statuses = ['DRAFT', 'RELEASED', 'PARTIALLY_PRODUCED', 'COMPLETED', 'CLOSED'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: statuses.map((s) {
              final isCurrent = _status == s;
              Color c;
              switch (s) {
                case 'RELEASED': c = Colors.orange; break;
                case 'PARTIALLY_PRODUCED': c = Colors.blue; break;
                case 'COMPLETED': c = Colors.green; break;
                case 'CLOSED': c = Colors.purple; break;
                default: c = Colors.grey;
              }
              return Expanded(
                child: GestureDetector(
                  onTap: widget.viewOnly ? null : () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? c : Colors.transparent,
                      border: Border.all(
                        color: isCurrent ? c : Colors.grey.shade300,
                        width: isCurrent ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s == 'DRAFT' ? Icons.edit_note
                            : s == 'RELEASED' ? Icons.send
                            : s == 'PARTIALLY_PRODUCED' ? Icons.timelapse
                            : s == 'COMPLETED' ? Icons.check_circle
                            : Icons.lock,
                          size: 16,
                          color: isCurrent ? Colors.white : c,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? Colors.white : c,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSelector() {
    return GestureDetector(
      onTap: widget.viewOnly ? null : _pickSalesOrder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: _salesOrderId != null && _salesOrderId!.isNotEmpty
                ? Colors.teal.shade300 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: _salesOrderId != null && _salesOrderId!.isNotEmpty
              ? Colors.teal.shade50 : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.shopping_cart, size: 16,
                color: _salesOrderId != null && _salesOrderId!.isNotEmpty
                    ? Colors.teal.shade600 : Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _salesOrderNumber != null && _salesOrderNumber!.isNotEmpty
                    ? 'Sales Order: $_salesOrderNumber' : 'Select Sales Order (optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: _salesOrderId != null && _salesOrderId!.isNotEmpty
                      ? Colors.teal.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
            if (!widget.viewOnly)
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (_salesOrderId != null && _salesOrderId!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      _salesOrderId = null; _salesOrderNumber = null;
                      _soItemId = null; _soItemProductName = null;
                      _soItemOptions = [];
                    }),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.search, size: 16, color: Colors.grey.shade600),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSOItemSelector() {
    return DropdownButtonFormField<String>(
      value: _soItemId,
      decoration: InputDecoration(
        labelText: 'SO Line Item',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        prefixIcon: const Icon(Icons.list_alt, size: 18),
        enabled: _salesOrderId != null && _salesOrderId!.isNotEmpty && !widget.viewOnly,
      ),
      style: const TextStyle(fontSize: 12),
      hint: Text(
        _salesOrderId == null || _salesOrderId!.isEmpty
            ? 'Select a Sales Order first' : 'Select line item...',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      items: _soItemOptions.map<DropdownMenuItem<String>>((item) {
        final id = (item['id'] ?? '').toString();
        final lineNo = item['line_no'] ?? 0;
        final prodName = (item['product_name'] ?? item['description'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toStringAsFixed(2) ?? '';
        return DropdownMenuItem<String>(
          value: id,
          child: Text('Line $lineNo: $prodName x$qty', style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: widget.viewOnly ? null : (val) {
        if (val == null) return;
        final item = _soItemOptions.firstWhere(
            (i) => (i['id'] ?? '').toString() == val, orElse: () => {});
        setState(() {
          _soItemId = val;
          _soItemLineNo = item['line_no'] as int?;
          _soItemProductName = (item['product_name'] ?? item['description'] ?? '').toString();
        });
      },
    );
  }

  Widget _buildMaterialSelector() {
    return GestureDetector(
      onTap: widget.viewOnly ? null : _pickMaterial,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: _materialId != null ? Colors.indigo.shade300 : Colors.orange.shade300),
          borderRadius: BorderRadius.circular(6),
          color: _materialId != null ? Colors.indigo.shade50 : Colors.orange.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_2, size: 16,
                color: _materialId != null ? Colors.indigo.shade600 : Colors.orange.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _materialName ?? 'Select Material *',
                style: TextStyle(fontSize: 12,
                    color: _materialId != null ? Colors.indigo.shade800 : Colors.orange.shade800,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (_materialSKU != null && _materialSKU!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(3)),
                child: Text(_materialSKU!,
                    style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.indigo.shade700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBOMSelector() {
    return DropdownButtonFormField<String>(
      value: _bomIdCtrl.text.isNotEmpty ? _bomIdCtrl.text : null,
      decoration: const InputDecoration(
        labelText: 'BOM Version (optional)', isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        prefixIcon: Icon(Icons.account_tree, size: 18),
      ),
      style: const TextStyle(fontSize: 12),
      hint: Text(_bomOptions.isEmpty ? 'Select a material first' : 'Select BOM...',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      items: _bomOptions.map((bom) {
        final version = (bom['bom_version'] ?? '').toString();
        final name = (bom['material_name'] ?? '').toString();
        final id = (bom['bom_id'] ?? '').toString();
        return DropdownMenuItem(value: id, child: Text('$version - $name', style: const TextStyle(fontSize: 12)));
      }).toList(),
      onChanged: widget.viewOnly ? null : (selectedId) {
        if (selectedId == null) return;
        final bom = _bomOptions.cast<Map<String, dynamic>>().firstWhere(
            (b) => (b['bom_id'] ?? '').toString() == selectedId, orElse: () => {});
        setState(() {
          _bomIdCtrl.text = selectedId;
          _bomVersionCtrl.text = (bom['bom_version'] ?? '').toString();
        });
      },
    );
  }

  // ── Tab 2: Routing ──
  Widget _buildRoutingTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.route, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Routing Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_orderId != null)
                IconButton(
                  icon: _routingLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh Routing',
                  onPressed: _routingLoading ? null : _loadRoutingInfo,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _routingLoading
              ? const Center(child: CircularProgressIndicator())
              : _routingInfo == null || _routingInfo!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('No routing template assigned',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Assign a BOM with routing template to see routing info',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: _buildRoutingInfo(),
                    ),
        ),
      ],
    );
  }

  Widget _buildRoutingInfo() {
    if (_routingInfo == null) return const SizedBox.shrink();
    final rtName = (_routingInfo!['template_name'] ?? _routingInfo!['name'] ?? 'N/A').toString();
    final rtDesc = (_routingInfo!['description'] ?? '').toString();
    final rtStatus = (_routingInfo!['status'] ?? 'ACTIVE').toString();
    final operations = (_routingInfo!['operations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text('Routing: $rtName',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rtStatus == 'ACTIVE' ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(rtStatus,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: rtStatus == 'ACTIVE' ? Colors.green.shade900 : Colors.orange.shade900)),
                ),
              ],
            ),
            if (rtDesc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(rtDesc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            if (operations.isNotEmpty) ...[
              const Text('Operations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 40,
                  headingRowColor: WidgetStateColor.resolveWith((_) => Colors.grey.shade200),
                  columns: const [
                    DataColumn(label: Text('No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Operation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Work Center', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Setup (min)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Run (min)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                  rows: operations.map<DataRow>((op) => DataRow(cells: [
                    DataCell(Text((op['operation_no'] ?? '').toString(), style: const TextStyle(fontSize: 11))),
                    DataCell(Text((op['operation_name'] ?? '').toString(), style: const TextStyle(fontSize: 11))),
                    DataCell(Text((op['work_center_name'] ?? op['work_center_id'] ?? '').toString(),
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text((op['setup_time_min'] as num?)?.toStringAsFixed(1) ?? '0',
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Text((op['run_time_min'] as num?)?.toStringAsFixed(1) ?? '0',
                        style: const TextStyle(fontSize: 11))),
                  ])).toList(),
                ),
              ),
            ] else
              Text('No operations defined', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ── Tab 3: Materials ──
  Widget _buildMaterialsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.category, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Material Requirements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_orderId != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Sync', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _materialsLoading ? null : _syncMaterials,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_bomIdCtrl.text.isEmpty && _materials.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Select a BOM to see material requirements',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (_materialsLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_materials.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No materials found. Tap Sync to generate from BOM.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                // Header row
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 32, child: Text('Pos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      const Expanded(flex: 3, child: Text('Component', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 70, child: Text('Req Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      const SizedBox(width: 90, child: Text('Issue Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 36),
                      const SizedBox(width: 40, child: Text('UOM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _materials.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = _materials[i] as Map<String, dynamic>;
                      return _MaterialIssueRow(
                        material: m,
                        productionService: widget.productionService,
                        onSaved: () => _loadMaterials(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// _MaterialIssueRow — editable issue qty row
// ════════════════════════════════════════════════════════════
class _MaterialIssueRow extends StatefulWidget {
  final Map<String, dynamic> material;
  final ProductionService productionService;
  final VoidCallback onSaved;
  const _MaterialIssueRow({required this.material, required this.productionService, required this.onSaved});
  @override
  State<_MaterialIssueRow> createState() => _MaterialIssueRowState();
}

class _MaterialIssueRowState extends State<_MaterialIssueRow> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final issueQty = (widget.material['issue_qty'] as num?)?.toDouble() ?? 0.0;
    _ctrl = TextEditingController(text: issueQty.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final qty = double.tryParse(_ctrl.text) ?? 0.0;
    final id = widget.material['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.productionService.updatePOMaterialIssueQty(id, qty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue qty updated'), backgroundColor: Colors.green));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final pos = (m['item_position'] ?? 0).toString();
    final compName = (m['component_name'] ?? '').toString();
    final compSku = (m['component_sku'] ?? '').toString();
    final reqQty = (m['required_qty'] as num?)?.toStringAsFixed(2) ?? '0';
    final uom = (m['unit_of_measure'] ?? 'EA').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Text(pos, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(compName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (compSku.isNotEmpty)
                  Text(compSku, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(reqQty, style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Save issue qty',
                    onPressed: _save,
                  ),
          ),
          SizedBox(
            width: 40,
            child: Text(uom, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// _ProductSelector Dialog
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
    _filtered = widget.products.take(50).map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); _debounceTimer?.cancel(); super.dispose(); }

  void _onSearchChanged(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () => _filter(q));
  }

  void _filter(String q) {
    if (!mounted) return;
    final query = q.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.products.take(50).map((p) => Map<String, dynamic>.from(p as Map)).toList();
      } else {
        _filtered = widget.products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final sku = (p['sku'] ?? '').toString().toLowerCase();
          return name.contains(query) || sku.contains(query);
        }).take(50).map((p) => Map<String, dynamic>.from(p as Map)).toList();
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
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(child: Text('Select Material', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _onSearchChanged,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('No products found', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.inventory_2, size: 18, color: Colors.indigo.shade400),
                        ),
                        title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('SKU: ${p['sku'] ?? ''}  |  UOM: ${p['unit_of_measure'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
// _SalesOrderPickerDialog
// ════════════════════════════════════════════════════════════
class _SalesOrderPickerDialog extends StatefulWidget {
  final List<dynamic> orders;
  const _SalesOrderPickerDialog({required this.orders});
  @override
  State<_SalesOrderPickerDialog> createState() => _SalesOrderPickerDialogState();
}

class _SalesOrderPickerDialogState extends State<_SalesOrderPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filtered = widget.orders.take(50).map((o) => Map<String, dynamic>.from(o as Map)).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _filter(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = q.toLowerCase().trim();
      setState(() {
        if (query.isEmpty) {
          _filtered = widget.orders.take(50).map((o) => Map<String, dynamic>.from(o as Map)).toList();
        } else {
          _filtered = widget.orders.where((o) {
            final soNum = (o['so_number'] ?? '').toString().toLowerCase();
            final cust = (o['customer_name'] ?? '').toString().toLowerCase();
            return soNum.contains(query) || cust.contains(query);
          }).take(50).map((o) => Map<String, dynamic>.from(o as Map)).toList();
        }
      });
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
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, size: 20, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                const Expanded(child: Text('Select Sales Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by SO# or customer...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: _filter,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('No sales orders found', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final o = _filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.shopping_cart, size: 18, color: Colors.teal.shade400),
                        ),
                        title: Text(o['so_number'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('Customer: ${o['customer_name'] ?? o['customer_id'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        trailing: o['status'] != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text(o['status'].toString(),
                                    style: TextStyle(fontSize: 9, color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
                              )
                            : null,
                        onTap: () => Navigator.pop(context, o),
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
// _DateField
// ════════════════════════════════════════════════════════════
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;
  final bool readOnly;

  const _DateField({required this.label, required this.date, required this.onSelected, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final fmt = AppDateFormatter();
    final displayText = fmt.formatSync(date);
    return InkWell(
      onTap: readOnly ? null : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label, isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: Icon(Icons.calendar_today, size: 14, color: readOnly ? Colors.grey.shade400 : null),
        ),
        child: Text(
          displayText.isEmpty ? 'Select date' : displayText,
          style: TextStyle(fontSize: 12, color: displayText.isEmpty ? Colors.grey : null),
        ),
      ),
    );
  }
}
