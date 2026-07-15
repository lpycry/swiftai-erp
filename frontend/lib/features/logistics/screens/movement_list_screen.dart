import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class MovementListScreen extends StatefulWidget {
  final AuthService authService;
  final WarehouseService warehouseService;
  const MovementListScreen({
    super.key,
    required this.authService,
    required this.warehouseService,
  });
  @override
  State<MovementListScreen> createState() => _MovementListScreenState();
}

class _MovementListScreenState extends State<MovementListScreen> {
  List<dynamic> _movements = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = false;

  // Filter state
  String? _filterWhId;
  String? _filterBinId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<dynamic> _binsForWh = [];

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _load();
  }

  Future<void> _loadWarehouses() async {
    try {
      final whs = await widget.warehouseService.listWarehouses();
      if (mounted)
        setState(() => _warehouses = whs.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.warehouseService.listMovements(
        warehouseId: _filterWhId,
        binId: _filterBinId,
        dateFrom: _dateFrom != null
            ? '${_dateFrom!.toIso8601String().substring(0, 19)}Z'
            : null,
        dateTo: _dateTo != null
            ? '${_dateTo!.toIso8601String().substring(0, 19)}Z'
            : null,
      );
      if (mounted) setState(() => _movements = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onWhChanged(String? whId) async {
    _filterWhId = whId;
    _filterBinId = null;
    // Load bins for this warehouse
    if (whId != null) {
      try {
        final uri = Uri.parse(
          'http://localhost:8080/api/v1/warehouse/bins?warehouse_id=$whId',
        );
        final r = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer ${widget.authService.accessToken ?? ''}',
          },
        );
        if (r.statusCode < 400) {
          final data = (jsonDecode(r.body)['data'] as List<dynamic>?) ?? [];
          _binsForWh = data;
        }
      } catch (_) {
        _binsForWh = [];
      }
    } else {
      _binsForWh = [];
    }
    if (mounted) setState(() {});
    await _load();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      await _load();
    }
  }

  void _clearFilters() {
    setState(() {
      _filterWhId = null;
      _filterBinId = null;
      _dateFrom = null;
      _dateTo = null;
      _binsForWh = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 2,
      onIndexChanged: (_) {},
      title: 'Movement History',
      body: Column(
        children: [
          // ── Filter bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Row 1: Warehouse + Bin
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterWhId,
                        decoration: InputDecoration(
                          labelText: 'Warehouse',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All', style: TextStyle(fontSize: 11)),
                          ),
                          ..._warehouses.map(
                            (w) => DropdownMenuItem(
                              value: w['id'].toString(),
                              child: Text(
                                '${w['code'] ?? ''} - ${w['name'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => _onWhChanged(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterBinId,
                        decoration: InputDecoration(
                          labelText: 'Bin Location',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All', style: TextStyle(fontSize: 11)),
                          ),
                          ..._binsForWh.map(
                            (b) => DropdownMenuItem(
                              value: b['id'].toString(),
                              child: Text(
                                '${b['code'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) async {
                          _filterBinId = v;
                          if (mounted) setState(() {});
                          await _load();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: Date range
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date From',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            suffixIcon: Icon(
                              Icons.date_range,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          child: Text(
                            _dateFrom != null
                                ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
                                : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: _dateFrom != null
                                  ? null
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date To',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            suffixIcon: Icon(
                              Icons.date_range,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          child: Text(
                            _dateTo != null
                                ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                                : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: _dateTo != null
                                  ? null
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: _clearFilters,
                      tooltip: 'Clear Filters',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _load,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Count ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_movements.length} movement(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (_filterWhId != null ||
                    _filterBinId != null ||
                    _dateFrom != null ||
                    _dateTo != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Column headers ──
          if (_movements.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'SKU',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Qty',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'From',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'To',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _movements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No movements',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _movements.length,
                      itemBuilder: (_, i) => _MovementRow(m: _movements[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Movement Row (unchanged, with reference info)
// ═══════════════════════════════════════════

class _MovementRow extends StatelessWidget {
  final dynamic m;
  const _MovementRow({required this.m});

  Color _typeColor(String t) {
    switch (t) {
      case 'goods_receipt':
        return Colors.green;
      case 'goods_issue':
        return Colors.red;
      case 'transfer':
        return Colors.blue;
      case 'adjustment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'goods_receipt':
        return 'GR';
      case 'goods_issue':
        return 'GI';
      case 'transfer':
        return 'TRF';
      case 'adjustment':
        return 'ADJ';
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = Fmt.dateStr(m['created_at']?.toString());
    final txType = m['transaction_type'] ?? '';
    final sku = m['product_sku'] ?? '';
    final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
    final from = m['warehouse_name'] ?? '';
    final to = m['to_warehouse_name'] ?? '';
    final color = _typeColor(txType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              createdAt,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _typeLabel(txType),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sku,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              qty.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: qty > 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              from,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              to.isNotEmpty ? to : '-',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
