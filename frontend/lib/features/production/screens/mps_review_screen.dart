import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/production/screens/production_order_screen.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class MpsReviewScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  final int initialTab;

  const MpsReviewScreen({
    super.key,
    required this.authService,
    required this.productionService,
    this.initialTab = 0,
  });

  @override
  State<MpsReviewScreen> createState() => _MpsReviewScreenState();
}

class _MpsReviewScreenState extends State<MpsReviewScreen> {
  bool _loading = true;
  bool _converting = false;
  bool _convertingMrpPR = false;
  List<dynamic> _plannedOrders = [];
  List<dynamic> _dependentDemands = [];
  List<dynamic> _exceptions = [];
  List<dynamic> _mrpPurchaseRequisitions = [];
  List<dynamic> _mrpExceptions = [];
  final Set<String> _selectedPlannedOrders = {};
  final Set<String> _selectedMrpPRs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.productionService.listMPSPlannedOrders(),
        widget.productionService.listMPSDependentDemands(),
        widget.productionService.listMPSExceptions(),
        widget.productionService.listMRPPlannedPurchaseRequisitions(),
        widget.productionService.listMRPExceptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _plannedOrders = results[0];
        _dependentDemands = results[1];
        _exceptions = results[2];
        _mrpPurchaseRequisitions = results[3];
        _mrpExceptions = results[4];
        _selectedPlannedOrders.removeWhere((id) {
          return !_plannedOrders.any((raw) => raw['id']?.toString() == id);
        });
        _selectedMrpPRs.removeWhere((id) {
          return !_mrpPurchaseRequisitions.any(
            (raw) => raw['id']?.toString() == id,
          );
        });
      });
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFirm(Map<String, dynamic> order) async {
    final id = order['id']?.toString();
    if (id == null) return;
    try {
      await widget.productionService.firmMPSPlannedOrder(
        id,
        order['is_firmed'] != true,
      );
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _convertOne(Map<String, dynamic> order) async {
    final id = order['id']?.toString();
    if (id == null) return;
    setState(() => _converting = true);
    try {
      final po = await widget.productionService.convertMPSPlannedOrder(id);
      await _load();
      _openProductionOrder(po['id']?.toString(), entry: po);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _convertBatch({required bool all}) async {
    final ids = all ? <String>[] : _selectedPlannedOrders.toList();
    if (!all && ids.isEmpty) {
      _snack('Select planned orders first', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(all ? 'Convert All Planned Orders' : 'Convert Selection'),
        content: Text(
          all
              ? 'Convert all open MPS planned orders to formal work orders?'
              : 'Convert ${ids.length} selected planned order(s) to formal work orders?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _converting = true);
    try {
      final orders = await widget.productionService.convertMPSPlannedOrders(
        ids: ids,
        all: all,
      );
      _selectedPlannedOrders.clear();
      await _load();
      _snack('Converted ${orders.length} work order(s)');
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _convertMrpPRs({
    List<String> ids = const [],
    bool all = false,
  }) async {
    if (!all && ids.isEmpty) {
      _snack('Select MRP PR first', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(all ? 'Convert All MRP PR' : 'Convert MRP PR'),
        content: Text(
          all
              ? 'Convert all open MRP planned purchase requisitions to formal PR?'
              : 'Convert ${ids.length} selected MRP planned purchase requisition(s) to formal PR?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _convertingMrpPR = true);
    try {
      final pr = await widget.productionService.convertMRPPRsToPR(
        ids: ids,
        all: all,
      );
      _selectedMrpPRs.clear();
      await _load();
      _snack('Created PR ${pr['pr_number'] ?? ''}');
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _convertingMrpPR = false);
    }
  }

  Future<void> _openProductionOrder(
    String? id, {
    Map<String, dynamic>? entry,
  }) async {
    if (id == null || id.isEmpty) return;
    Map<String, dynamic> order = entry ?? {};
    if (order.isEmpty) {
      try {
        order = await widget.productionService.getProductionOrder(id);
      } catch (e) {
        _snack('$e', isError: true);
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionOrderDetailScreen(
          authService: widget.authService,
          productionService: widget.productionService,
          entry: order,
          onSaved: _load,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTab.clamp(0, 4),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MPS Review'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Planned Orders (${_plannedOrders.length})'),
              Tab(text: 'MRP PR (${_mrpPurchaseRequisitions.length})'),
              Tab(text: 'Dependent Demands (${_dependentDemands.length})'),
              Tab(text: 'MPS Exceptions (${_exceptions.length})'),
              Tab(text: 'MRP Exceptions (${_mrpExceptions.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _plannedOrdersTab(),
                  _mrpPurchaseRequisitionsTab(),
                  _dependentDemandsTab(),
                  _exceptionsTab(),
                  _mrpExceptionsTab(),
                ],
              ),
      ),
    );
  }

  Widget _plannedOrdersTab() {
    final openCount = _plannedOrders.where((raw) {
      return (raw['converted_production_order_id']?.toString() ?? '').isEmpty;
    }).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '$openCount open planned order(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _converting ? null : () => _convertBatch(all: false),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Convert Selected'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _converting || openCount == 0
                    ? null
                    : () => _convertBatch(all: true),
                icon: _converting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.precision_manufacturing_rounded),
                label: const Text('Convert All'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _plannedOrders.isEmpty
              ? const Center(child: Text('No MPS planned orders'))
              : ListView.separated(
                  itemCount: _plannedOrders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final order = Map<String, dynamic>.from(
                      _plannedOrders[index] as Map,
                    );
                    final id = order['id']?.toString() ?? '';
                    final convertedId =
                        order['converted_production_order_id']?.toString() ??
                        '';
                    final converted = convertedId.isNotEmpty;
                    final selected = _selectedPlannedOrders.contains(id);
                    return ListTile(
                      leading: converted
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : Checkbox(
                              value: selected,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedPlannedOrders.add(id);
                                } else {
                                  _selectedPlannedOrders.remove(id);
                                }
                              }),
                            ),
                      title: Text(
                        '${order['product_sku'] ?? ''} - ${order['product_name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Qty ${_fmt(order['planned_qty'])}  Due ${order['due_date'] ?? ''}'
                        '${_plantLabel(order) == '-' ? '' : '  Plant ${_plantLabel(order)}'}'
                        '${converted ? '  Converted ${order['converted_order_number'] ?? convertedId}' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'View Details',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => _showDetails(
                              'MPS Planned Order',
                              order,
                              preferredKeys: const [
                                'product_sku',
                                'product_name',
                                'planned_qty',
                                'due_date',
                                'site_code',
                                'site_name',
                                'is_firmed',
                                'converted_order_number',
                                'status',
                                'exception_code',
                                'exception_message',
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _toggleFirm(order),
                            icon: Icon(
                              order['is_firmed'] == true
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                              size: 16,
                            ),
                            label: Text(
                              order['is_firmed'] == true ? 'Unfirm' : 'Firm',
                            ),
                          ),
                          if (converted)
                            IconButton(
                              tooltip: 'Open Work Order',
                              icon: const Icon(Icons.open_in_new_rounded),
                              onPressed: () =>
                                  _openProductionOrder(convertedId),
                            )
                          else
                            IconButton(
                              tooltip: 'Convert',
                              icon: const Icon(
                                Icons.precision_manufacturing_rounded,
                              ),
                              onPressed: _converting
                                  ? null
                                  : () => _convertOne(order),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dependentDemandsTab() {
    if (_dependentDemands.isEmpty) {
      return const Center(child: Text('No dependent demands'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('Parent')),
          DataColumn(label: Text('Component')),
          DataColumn(label: Text('MRP Type')),
          DataColumn(label: Text('Demand Qty')),
          DataColumn(label: Text('Requirement Date')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('View')),
        ],
        rows: _dependentDemands.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return DataRow(
            cells: [
              DataCell(Text(row['parent_sku']?.toString() ?? '')),
              DataCell(
                Text(
                  '${row['component_sku'] ?? ''} - ${row['component_name'] ?? ''}',
                ),
              ),
              DataCell(Text(row['component_mrp_type']?.toString() ?? '')),
              DataCell(Text(_fmt(row['demand_qty']))),
              DataCell(Text(row['requirement_date']?.toString() ?? '')),
              DataCell(Text(row['action']?.toString() ?? '')),
              DataCell(
                IconButton(
                  tooltip: 'View Details',
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => _showDetails(
                    'Dependent Demand',
                    row,
                    preferredKeys: const [
                      'parent_sku',
                      'parent_name',
                      'component_sku',
                      'component_name',
                      'component_mrp_type',
                      'demand_qty',
                      'requirement_date',
                      'action',
                      'site_code',
                      'site_name',
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _exceptionsTab() {
    if (_exceptions.isEmpty) {
      return const Center(child: Text('No MPS exceptions'));
    }
    return ListView.separated(
      itemCount: _exceptions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final row = Map<String, dynamic>.from(_exceptions[index] as Map);
        final severity = row['severity']?.toString() ?? 'WARNING';
        return ListTile(
          leading: Icon(
            severity == 'ERROR'
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: severity == 'ERROR' ? Colors.red : Colors.orange,
          ),
          title: Text(
            '${row['code'] ?? ''} ${row['product_sku'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(row['message']?.toString() ?? ''),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(severity),
              IconButton(
                tooltip: 'View Details',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => _showDetails(
                  'MPS Exception',
                  row,
                  preferredKeys: const [
                    'code',
                    'severity',
                    'product_sku',
                    'product_name',
                    'message',
                    'site_code',
                    'site_name',
                    'created_at',
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mrpPurchaseRequisitionsTab() {
    if (_mrpPurchaseRequisitions.isEmpty) {
      return const Center(child: Text('No MRP planned purchase requisitions'));
    }
    final openRows = _mrpPurchaseRequisitions.where((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      return row['status']?.toString() == 'PLANNED';
    }).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '$openRows open MRP PR line(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _convertingMrpPR
                    ? null
                    : () => _convertMrpPRs(ids: _selectedMrpPRs.toList()),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Convert Selected'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _convertingMrpPR || openRows == 0
                    ? null
                    : () => _convertMrpPRs(all: true),
                icon: _convertingMrpPR
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.request_quote_rounded, size: 18),
                label: const Text('Convert All to PR'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 58,
              columns: const [
                DataColumn(label: Text('')),
                DataColumn(label: Text('Material')),
                DataColumn(label: Text('Vendor')),
                DataColumn(label: Text('Demand')),
                DataColumn(label: Text('Net')),
                DataColumn(label: Text('PR Qty')),
                DataColumn(label: Text('Due')),
                DataColumn(label: Text('Release')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: _mrpPurchaseRequisitions.map((raw) {
                final row = Map<String, dynamic>.from(raw as Map);
                final id = row['id']?.toString() ?? '';
                final isOpen = row['status']?.toString() == 'PLANNED';
                final selected = _selectedMrpPRs.contains(id);
                return DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selected,
                        onChanged: !isOpen || _convertingMrpPR
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  _selectedMrpPRs.add(id);
                                } else {
                                  _selectedMrpPRs.remove(id);
                                }
                              }),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${row['product_sku'] ?? ''} - ${row['product_name'] ?? ''}',
                      ),
                    ),
                    DataCell(
                      Text(
                        '${row['vendor_code'] ?? ''} - ${row['vendor_name'] ?? ''}',
                      ),
                    ),
                    DataCell(Text(_fmt(row['demand_qty']))),
                    DataCell(Text(_fmt(row['net_qty']))),
                    DataCell(
                      Text(
                        '${_fmt(row['order_qty'])} ${row['purchase_uom'] ?? ''}',
                      ),
                    ),
                    DataCell(Text(row['due_date']?.toString() ?? '')),
                    DataCell(Text(row['release_date']?.toString() ?? '')),
                    DataCell(
                      Text('${row['currency'] ?? ''} ${_fmt(row['price'])}'),
                    ),
                    DataCell(Text(row['status']?.toString() ?? '')),
                    DataCell(
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'View Details',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => _showDetails(
                              'MRP Planned Purchase Requisition',
                              row,
                              preferredKeys: const [
                                'product_sku',
                                'product_name',
                                'vendor_code',
                                'vendor_name',
                                'demand_qty',
                                'on_hand_qty',
                                'scheduled_receipts',
                                'allocated_qty',
                                'net_qty',
                                'order_qty',
                                'purchase_uom',
                                'due_date',
                                'release_date',
                                'currency',
                                'price',
                                'status',
                                'site_code',
                                'site_name',
                                'info_record',
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Convert to PR',
                            icon: const Icon(Icons.request_quote_outlined),
                            onPressed: !isOpen || _convertingMrpPR
                                ? null
                                : () => _convertMrpPRs(ids: [id]),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mrpExceptionsTab() {
    if (_mrpExceptions.isEmpty) {
      return const Center(child: Text('No MRP exceptions'));
    }
    return _exceptionList(_mrpExceptions);
  }

  Widget _exceptionList(List<dynamic> rows) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        final severity = row['severity']?.toString() ?? 'WARNING';
        return ListTile(
          leading: Icon(
            severity == 'ERROR'
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: severity == 'ERROR' ? Colors.red : Colors.orange,
          ),
          title: Text(
            '${row['code'] ?? ''} ${row['product_sku'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(row['message']?.toString() ?? ''),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(severity),
              IconButton(
                tooltip: 'View Details',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => _showDetails(
                  'MRP Exception',
                  row,
                  preferredKeys: const [
                    'code',
                    'severity',
                    'product_sku',
                    'product_name',
                    'message',
                    'site_code',
                    'site_name',
                    'created_at',
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDetails(
    String title,
    Map<String, dynamic> row, {
    List<String> preferredKeys = const [],
  }) async {
    final orderedKeys = <String>[
      ...preferredKeys.where(row.containsKey),
      ...row.keys.where((key) => !preferredKeys.contains(key)),
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: orderedKeys
                  .where((key) => !_hideTechnicalDetailKey(key))
                  .map((key) => _detailRow(_label(key), _detailValue(row[key])))
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
  }

  bool _hideTechnicalDetailKey(String key) {
    final normalized = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toLowerCase();
    if (normalized == 'id') return true;
    if (normalized.endsWith('_id')) return true;
    return false;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String key) {
    return key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _detailValue(dynamic value) {
    if (value == null) return '';
    if (value is num) return _fmt(value);
    return value.toString();
  }

  String _plantLabel(Map<String, dynamic> order) {
    final code = order['site_code']?.toString() ?? '';
    final name = order['site_name']?.toString() ?? '';
    final label = [code, name].where((v) => v.isNotEmpty).join(' - ');
    return label.isEmpty ? '-' : label;
  }

  String _fmt(dynamic value) {
    final n = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }
}
