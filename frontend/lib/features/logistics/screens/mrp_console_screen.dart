import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/production/screens/material_requirements_screen.dart';
import 'package:swiftai_erp/features/production/screens/mps_review_screen.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class MRPConsoleScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;

  const MRPConsoleScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  State<MRPConsoleScreen> createState() => _MRPConsoleScreenState();
}

class _MRPConsoleScreenState extends State<MRPConsoleScreen> {
  static const _baseUrl = 'http://localhost:8080/api/v1';

  bool _loading = true;
  bool _running = false;
  bool _loadingRequirements = false;
  String _planningScope = 'PLANT';
  String _processingKey = 'NETCH';
  String _createPR = '1';
  String _planningMode = '3';
  String? _siteId;
  String? _productId;
  List<dynamic> _sites = [];
  List<dynamic> _products = [];
  Map<String, dynamic>? _runResult;
  Map<String, dynamic>? _requirements;
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _loading = true);
    try {
      final headers = {
        'Authorization': 'Bearer ${widget.authService.accessToken}',
      };
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/sites'), headers: headers),
        http.get(Uri.parse('$_baseUrl/warehouse/products'), headers: headers),
      ]);
      final allSites = results[0].statusCode < 400
          ? (jsonDecode(results[0].body)['data'] as List<dynamic>? ?? [])
          : <dynamic>[];
      final products = results[1].statusCode < 400
          ? (jsonDecode(results[1].body)['data'] as List<dynamic>? ?? [])
          : <dynamic>[];
      final plants = allSites
          .where(
            (site) => site is Map && site['site_type']?.toString() == 'plant',
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _sites = plants.isEmpty ? allSites : plants;
        _products = products
            .where(
              (p) =>
                  p is Map &&
                  (p['mrp_type']?.toString().toUpperCase() == 'MRP' ||
                      p['mrp_type']?.toString().toUpperCase() == 'MPS'),
            )
            .toList();
        _siteId ??= _sites.isNotEmpty ? _sites.first['id']?.toString() : null;
        _productId ??= _products.isNotEmpty
            ? _products.first['id']?.toString()
            : null;
      });
      await _loadRequirements();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runMRP() async {
    setState(() => _running = true);
    try {
      final result = await widget.productionService.runMRP({
        if (_planningScope == 'PLANT' && _siteId != null) 'site_id': _siteId,
        'planning_mode': _processingKey,
        'planning_time_fence_enabled': _planningMode == '1',
        'planning_time_fence_days': 5,
        'run_mrp_after_mps': true,
      });
      if (!mounted) return;
      setState(() => _runResult = result);
      await _loadRequirements();
      final mrp = result['mrp_result'] as Map<String, dynamic>?;
      final prs =
          (mrp?['planned_purchase_requisitions'] as List<dynamic>? ?? [])
              .length;
      final ex = (mrp?['exceptions'] as List<dynamic>? ?? []).length;
      _snack('MRP completed. Planned PR: $prs, Exceptions: $ex');
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _loadRequirements() async {
    if (_productId == null) return;
    setState(() => _loadingRequirements = true);
    try {
      final data = await widget.productionService.getMaterialRequirementsList(
        productId: _productId!,
        siteId: _planningScope == 'PLANT' ? _siteId : null,
      );
      if (mounted) setState(() => _requirements = data);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingRequirements = false);
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

  String _fmt(dynamic value) {
    final n = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  int _mrpPRCount() {
    final mrp = _runResult?['mrp_result'] as Map<String, dynamic>?;
    return (mrp?['planned_purchase_requisitions'] as List<dynamic>? ?? [])
        .length;
  }

  int _mrpExceptionCount() {
    final mrp = _runResult?['mrp_result'] as Map<String, dynamic>?;
    return (mrp?['exceptions'] as List<dynamic>? ?? []).length;
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_requirements?['elements'] as List<dynamic>? ?? []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MRP Running Console'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MpsReviewScreen(
                  authService: widget.authService,
                  productionService: widget.productionService,
                  initialTab: 1,
                ),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('MRP Results'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadMasterData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _pageScrollController,
                primary: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _runConsole(),
                      const Divider(height: 1),
                      _resultSummary(),
                      const Divider(height: 1),
                      _evaluationHeader(),
                      SizedBox(
                        height: 420,
                        child: _loadingRequirements
                            ? const Center(child: CircularProgressIndicator())
                            : rows.isEmpty
                            ? const Center(child: Text('No MRP elements found'))
                            : _mrpElementsTable(rows),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _runConsole() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Run Parameters',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                height: 58,
                child: DropdownButtonFormField<String>(
                  initialValue: _planningScope,
                  decoration: const InputDecoration(
                    labelText: 'Planning Scope',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PLANT',
                      child: Text('Specific Plant'),
                    ),
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text('All Plants'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _planningScope = v ?? 'PLANT'),
                ),
              ),
              SizedBox(
                width: 260,
                height: 58,
                child: DropdownButtonFormField<String>(
                  initialValue: _siteId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Plant'),
                  items: _sites
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(
                            '${s['site_code'] ?? ''} - ${s['site_name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _planningScope == 'ALL'
                      ? null
                      : (v) async {
                          setState(() => _siteId = v);
                          await _loadRequirements();
                        },
                ),
              ),
              SizedBox(
                width: 340,
                height: 48,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'NETCH',
                      label: Text('NETCH'),
                      icon: Icon(Icons.update, size: 16),
                    ),
                    ButtonSegment(
                      value: 'NEUPL',
                      label: Text('NEUPL'),
                      icon: Icon(Icons.restart_alt, size: 16),
                    ),
                  ],
                  selected: {_processingKey},
                  onSelectionChanged: (v) {
                    setState(() => _processingKey = v.first);
                  },
                ),
              ),
              SizedBox(
                width: 250,
                height: 58,
                child: DropdownButtonFormField<String>(
                  initialValue: _createPR,
                  decoration: const InputDecoration(
                    labelText: 'Create Purchase Req.',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '1',
                      child: Text('1 - Direct PR'),
                    ),
                    DropdownMenuItem(
                      value: '2',
                      child: Text('2 - Planned order first'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _createPR = v ?? '1'),
                ),
              ),
              SizedBox(
                width: 260,
                height: 58,
                child: DropdownButtonFormField<String>(
                  initialValue: _planningMode,
                  decoration: const InputDecoration(labelText: 'Planning Mode'),
                  items: const [
                    DropdownMenuItem(
                      value: '1',
                      child: Text('1 - Adaptive/time fence'),
                    ),
                    DropdownMenuItem(
                      value: '3',
                      child: Text('3 - Clear and recalculate'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _planningMode = v ?? '3'),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _running ? null : _runMRP,
                  icon: _running
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run Global MRP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _processingKey == 'NETCH'
                ? 'NETCH recalculates changed materials. NEUPL clears and recalculates all planning proposals in scope.'
                : 'NEUPL performs a full regenerative planning run for the selected scope.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _resultSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _summaryTile('MPS Planned Orders', _runResult?['planned_orders']),
          _summaryTile('Dependent Demands', _runResult?['dependent_demands']),
          _summaryTile('MRP Planned PR', _mrpPRCount()),
          _summaryTile('MRP Exceptions', _mrpExceptionCount()),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MaterialRequirementsScreen(
                  authService: widget.authService,
                  productionService: widget.productionService,
                ),
              ),
            ),
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: const Text('Open MD04'),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, dynamic value) {
    final count = value is List ? value.length : value is int ? value : 0;
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _evaluationHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Material',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: _products
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id']?.toString(),
                          child: Text(
                            '${p['sku'] ?? ''} - ${p['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _productId = v);
                    await _loadRequirements();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loadingRequirements ? null : _loadRequirements,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Display MD04'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_requirements != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _headerValue(
                    'Material',
                    '${_requirements!['product_sku'] ?? ''} - ${_requirements!['product_name'] ?? ''}',
                  ),
                  _headerValue('MRP Type', _requirements!['mrp_type']),
                  _headerValue('Unit', _requirements!['base_uom']),
                  _headerValue('OnHand Qty', _fmt(_requirements!['stock_qty'])),
                  _headerValue(
                    'Available Qty',
                    _fmt(_requirements!['available_qty']),
                  ),
                  _headerValue(
                    'Safety Stock',
                    _fmt(_requirements!['safety_stock']),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mrpElementsTable(List<dynamic> rows) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 980),
            child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('MRP Element')),
            DataColumn(label: Text('MRP Element Data')),
            DataColumn(label: Text('Receipt/Reqmt')),
            DataColumn(label: Text('Available Stock')),
            DataColumn(label: Text('Exception')),
            DataColumn(label: Text('Action')),
          ],
          rows: rows.map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final receipt = (row['receipt_qty'] as num?)?.toDouble() ?? 0;
            final req = (row['requirement_qty'] as num?)?.toDouble() ?? 0;
            final available = (row['available_qty'] as num?)?.toDouble() ?? 0;
            final exception = row['exception']?.toString() ?? '';
            final danger = available < 0 || exception.isNotEmpty;
            final qtyText = receipt > 0
                ? '+${_fmt(receipt)}'
                : req > 0
                ? '-${_fmt(req)}'
                : '';
            return DataRow(
              color: WidgetStateProperty.resolveWith(
                (_) => danger ? Colors.red.withValues(alpha: 0.08) : null,
              ),
              cells: [
                DataCell(Text(row['date']?.toString() ?? '')),
                DataCell(Text(row['mrp_element']?.toString() ?? '')),
                DataCell(Text(row['element_data']?.toString() ?? '')),
                DataCell(Text(qtyText)),
                DataCell(Text(_fmt(available))),
                DataCell(
                  Text(
                    exception,
                    style: TextStyle(
                      color: danger ? Colors.red.shade700 : Colors.grey.shade700,
                      fontWeight: danger ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _showElement(row),
                    child: const Text('View'),
                  ),
                ),
              ],
            );
          }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showElement(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row['mrp_element']?.toString() ?? 'MRP Element'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: row.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            e.key,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(child: Text(e.value?.toString() ?? '-')),
                      ],
                    ),
                  ),
                )
                .toList(),
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

  Widget _headerValue(String label, dynamic value) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(
            value?.toString().isNotEmpty == true ? value.toString() : '-',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
