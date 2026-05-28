import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

/// Stock On-Hand — grouped by SKU with filters
/// Show total qty per product across all locations

class StockOnHandScreen extends StatefulWidget {
  final AuthService authService;
  final WarehouseService warehouseService;
  const StockOnHandScreen({super.key, required this.authService, required this.warehouseService});
  @override State<StockOnHandScreen> createState() => _StockOnHandScreenState();
}

class _StockOnHandScreenState extends State<StockOnHandScreen> {
  List<dynamic> _stock = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = false;

  // Filters
  String? _filterWhId;
  String? _filterBinId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<dynamic> _binsForWh = [];

  @override void initState() { super.initState(); _loadWarehouses(); _loadStock(); }

  Future<void> _loadWarehouses() async {
    try {
      final whs = await widget.warehouseService.listWarehouses();
      if (mounted) setState(() => _warehouses = whs.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _loadStock() async {
    setState(() => _loading = true);
    try {
      final data = await widget.warehouseService.listStock(
        warehouseId: _filterWhId,
        binId: _filterBinId,
        groupBySku: true,
        dateFrom: _dateFrom != null ? '${_dateFrom!.toIso8601String().substring(0, 19)}Z' : null,
        dateTo: _dateTo != null ? '${_dateTo!.toIso8601String().substring(0, 19)}Z' : null,
      );
      if (mounted) setState(() => _stock = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.errorColor));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _onWhChanged(String? whId) async {
    _filterWhId = whId;
    _filterBinId = null;
    if (whId != null) {
      try {
        final r = await http.get(
          Uri.parse('http://localhost:8080/api/v1/warehouse/bins?warehouse_id=$whId'),
          headers: {'Authorization': 'Bearer ${widget.authService.accessToken ?? ''}'});
        if (r.statusCode < 400) _binsForWh = (jsonDecode(r.body)['data'] as List<dynamic>?) ?? [];
      } catch (_) { _binsForWh = []; }
    } else {
      _binsForWh = [];
    }
    if (mounted) setState(() {});
    await _loadStock();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() { if (isFrom) _dateFrom = picked; else _dateTo = picked; });
      await _loadStock();
    }
  }

  void _clearFilters() {
    setState(() { _filterWhId = null; _filterBinId = null; _dateFrom = null; _dateTo = null; _binsForWh = []; });
    _loadStock();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {},
      title: 'Stock On-Hand',
      body: Column(children: [
        // ── Filters ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey.shade50,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterWhId,
                  decoration: InputDecoration(
                    labelText: 'Warehouse', isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Warehouses', style: TextStyle(fontSize: 11))),
                    ..._warehouses.map((w) => DropdownMenuItem(value: w['id'].toString(),
                        child: Text('${w['code'] ?? ''} - ${w['name'] ?? ''}', style: const TextStyle(fontSize: 11)))),
                  ],
                  onChanged: (v) => _onWhChanged(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterBinId,
                  decoration: InputDecoration(
                    labelText: 'Bin Location', isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Bins', style: TextStyle(fontSize: 11))),
                    ..._binsForWh.map((b) => DropdownMenuItem(value: b['id'].toString(),
                        child: Text('${b['code'] ?? ''}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')))),
                  ],
                  onChanged: (v) async { _filterBinId = v; if (mounted) setState(() {}); await _loadStock(); },
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Last Movement From', isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      suffixIcon: Icon(Icons.date_range, size: 16, color: Colors.grey.shade500)),
                    child: Text(_dateFrom != null
                        ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
                        : '', style: TextStyle(fontSize: 11, color: _dateFrom != null ? null : Colors.grey.shade400)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Last Movement To', isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      suffixIcon: Icon(Icons.date_range, size: 16, color: Colors.grey.shade500)),
                    child: Text(_dateTo != null
                        ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                        : '', style: TextStyle(fontSize: 11, color: _dateTo != null ? null : Colors.grey.shade400)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade500), onPressed: _clearFilters, tooltip: 'Clear Filters'),
              IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadStock, tooltip: 'Refresh'),
            ]),
          ]),
        ),
        const Divider(height: 1),
        // ── Count ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_stock.length} SKU(s)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            if (_filterWhId != null || _filterBinId != null || _dateFrom != null || _dateTo != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(3)),
                child: Text('Filtered', style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w500))),
            const Spacer(),
            Text('Grouped by SKU', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          ]),
        ),
        const Divider(height: 1),
        // ── Column headers ──
        if (_stock.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), color: Colors.grey.shade100,
            child: Row(children: [
              const Expanded(flex: 2, child: Text('SKU', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('On Hand', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Reserved', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Available', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Total Cost', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            ]),
          ),
        // ── List ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _stock.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No stock data', style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadStock,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _stock.length,
                        itemBuilder: (context, i) => _StockRow(entry: _stock[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _StockRow extends StatelessWidget {
  final dynamic entry;
  const _StockRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final sku = entry['product_sku'] ?? '';
    final name = entry['product_name'] ?? '';
    final qty = (entry['quantity_on_hand'] as num?)?.toDouble() ?? 0;
    final reserved = (entry['quantity_reserved'] as num?)?.toDouble() ?? 0;
    final available = qty - reserved;
    final totalCost = (entry['total_cost'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(sku, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
        Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(qty.toStringAsFixed(0), textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700))),
        Expanded(flex: 1, child: Text(reserved.toStringAsFixed(0), textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade600))),
        Expanded(flex: 1, child: Text(available.toStringAsFixed(0), textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: available > 0 ? Colors.green.shade700 : Colors.red.shade700))),
        Expanded(flex: 1, child: Text('\$${totalCost.toStringAsFixed(2)}', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
      ]),
    );
  }
}
