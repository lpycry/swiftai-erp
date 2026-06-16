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
    : orderId = json['order_id']?.toString(),
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

  Map<String, dynamic> toJson() => {
    if (orderId != null) 'order_id': orderId,
    'order_number': orderNumber,
    if (materialId != null) 'material_id': materialId,
    'material_name': materialName,
    'order_qty': orderQty,
    'status': status,
    'priority': priority,
    if (plannedStartDate != null) 'planned_start_date': plannedStartDate!.toIso8601String(),
    if (plannedEndDate != null) 'planned_end_date': plannedEndDate!.toIso8601String(),
    'notes': notes,
  };
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
        content: Text(
          'Delete production order ${e['order_number'] ?? ''} ?',
        ),
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
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () => _openDetail(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No production orders yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
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
      case 'COMPLETED':
        statusColor = Colors.green;
        break;
      case 'IN_PROCESS':
        statusColor = Colors.blue;
        break;
      case 'RELEASED':
        statusColor = Colors.orange;
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    Color priorityColor;
    switch (priority) {
      case 'URGENT':
        priorityColor = Colors.red;
        break;
      case 'HIGH':
        priorityColor = Colors.orange;
        break;
      case 'LOW':
        priorityColor = Colors.grey;
        break;
      default:
        priorityColor = Colors.blue;
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
            // Top row: order number and status
            Row(
              children: [
                Icon(
                  Icons.assignment,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  e['order_number'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Material info
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  e['material_name'] ?? 'N/A',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'Qty: ${(e['order_qty'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Dates
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 11,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 3),
                Text(
                  startDateStr.isEmpty ? 'TBD' : startDateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 3),
                Text(
                  endDateStr.isEmpty ? 'TBD' : endDateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openDetail(entry: e, viewOnly: true),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openDetail(entry: e),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppTheme.errorColor,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _deleteOrder(e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
  State<ProductionOrderDetailScreen> createState() =>
      _ProductionOrderDetailScreenState();
}

class _ProductionOrderDetailScreenState
    extends State<ProductionOrderDetailScreen> {
  // Header fields
  final _orderNumberCtrl = TextEditingController();
  final _orderQtyCtrl = TextEditingController(text: '1.00');
  final _notesCtrl = TextEditingController();
  final _bomIdCtrl = TextEditingController();
  final _bomVersionCtrl = TextEditingController();
  String? _materialId, _materialName, _materialSKU;
  String _status = 'DRAFT';
  String _priority = 'MEDIUM';
  DateTime? _plannedStartDate, _plannedEndDate;
  bool _saving = false;

  bool get _isEdit => widget.entry != null;
  String? get _orderId =>
      widget.entry?['order_id']?.toString() ??
      widget.entry?['id']?.toString();

  // BOM list for the selected material
  List<dynamic> _bomOptions = [];

  @override
  void initState() {
    super.initState();
    _populate();
    if (_isEdit && !widget.viewOnly) _fetchDetail();
    if (_isEdit) _loadBOMOptions();
  }

  Future<void> _fetchDetail() async {
    try {
      final d = await widget.productionService.getProductionOrder(_orderId!);
      if (!mounted) return;
      _populateFromDetail(d);
    } catch (_) {}
  }

  void _populateFromDetail(Map<String, dynamic> d) {
    setState(() {
      _materialId = d['material_id']?.toString();
      _materialName = d['material_name'] ?? '';
      _materialSKU = d['material_sku'] ?? '';
      _orderNumberCtrl.text = d['order_number'] ?? '';
      _orderQtyCtrl.text =
          (d['order_qty'] as num?)?.toStringAsFixed(2) ?? '1.00';
      _status = d['status'] ?? 'DRAFT';
      _priority = d['priority'] ?? 'MEDIUM';
      _plannedStartDate = d['planned_start_date'] is String
          ? DateTime.tryParse(d['planned_start_date'])
          : null;
      _plannedEndDate = d['planned_end_date'] is String
          ? DateTime.tryParse(d['planned_end_date'])
          : null;
      _notesCtrl.text = d['notes'] ?? '';
      _bomIdCtrl.text = d['bom_id']?.toString() ?? '';
      _bomVersionCtrl.text = d['bom_version']?.toString() ?? '';
    });
  }

  void _populate() {
    final e = widget.entry;
    if (e == null) return;
    _materialId = e['material_id']?.toString();
    _materialName = e['material_name'] ?? '';
    _materialSKU = e['material_sku'] ?? '';
    _orderNumberCtrl.text = e['order_number'] ?? '';
    _orderQtyCtrl.text =
        (e['order_qty'] as num?)?.toStringAsFixed(2) ?? '1.00';
    _status = e['status'] ?? 'DRAFT';
    _priority = e['priority'] ?? 'MEDIUM';
    _plannedStartDate = e['planned_start_date'] is String
        ? DateTime.tryParse(e['planned_start_date'])
        : null;
    _plannedEndDate = e['planned_end_date'] is String
        ? DateTime.tryParse(e['planned_end_date'])
        : null;
    _notesCtrl.text = e['notes'] ?? '';
    _bomIdCtrl.text = e['bom_id']?.toString() ?? '';
    _bomVersionCtrl.text = e['bom_version']?.toString() ?? '';
  }

  Future<void> _loadBOMOptions() async {
    if (_materialId == null) return;
    try {
      final boms = await widget.productionService.listBOMs(
        materialId: _materialId,
      );
      if (mounted) setState(() => _bomOptions = boms);
    } catch (_) {}
  }

  @override
  void dispose() {
    _orderNumberCtrl.dispose();
    _orderQtyCtrl.dispose();
    _notesCtrl.dispose();
    _bomIdCtrl.dispose();
    _bomVersionCtrl.dispose();
    super.dispose();
  }

  // ── Save ──
  Future<void> _save() async {
    if (_materialId == null) {
      _showMsg('Select a material');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'material_id': _materialId,
        'material_name': _materialName,
        'order_qty': double.tryParse(_orderQtyCtrl.text) ?? 1,
        'priority': _priority,
        'status': _status,
        if (_plannedStartDate != null)
          'planned_start_date': _plannedStartDate!.toIso8601String(),
        if (_plannedEndDate != null)
          'planned_end_date': _plannedEndDate!.toIso8601String(),
        'notes': _notesCtrl.text.trim(),
      };
      // Include BOM reference if a BOM is selected
      if (_bomIdCtrl.text.isNotEmpty && _bomVersionCtrl.text.isNotEmpty) {
        data['bom_id'] = _bomIdCtrl.text;
        data['bom_version'] = _bomVersionCtrl.text;
      }
      if (_isEdit && !widget.viewOnly) {
        await widget.productionService.updateProductionOrder(_orderId!, data);
      } else {
        await widget.productionService.createProductionOrder(data);
      }
      widget.onSaved();
      if (mounted) {
        _showMsg('Production order saved');
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

  // ── Status color helper ──
  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROCESS':
        return Colors.blue;
      case 'RELEASED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Order: ${widget.entry!['order_number'] ?? ''}'
              : 'New Production Order',
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
                    title: const Text('Delete Production Order'),
                    content: const Text(
                      'Delete this production order?',
                    ),
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
                    await widget.productionService.deleteProductionOrder(
                      _orderId!,
                    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Order Number (read-only) ──
            TextField(
              controller: _orderNumberCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Order Number (auto-generated)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                prefixIcon: Icon(Icons.tag, size: 18),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),

            // ── Material Selector ──
            _buildMaterialSelector(),
            const SizedBox(height: 12),

            // ── BOM Selector ──
            _buildBOMSelector(),
            const SizedBox(height: 12),

            // ── Order Qty ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _orderQtyCtrl,
                    readOnly: widget.viewOnly,
                    decoration: const InputDecoration(
                      labelText: 'Order Qty',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      prefixIcon: Icon(Icons.view_agenda, size: 18),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                // ── Priority Dropdown ──
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    items: const [
                      DropdownMenuItem(
                        value: 'LOW',
                        child: Text('LOW', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'MEDIUM',
                        child: Text('MEDIUM', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'HIGH',
                        child: Text('HIGH', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'URGENT',
                        child: Text('URGENT', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: widget.viewOnly ? null : (v) => setState(() => _priority = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Status Display ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _statusColor(_status).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(6),
                color: _statusColor(_status).withOpacity(0.08),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _statusColor(_status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: $_status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(_status),
                    ),
                  ),
                  const Spacer(),
                  // Status change dropdown (only when editing)
                  if (_isEdit && !widget.viewOnly)
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(_status),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'DRAFT',
                            child: Text(
                              'DRAFT',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'RELEASED',
                            child: Text(
                              'RELEASED',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'IN_PROCESS',
                            child: Text(
                              'IN_PROCESS',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'COMPLETED',
                            child: Text(
                              'COMPLETED',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CANCELLED',
                            child: Text(
                              'CANCELLED',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Planned Start / End Dates ──
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Planned Start Date',
                    date: _plannedStartDate,
                    onSelected: (d) => setState(() => _plannedStartDate = d),
                    readOnly: widget.viewOnly,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateField(
                    label: 'Planned End Date',
                    date: _plannedEndDate,
                    onSelected: (d) => setState(() => _plannedEndDate = d),
                    readOnly: widget.viewOnly,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Notes ──
            TextField(
              controller: _notesCtrl,
              readOnly: widget.viewOnly,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.notes, size: 18),
                ),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),

            // ── Save Button ──
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
                  _saving
                      ? 'Saving...'
                      : _isEdit
                          ? 'Update Order'
                          : 'Create Order',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed:
                    (_saving || widget.viewOnly) ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Material Selector ──
  Widget _buildMaterialSelector() {
    return GestureDetector(
      onTap: widget.viewOnly ? null : _pickMaterial,
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

  // ── BOM Selector ──
  Widget _buildBOMSelector() {
    return DropdownButtonFormField<String>(
      value: _bomIdCtrl.text.isNotEmpty ? _bomIdCtrl.text : null,
      decoration: const InputDecoration(
        labelText: 'BOM Version (optional)',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        prefixIcon: Icon(Icons.account_tree, size: 18),
      ),
      style: const TextStyle(fontSize: 12),
      hint: Text(
        _bomOptions.isEmpty ? 'Select a material first' : 'Select BOM...',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      items: _bomOptions.map((bom) {
        final version = (bom['bom_version'] ?? '').toString();
        final name = (bom['material_name'] ?? '').toString();
        final id = (bom['bom_id'] ?? '').toString();
        return DropdownMenuItem(
          value: id,
          child: Text(
            '$version - $name',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
      onChanged: widget.viewOnly
          ? null
          : (selectedId) {
              if (selectedId == null) return;
              final bom = _bomOptions.cast<Map<String, dynamic>>().firstWhere(
                    (b) => (b['bom_id'] ?? '').toString() == selectedId,
                    orElse: () => {},
                  );
              setState(() {
                _bomIdCtrl.text = selectedId;
                _bomVersionCtrl.text = (bom['bom_version'] ?? '').toString();
              });
            },
    );
  }
}

// ════════════════════════════════════════════════════════════
// Product Selector Dialog (reused from bom_screen.dart pattern)
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
                      style: TextStyle(color: Colors.grey.shade600),
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
                            color: Colors.grey.shade600,
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
// _DateField — tappable date display that opens a DatePicker
// ════════════════════════════════════════════════════════════
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;
  final bool readOnly;

  const _DateField({
    required this.label,
    required this.date,
    required this.onSelected,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = AppDateFormatter();
    final displayText = fmt.formatSync(date);

    return InkWell(
      onTap: readOnly
          ? null
          : () async {
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
          suffixIcon: Icon(
            Icons.calendar_today,
            size: 14,
            color: readOnly ? Colors.grey.shade400 : null,
          ),
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
