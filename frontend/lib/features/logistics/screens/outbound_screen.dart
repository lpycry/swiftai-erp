import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class OutboundScreen extends StatefulWidget {
  final AuthService authService;
  final WarehouseService warehouseService;
  const OutboundScreen({
    super.key,
    required this.authService,
    required this.warehouseService,
  });
  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  List<dynamic> _orders = [], _products = [], _warehouses = [];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await widget.warehouseService.listOutbound();
      final p = await widget.warehouseService.listProducts();
      final w = await widget.warehouseService.listWarehouses();
      if (mounted)
        setState(() {
          _orders = o;
          _products = p;
          _warehouses = w;
        });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 2,
      onIndexChanged: (_) {},
      title: 'Outbound',
      body: Column(
        children: [
          TabBar(
            controller: _tc,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.accentBlue,
            tabs: const [
              Tab(text: 'Order'),
              Tab(text: 'GI History'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                _OBForm(
                  authService: widget.authService,
                  products: _products,
                  warehouses: _warehouses,
                  svc: widget.warehouseService,
                  onDone: _load,
                ),
                _GIHistoryList(
                  orders: _orders,
                  products: _products,
                  warehouses: _warehouses,
                  svc: widget.warehouseService,
                  onChanged: _load,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OBForm extends StatefulWidget {
  final AuthService authService;
  final List<dynamic> products, warehouses;
  final WarehouseService svc;
  final VoidCallback onDone;
  const _OBForm({
    required this.authService,
    required this.products,
    required this.warehouses,
    required this.svc,
    required this.onDone,
  });
  @override
  State<_OBForm> createState() => _OBFormState();
}

class _OBFormState extends State<_OBForm> {
  final _refCtrl = TextEditingController(),
      _custCtrl = TextEditingController(),
      _qtyCtrl = TextEditingController();
  String? _whId, _prodId;
  bool _loading = false;
  String _orderType = 'sales_order';
  List<Map<String, dynamic>> _workOrders = [];
  List<Map<String, dynamic>> _issueLines = [];
  Map<String, dynamic>? _selectedWorkOrder;

  static const _orderTypes = <Map<String, String>>[
    {'value': 'sales_order', 'label': 'Sales Order'},
    {'value': 'work_order', 'label': 'Work Order'},
    {'value': 'transfer', 'label': 'Transfer'},
    {'value': 'return', 'label': 'Return'},
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkOrders();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _custCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.authService.accessToken ?? ''}',
  };

  Future<void> _loadWorkOrders() async {
    try {
      final responses = await Future.wait(
        ['RELEASED', 'PARTIALLY_PRODUCED'].map(
          (status) => http.get(
            Uri.parse(
              'http://localhost:8080/api/v1/production/orders?status=$status',
            ),
            headers: _headers,
          ),
        ),
      );
      final byID = <String, Map<String, dynamic>>{};
      for (final resp in responses) {
        if (resp.statusCode >= 400) continue;
        final list = ((jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        for (final order in list) {
          if (_remaining(order) > 0)
            byID[order['id']?.toString() ?? ''] = order;
        }
      }
      if (mounted) setState(() => _workOrders = byID.values.toList());
    } catch (_) {}
  }

  double _remaining(Map<String, dynamic> order) {
    final orderQty = (order['order_qty'] as num?)?.toDouble() ?? 0;
    final completedQty = (order['completed_qty'] as num?)?.toDouble() ?? 0;
    final rem = orderQty - completedQty;
    return rem > 0 ? rem : 0;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _selectWorkOrder(String? id) async {
    final wo = _workOrders.cast<Map<String, dynamic>?>().firstWhere(
      (o) => o?['id']?.toString() == id,
      orElse: () => null,
    );
    if (wo == null) {
      setState(() {
        _selectedWorkOrder = null;
        _issueLines = [];
        _refCtrl.clear();
      });
      return;
    }
    setState(() => _loading = true);
    Map<String, dynamic> detail = wo;
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/production/orders/$id'),
        headers: _headers,
      );
      if (resp.statusCode < 400) {
        detail = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      }
      final materials = ((detail['materials'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      final allBins = (await widget.svc.listBins())
          .cast<Map<String, dynamic>>();
      final lines = <Map<String, dynamic>>[];
      for (final m in materials) {
        final requiredQty = (m['required_qty'] as num?)?.toDouble() ?? 0;
        final issuedQty = (m['issue_qty'] as num?)?.toDouble() ?? 0;
        final qtyToIssue = requiredQty - issuedQty;
        if (qtyToIssue <= 0) continue;
        final stock = await widget.svc.listStock(
          productId: m['component_id']?.toString(),
        );
        final stockOptions = stock.cast<Map<String, dynamic>>();
        final available = stockOptions.cast<Map<String, dynamic>?>().firstWhere(
          (s) => (((s?['quantity_on_hand'] as num?)?.toDouble() ?? 0) > 0),
          orElse: () => null,
        );
        final firstWarehouse = available?['warehouse_id'] != null
            ? null
            : widget.warehouses.cast<Map<String, dynamic>?>().firstWhere(
                (w) => w?['id'] != null,
                orElse: () => null,
              );
        final selectedWarehouseId =
            available?['warehouse_id'] ?? firstWarehouse?['id'];
        final selectedBin = available?['bin_id'] != null
            ? null
            : allBins.cast<Map<String, dynamic>?>().firstWhere(
                (b) =>
                    selectedWarehouseId != null &&
                    b?['warehouse_id']?.toString() ==
                        selectedWarehouseId.toString(),
                orElse: () => null,
              );
        lines.add({
          'product_id': m['component_id'],
          'sku': m['component_sku'] ?? '',
          'name': m['component_name'] ?? '',
          'required_qty': requiredQty,
          'issued_qty': issuedQty,
          'qty_to_issue': qtyToIssue,
          'stock_options': stockOptions,
          'all_bins': allBins,
          'warehouse_id': selectedWarehouseId,
          'warehouse_name':
              available?['warehouse_name'] ??
              available?['warehouse_code'] ??
              firstWarehouse?['name'] ??
              firstWarehouse?['code'] ??
              '',
          'bin_id': available?['bin_id'] ?? selectedBin?['id'],
          'bin_code':
              available?['bin_code'] ??
              selectedBin?['code'] ??
              selectedBin?['bin_code'] ??
              '',
          'on_hand': (available?['quantity_on_hand'] as num?)?.toDouble() ?? 0,
        });
      }
      detail = {...detail, 'materials': materials};
      setState(() {
        _selectedWorkOrder = detail;
        _issueLines = lines;
        _prodId = lines.isNotEmpty
            ? lines.first['product_id']?.toString()
            : null;
        _refCtrl.text = detail['order_number']?.toString() ?? '';
        _qtyCtrl.clear();
      });
    } catch (e) {
      _err(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeOrderType(String value) {
    setState(() {
      _orderType = value;
      _selectedWorkOrder = null;
      _issueLines = [];
      _prodId = null;
      _refCtrl.clear();
      _qtyCtrl.clear();
    });
  }

  void _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _submit() async {
    if (_orderType == 'work_order' && _selectedWorkOrder == null) {
      _err('Select Work Order');
      return;
    }
    if (_orderType == 'work_order') {
      if (_issueLines.isEmpty) {
        _err('No BOM items available to issue.');
        return;
      }
      if (_issueLines.any((l) => l['warehouse_id'] == null)) {
        _err('Some BOM items have no available warehouse stock.');
        return;
      }
      if (_issueLines.any(
        (l) =>
            ((l['on_hand'] as num?)?.toDouble() ?? 0) <
            ((l['qty_to_issue'] as num?)?.toDouble() ?? 0),
      )) {
        _err(
          'Some BOM items do not have enough stock at the selected location.',
        );
        return;
      }
    } else if (_whId == null || _prodId == null) {
      _err('Select product and warehouse');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text);
    if (_orderType != 'work_order') {
      if (qty == null || qty <= 0) {
        _err('Enter valid quantity');
        return;
      }
    }
    setState(() => _loading = true);
    try {
      await widget.svc.createOutbound({
        'order_type': _orderType,
        'reference_no': _refCtrl.text.trim(),
        if (_orderType != 'work_order') 'warehouse_id': _whId,
        'customer_name': _custCtrl.text.trim(),
        'lines': _orderType == 'work_order'
            ? _issueLines
                  .map(
                    (l) => {
                      'product_id': l['product_id'],
                      'warehouse_id': l['warehouse_id'],
                      if (l['bin_id'] != null) 'bin_id': l['bin_id'],
                      'ordered_qty': l['qty_to_issue'],
                    },
                  )
                  .toList()
            : [
                {'product_id': _prodId, 'ordered_qty': qty},
              ],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDone();
        setState(() {
          _qtyCtrl.clear();
          _refCtrl.clear();
          _custCtrl.clear();
          _issueLines = [];
          _selectedWorkOrder = null;
        });
      }
    } catch (e) {
      if (mounted) _err('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _warehouseOptions(Map<String, dynamic> line) {
    final stock = ((line['stock_options'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
    final byWarehouse = <String, Map<String, dynamic>>{};
    for (final w in widget.warehouses.cast<Map<String, dynamic>>()) {
      final id = w['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byWarehouse[id] = {
        'warehouse_id': id,
        'warehouse_name': w['name'] ?? w['code'] ?? w['warehouse_code'] ?? id,
        'on_hand': 0.0,
      };
    }
    for (final s in stock) {
      final id = s['warehouse_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final qty = (s['quantity_on_hand'] as num?)?.toDouble() ?? 0;
      final existing = byWarehouse[id];
      if (existing == null) {
        byWarehouse[id] = {
          'warehouse_id': id,
          'warehouse_name':
              s['warehouse_name'] ?? s['warehouse_code'] ?? 'Warehouse',
          'on_hand': qty,
        };
      } else {
        existing['on_hand'] =
            ((existing['on_hand'] as num?)?.toDouble() ?? 0) + qty;
        if ((existing['warehouse_name'] ?? '').toString().isEmpty) {
          existing['warehouse_name'] =
              s['warehouse_name'] ?? s['warehouse_code'] ?? 'Warehouse';
        }
      }
    }
    return byWarehouse.values.toList();
  }

  List<Map<String, dynamic>> _binOptions(Map<String, dynamic> line) {
    final warehouseId = line['warehouse_id']?.toString();
    if (warehouseId == null || warehouseId.isEmpty) return [];
    final stock = ((line['stock_options'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['warehouse_id']?.toString() == warehouseId);
    final byBin = <String, Map<String, dynamic>>{};
    final allBins = ((line['all_bins'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((b) => b['warehouse_id']?.toString() == warehouseId);
    for (final b in allBins) {
      final binId = b['id']?.toString() ?? '';
      if (binId.isEmpty) continue;
      byBin[binId] = {
        'bin_id': binId,
        'bin_code': b['code'] ?? b['bin_code'] ?? b['name'] ?? 'Bin',
        'on_hand': 0.0,
      };
    }
    for (final s in stock) {
      final binId = s['bin_id']?.toString() ?? '';
      final qty = (s['quantity_on_hand'] as num?)?.toDouble() ?? 0;
      final existing = byBin[binId];
      if (existing == null) {
        byBin[binId] = {
          'bin_id': binId,
          'bin_code': (s['bin_code'] ?? '').toString().isEmpty
              ? 'No Bin'
              : s['bin_code'],
          'on_hand': qty,
        };
      } else {
        existing['on_hand'] =
            ((existing['on_hand'] as num?)?.toDouble() ?? 0) + qty;
        if ((existing['bin_code'] ?? '').toString().isEmpty) {
          existing['bin_code'] = (s['bin_code'] ?? '').toString().isEmpty
              ? 'No Bin'
              : s['bin_code'];
        }
      }
    }
    if (byBin.isEmpty) {
      byBin[''] = {'bin_id': '', 'bin_code': 'No Bin', 'on_hand': 0.0};
    }
    return byBin.values.toList();
  }

  void _setIssueWarehouse(Map<String, dynamic> line, String? warehouseId) {
    if (warehouseId == null) return;
    final wh = _warehouseOptions(line).firstWhere(
      (w) => w['warehouse_id']?.toString() == warehouseId,
      orElse: () => {},
    );
    final bins = _binOptions({...line, 'warehouse_id': warehouseId});
    final firstBin = bins.isNotEmpty ? bins.first : null;
    setState(() {
      line['warehouse_id'] = warehouseId;
      line['warehouse_name'] = wh['warehouse_name'] ?? '';
      line['bin_id'] = firstBin == null || firstBin['bin_id'] == ''
          ? null
          : firstBin['bin_id'];
      line['bin_code'] = firstBin?['bin_code'] ?? '';
      line['on_hand'] = firstBin?['on_hand'] ?? wh['on_hand'] ?? 0;
    });
  }

  void _setIssueBin(Map<String, dynamic> line, String? binId) {
    if (binId == null) return;
    final bin = _binOptions(
      line,
    ).firstWhere((b) => b['bin_id']?.toString() == binId, orElse: () => {});
    setState(() {
      line['bin_id'] = binId.isEmpty ? null : binId;
      line['bin_code'] = bin['bin_code'] ?? '';
      line['on_hand'] = bin['on_hand'] ?? 0;
    });
  }

  Widget _buildWorkOrderIssueTable() {
    if (_selectedWorkOrder == null) {
      return Text(
        'Select Work Order first',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }
    if (_issueLines.isEmpty) {
      return Text(
        'No open BOM items to issue.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Material',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Warehouse',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Bin Location',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Issue Qty',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    'On Hand',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          ..._issueLines.map((line) {
            final warehouseOptions = _warehouseOptions(line);
            final selectedWarehouse = line['warehouse_id']?.toString();
            final warehouseValue =
                warehouseOptions.any(
                  (w) => w['warehouse_id']?.toString() == selectedWarehouse,
                )
                ? selectedWarehouse
                : null;
            final binOptions = _binOptions(line);
            final selectedBin = line['bin_id']?.toString() ?? '';
            final binValue =
                binOptions.any((b) => b['bin_id']?.toString() == selectedBin)
                ? selectedBin
                : null;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${line['sku'] ?? ''} ${line['name'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: warehouseValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      items: warehouseOptions
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['warehouse_id']?.toString(),
                              child: Text(
                                '${w['warehouse_name'] ?? ''} (${_fmt((w['on_hand'] as num?)?.toDouble() ?? 0)})',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _setIssueWarehouse(line, v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: binValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      items: binOptions
                          .map(
                            (b) => DropdownMenuItem(
                              value: b['bin_id']?.toString() ?? '',
                              child: Text(
                                '${b['bin_code'] ?? 'No Bin'} (${_fmt((b['on_hand'] as num?)?.toDouble() ?? 0)})',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _setIssueBin(line, v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fmt((line['qty_to_issue'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _fmt((line['on_hand'] as num?)?.toDouble() ?? 0),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            ((line['on_hand'] as num?)?.toDouble() ?? 0) <
                                ((line['qty_to_issue'] as num?)?.toDouble() ??
                                    0)
                            ? Colors.red
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'New Outbound Order',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Order Type',
                  isDense: true,
                ),
                initialValue: _orderType,
                items: _orderTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['value'],
                        child: Text(
                          t['label']!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) _changeOrderType(v);
                },
              ),
              const SizedBox(height: 12),
              if (_orderType != 'work_order' && widget.warehouses.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Warehouse *',
                    isDense: true,
                  ),
                  items: widget.warehouses
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id']?.toString(),
                          child: Text(
                            '${w['code']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _whId = v),
                ),
              const SizedBox(height: 12),
              if (_orderType == 'work_order') ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Work Order *',
                    isDense: true,
                  ),
                  value: _selectedWorkOrder?['id']?.toString(),
                  isExpanded: true,
                  items: _workOrders
                      .map(
                        (wo) => DropdownMenuItem(
                          value: wo['id']?.toString(),
                          child: Text(
                            '${wo['order_number'] ?? ''} | ${wo['material_sku'] ?? ''} ${wo['material_name'] ?? ''} | Remaining ${_fmt(_remaining(wo))}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _selectWorkOrder,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _refCtrl,
                readOnly: _orderType == 'work_order',
                decoration: InputDecoration(
                  labelText: _orderType == 'work_order'
                      ? 'Reference (Work Order)'
                      : 'Reference (SO#)',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _custCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const Divider(height: 20),
              const Text(
                'Item',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_orderType == 'work_order')
                _buildWorkOrderIssueTable()
              else if (widget.products.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    isDense: true,
                  ),
                  items: widget.products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['id']?.toString(),
                          child: Text(
                            '${p['sku']} - ${p['name']}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _prodId = v),
                ),
              if (_orderType != 'work_order') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shopping_cart, size: 18),
                  label: Text(_loading ? 'Creating...' : 'Create Order'),
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OBList extends StatelessWidget {
  final List<dynamic> orders;
  final WarehouseService svc;
  final VoidCallback onChanged;
  const _OBList({
    required this.orders,
    required this.svc,
    required this.onChanged,
  });

  Color _stColor(String s) {
    switch (s) {
      case 'draft':
        return Colors.grey;
      case 'picking':
        return Colors.blue;
      case 'packed':
        return Colors.purple;
      case 'issued':
      case 'shipped':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text('No orders', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (_, i) => _buildCard(context, orders[i]),
    );
  }

  Widget _buildCard(BuildContext context, dynamic o) {
    final orderNo = o['order_no'] ?? o['id']?.toString().substring(0, 8) ?? '';
    final ref = o['reference_no'] ?? '';
    final cust = o['customer_name'] ?? '';
    final status = o['status'] ?? 'draft';
    final lines = (o['lines'] as List<dynamic>?) ?? [];
    final qty = lines.fold<double>(
      0,
      (s, l) => s + ((l['ordered_qty'] as num?)?.toDouble() ?? 0),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_upward,
            color: Colors.orange.shade700,
            size: 20,
          ),
        ),
        title: Text(
          'OB-$orderNo',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          '$cust • $ref • Qty: ${qty.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          maxLines: 1,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _stColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _stColor(status),
            ),
          ),
        ),
      ),
    );
  }
}

class _GIHistoryList extends StatelessWidget {
  final List<dynamic> orders;
  final List<dynamic> products;
  final List<dynamic> warehouses;
  final WarehouseService svc;
  final VoidCallback onChanged;
  const _GIHistoryList({
    required this.orders,
    required this.products,
    required this.warehouses,
    required this.svc,
    required this.onChanged,
  });

  Color _stColor(String s) {
    switch (s) {
      case 'draft':
        return Colors.grey;
      case 'picking':
        return Colors.blue;
      case 'packed':
        return Colors.purple;
      case 'issued':
      case 'shipped':
        return Colors.green;
      case 'reversed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _fmt(num v) => v.toDouble() == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2);

  String _dt(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return '-';
    try {
      final dt = DateTime.parse(text).toLocal();
      return '${Fmt.d(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return Fmt.dateTimeStr(text);
    }
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _postGI(BuildContext context, Map<String, dynamic> order) async {
    try {
      await svc.shipOutbound(order['id'].toString());
      _snack(context, 'Goods Issue posted.', Colors.green);
      onChanged();
    } catch (e) {
      _snack(context, e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  Future<void> _reverse(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverse Goods Issue'),
        content: Text(
          'Reverse ${order['order_no'] ?? ''}? This will restore stock and reverse the journal entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await svc.reverseOutbound(order['id'].toString());
      _snack(context, 'Goods Issue reversed.', Colors.green);
      onChanged();
    } catch (e) {
      _snack(context, e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  void _view(BuildContext context, Map<String, dynamic> order) {
    final lines = (order['lines'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('GI ${order['order_no'] ?? ''}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Type: ${order['order_type'] ?? '-'}'),
                Text('Reference: ${order['reference_no'] ?? '-'}'),
                Text(
                  'Warehouse: ${order['warehouse_name'] ?? order['warehouse_id'] ?? '-'}',
                ),
                Text('Status: ${order['status'] ?? '-'}'),
                Text('Created: ${_dt(order['created_at'])}'),
                Text('Issued: ${_dt(order['shipped_at'])}'),
                const Divider(),
                ...lines.map(
                  (l) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${l['product_sku'] ?? ''} ${l['product_name'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Ordered ${_fmt((l['ordered_qty'] as num?) ?? 0)} | Issued ${_fmt((l['shipped_qty'] as num?) ?? 0)} | Cost ${_fmt((l['total_cost'] as num?) ?? 0)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Map<String, dynamic> order) async {
    final lines = (order['lines'] as List<dynamic>?) ?? [];
    if ((order['status'] ?? '') != 'draft' || lines.isEmpty) {
      _snack(context, 'Only draft GI orders can be edited.', Colors.orange);
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GIEditDialog(
        order: order,
        products: products,
        warehouses: warehouses,
        svc: svc,
      ),
    );
    if (result == null) return;
    try {
      await svc.updateOutbound(order['id'].toString(), result);
      _snack(context, 'GI order updated.', Colors.green);
      onChanged();
    } catch (e) {
      _snack(context, e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  Future<void> _viewJournal(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    try {
      final data = await svc.getOutboundJournal(order['id'].toString());
      final entries = ((data['journal_entries'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (entries.isEmpty) {
        entries.add((data['journal_entry'] as Map<String, dynamic>?) ?? data);
      }
      final first = entries.first;
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                first['status'] == 'posted'
                    ? Icons.check_circle
                    : Icons.edit_note,
                color: first['status'] == 'posted'
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entries.length > 1
                      ? 'Journal Entries (${entries.length})'
                      : first['document_no']?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _journalStatusBadge(first['status']?.toString() ?? 'draft'),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: entries
                    .asMap()
                    .entries
                    .map(
                      (entry) => _journalEntryPanel(
                        entry.value,
                        entry.key,
                        entries.length,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _snack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        Colors.orange,
      );
    }
  }

  Widget _journalEntryPanel(
    Map<String, dynamic> je,
    int index,
    int totalEntries,
  ) {
    final lines = (je['lines'] as List<dynamic>?) ?? [];
    var totalDebit = (je['total_debit'] as num?)?.toDouble() ?? 0;
    var totalCredit = (je['total_credit'] as num?)?.toDouble() ?? 0;
    if (totalDebit == 0 && totalCredit == 0) {
      for (final line in lines) {
        totalDebit += (line['debit'] as num?)?.toDouble() ?? 0;
        totalCredit += (line['credit'] as num?)?.toDouble() ?? 0;
      }
    }
    final isReversal = je['entry_type']?.toString() == 'reversal';
    return Padding(
      padding: EdgeInsets.only(bottom: index == totalEntries - 1 ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReversal ? Icons.undo_outlined : Icons.receipt_long_outlined,
                size: 18,
                color: isReversal ? AppTheme.errorColor : AppTheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${je['document_no'] ?? 'N/A'}${isReversal ? ' - Reversal' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _journalStatusBadge(je['status']?.toString() ?? 'draft'),
            ],
          ),
          const SizedBox(height: 10),
          _journalDetailRow('Description', je['description']?.toString() ?? ''),
          _journalDetailRow('Posting Date', _journalDate(je['posting_date'])),
          _journalDetailRow('Document Date', _journalDate(je['document_date'])),
          _journalDetailRow('Reference', je['reference']?.toString() ?? ''),
          _journalDetailRow('Type', je['entry_type']?.toString() ?? 'normal'),
          if ((je['organization_name']?.toString() ?? '').isNotEmpty)
            _journalDetailRow('Company', je['organization_name'].toString()),
          const Divider(height: 16),
          const Text(
            'Line Items',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _journalLineTable(lines, totalDebit, totalCredit),
        ],
      ),
    );
  }

  Widget _journalStatusBadge(String status) {
    final color = status == 'posted'
        ? AppTheme.successColor
        : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _journalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _journalLineTable(
    List<dynamic> lines,
    double totalDebit,
    double totalCredit,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Account',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Debit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Credit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Description',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          ...lines.map(
            (line) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${line['account_code'] ?? ''} ${line['account_name'] ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ((line['debit'] as num?)?.toDouble() ?? 0) != 0
                          ? '\$${GlService.fmtAmount(line['debit'] as num?)}'
                          : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ((line['credit'] as num?)?.toDouble() ?? 0) != 0
                          ? '\$${GlService.fmtAmount(line['credit'] as num?)}'
                          : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      line['description']?.toString() ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    '\$${GlService.fmtAmount(totalDebit)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '\$${GlService.fmtAmount(totalCredit)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _journalDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.outbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No Goods Issue history',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (_, i) => _buildCard(context, orders[i]),
    );
  }

  Widget _buildCard(BuildContext context, dynamic o) {
    final order = o as Map<String, dynamic>;
    final orderNo =
        order['order_no'] ?? order['id']?.toString().substring(0, 8) ?? '';
    final ref = order['reference_no'] ?? '';
    final cust = order['customer_name'] ?? '';
    final status = order['status'] ?? 'draft';
    final statusText = status == 'shipped'
        ? 'ISSUED'
        : status.toString().toUpperCase();
    final lines = (order['lines'] as List<dynamic>?) ?? [];
    final qty = lines.fold<double>(
      0,
      (s, l) => s + ((l['ordered_qty'] as num?)?.toDouble() ?? 0),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_upward,
            color: Colors.orange.shade700,
            size: 20,
          ),
        ),
        title: Text(
          'GI-$orderNo',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          '$cust | $ref | Qty: ${qty.toStringAsFixed(0)} | ${_dt(order['created_at'])}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          maxLines: 1,
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _stColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _stColor(status),
                ),
              ),
            ),
            IconButton(
              tooltip: 'View',
              icon: const Icon(Icons.visibility_outlined, size: 18),
              onPressed: () => _view(context, order),
            ),
            if (status == 'draft')
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _edit(context, order),
              ),
            if (status == 'draft')
              IconButton(
                tooltip: 'Post GI',
                icon: const Icon(Icons.outbox_outlined, size: 18),
                onPressed: () => _postGI(context, order),
              ),
            if (status == 'issued' || status == 'shipped')
              IconButton(
                tooltip: 'Reverse',
                icon: const Icon(Icons.undo_outlined, size: 18),
                onPressed: () => _reverse(context, order),
              ),
            IconButton(
              tooltip: 'View Journal Entry',
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              onPressed: () => _viewJournal(context, order),
            ),
          ],
        ),
      ),
    );
  }
}

class _GIEditDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final List<dynamic> products;
  final List<dynamic> warehouses;
  final WarehouseService svc;

  const _GIEditDialog({
    required this.order,
    required this.products,
    required this.warehouses,
    required this.svc,
  });

  @override
  State<_GIEditDialog> createState() => _GIEditDialogState();
}

class _GIEditDialogState extends State<_GIEditDialog> {
  late String _orderType;
  late final TextEditingController _refCtrl;
  late final TextEditingController _custCtrl;
  late final TextEditingController _qtyCtrl;
  String? _whId;
  String? _prodId;
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _allBins = [];

  @override
  void initState() {
    super.initState();
    _orderType = widget.order['order_type']?.toString() ?? 'sales_order';
    _refCtrl = TextEditingController(
      text: widget.order['reference_no']?.toString() ?? '',
    );
    _custCtrl = TextEditingController(
      text: widget.order['customer_name']?.toString() ?? '',
    );
    _whId = widget.order['warehouse_id']?.toString();
    final rawLines = ((widget.order['lines'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
    _lines = rawLines.map((l) => Map<String, dynamic>.from(l)).toList();
    if (_lines.isNotEmpty) {
      _prodId = _lines.first['product_id']?.toString();
      _qtyCtrl = TextEditingController(
        text: _fmt((_lines.first['ordered_qty'] as num?)?.toDouble() ?? 0),
      );
    } else {
      _qtyCtrl = TextEditingController();
    }
    _loadBins();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _custCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBins() async {
    try {
      final bins = await widget.svc.listBins();
      if (mounted) {
        setState(() => _allBins = bins.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  List<Map<String, dynamic>> _binOptions(Map<String, dynamic> line) {
    final warehouseId =
        line['warehouse_id']?.toString() ??
        _whId ??
        widget.order['warehouse_id']?.toString();
    if (warehouseId == null || warehouseId.isEmpty) {
      return [
        {'bin_id': '', 'bin_code': 'No Bin'},
      ];
    }
    final bins = _allBins
        .where((b) => b['warehouse_id']?.toString() == warehouseId)
        .map(
          (b) => {
            'bin_id': b['id']?.toString() ?? '',
            'bin_code': b['code'] ?? b['bin_code'] ?? b['name'] ?? 'Bin',
          },
        )
        .toList();
    if (bins.isEmpty) {
      return [
        {'bin_id': '', 'bin_code': 'No Bin'},
      ];
    }
    return bins;
  }

  void _save() {
    final payloadLines = _orderType == 'work_order'
        ? _lines
              .map(
                (l) => {
                  'product_id': l['product_id'],
                  'warehouse_id': l['warehouse_id'] ?? _whId,
                  if (l['bin_id'] != null && l['bin_id'].toString().isNotEmpty)
                    'bin_id': l['bin_id'],
                  'ordered_qty': (l['ordered_qty'] as num?)?.toDouble() ?? 0,
                },
              )
              .toList()
        : [
            {
              'product_id': _prodId,
              'ordered_qty': double.tryParse(_qtyCtrl.text.trim()) ?? 0,
            },
          ];
    if (payloadLines.any(
      (l) => l['product_id'] == null || (l['ordered_qty'] as double) <= 0,
    )) {
      return;
    }
    Navigator.pop(context, {
      'order_type': _orderType,
      'reference_no': _refCtrl.text.trim(),
      if (_orderType != 'work_order') 'warehouse_id': _whId,
      if (_orderType == 'work_order')
        'warehouse_id': payloadLines.first['warehouse_id'],
      'customer_name': _custCtrl.text.trim(),
      'lines': payloadLines,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.order['order_no'] ?? ''}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Goods Issue Order',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _orderType,
                decoration: const InputDecoration(
                  labelText: 'Order Type',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'sales_order',
                    child: Text('Sales Order'),
                  ),
                  DropdownMenuItem(
                    value: 'work_order',
                    child: Text('Work Order'),
                  ),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                  DropdownMenuItem(value: 'return', child: Text('Return')),
                ],
                onChanged: (v) => setState(() => _orderType = v ?? _orderType),
              ),
              const SizedBox(height: 12),
              if (_orderType != 'work_order')
                DropdownButtonFormField<String>(
                  value: _whId,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse *',
                    isDense: true,
                  ),
                  items: widget.warehouses
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id']?.toString(),
                          child: Text('${w['code'] ?? w['name'] ?? ''}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _whId = v),
                ),
              if (_orderType != 'work_order') const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                readOnly: _orderType == 'work_order',
                decoration: InputDecoration(
                  labelText: _orderType == 'work_order'
                      ? 'Reference (Work Order)'
                      : 'Reference (SO#)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _custCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  isDense: true,
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Item',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_orderType == 'work_order')
                _buildWorkOrderLines()
              else
                _buildSingleLine(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildSingleLine() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _prodId,
          decoration: const InputDecoration(
            labelText: 'Product',
            isDense: true,
          ),
          items: widget.products
              .map(
                (p) => DropdownMenuItem(
                  value: p['id']?.toString(),
                  child: Text('${p['sku']} - ${p['name']}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _prodId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qtyCtrl,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildWorkOrderLines() {
    return Column(
      children: _lines.map((line) {
        final whValue = line['warehouse_id']?.toString() ?? _whId;
        final bins = _binOptions(line);
        final binValue =
            bins.any(
              (b) =>
                  b['bin_id']?.toString() == (line['bin_id']?.toString() ?? ''),
            )
            ? (line['bin_id']?.toString() ?? '')
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${line['product_sku'] ?? ''} ${line['product_name'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value:
                      widget.warehouses.any(
                        (w) => w['id']?.toString() == whValue,
                      )
                      ? whValue
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse',
                    isDense: true,
                  ),
                  items: widget.warehouses
                      .map(
                        (w) => DropdownMenuItem(
                          value: w['id']?.toString(),
                          child: Text('${w['code'] ?? w['name'] ?? ''}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    line['warehouse_id'] = v;
                    line['bin_id'] = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: binValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Bin Location',
                    isDense: true,
                  ),
                  items: bins
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['bin_id']?.toString() ?? '',
                          child: Text('${b['bin_code'] ?? 'No Bin'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    line['bin_id'] = v == null || v.isEmpty ? null : v;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _fmt(
                    (line['ordered_qty'] as num?)?.toDouble() ?? 0,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Issue Qty',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      line['ordered_qty'] = double.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
