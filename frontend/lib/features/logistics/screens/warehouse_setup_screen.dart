import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

/// Bin Location Setup — flat CRUD for bin locations
/// Searchable list of all bins, with warehouse/site context

class WarehouseSetupScreen extends StatefulWidget {
  final AuthService authService;
  final WarehouseService warehouseService;
  const WarehouseSetupScreen({super.key, required this.authService, required this.warehouseService});
  @override State<WarehouseSetupScreen> createState() => _WarehouseSetupScreenState();
}

class _WarehouseSetupScreenState extends State<WarehouseSetupScreen> {
  bool _loading = true;
  List<dynamic> _bins = [];
  List<Map<String, dynamic>> _warehouses = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String? _filterWhId;

  @override
  void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final whs = await widget.warehouseService.listWarehouses();
      _warehouses = whs.cast<Map<String, dynamic>>();
      await _loadBins();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBins() async {
    try {
      final params = <String, String>{};
      if (_filterWhId != null) {
        params['warehouse_id'] = _filterWhId!;
      } else if (_searchCtrl.text.trim().isNotEmpty) {
        params['q'] = _searchCtrl.text.trim();
      }
      final uri = Uri.parse('http://localhost:8080/api/v1/warehouse/bins').replace(queryParameters: params.isEmpty ? null : params);
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $_token'});
      if (r.statusCode < 400) {
        _bins = (jsonDecode(r.body)['data'] as List<dynamic>?) ?? [];
      }
    } catch (_) {}
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    String? selWhId;
    if (_warehouses.length == 1) selWhId = _warehouses.first['id'].toString();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('New Bin Location', style: TextStyle(fontSize: 16)),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: selWhId,
            decoration: const InputDecoration(labelText: 'Warehouse *', isDense: true, prefixIcon: Icon(Icons.warehouse, size: 18)),
            isExpanded: true, items: _warehouses.map((w) => DropdownMenuItem(value: w['id'].toString(),
              child: Text('${w['code'] ?? ''} - ${w['name'] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setDlg(() => selWhId = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Bin Code *', isDense: true, hintText: 'e.g. A-01'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true))),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Max Wt', isDense: true), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode', isDense: true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (selWhId == null || codeCtrl.text.trim().isEmpty) { _msg('Warehouse and Code required', isError: true); return; }
            try {
              final body = <String, dynamic>{'warehouse_id': selWhId, 'code': codeCtrl.text.trim().toUpperCase(),
                'name': nameCtrl.text.trim(), 'barcode': barcodeCtrl.text.trim()};
              if (weightCtrl.text.trim().isNotEmpty) body['max_weight_kg'] = double.tryParse(weightCtrl.text);
              final r = await http.post(Uri.parse('http://localhost:8080/api/v1/warehouse/bins'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode(body));
              if (r.statusCode >= 400) throw Exception(jsonDecode(r.body)['message'] ?? 'Failed');
              if (ctx.mounted) Navigator.pop(ctx);
              await _load(); _msg('Bin created');
            } catch (e) { _msg('$e', isError: true); }
          }, child: const Text('Create')),
        ],
      ),
    ));
  }

  void _showEditDialog(dynamic bin) {
    final codeCtrl = TextEditingController(text: bin['code'] ?? '');
    final nameCtrl = TextEditingController(text: bin['name'] ?? '');
    final barcodeCtrl = TextEditingController(text: bin['barcode'] ?? '');
    final weightCtrl = TextEditingController(text: (bin['max_weight_kg'] as num?)?.toString() ?? '');
    final binId = bin['id'].toString();
    String? selWhId = bin['warehouse_id']?.toString();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Edit Bin', style: TextStyle(fontSize: 16)),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: selWhId,
            decoration: const InputDecoration(labelText: 'Warehouse', isDense: true, prefixIcon: Icon(Icons.warehouse, size: 18)),
            isExpanded: true, items: _warehouses.map((w) => DropdownMenuItem(value: w['id'].toString(),
              child: Text('${w['code'] ?? ''} - ${w['name'] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setDlg(() => selWhId = v),
          ),
          const SizedBox(height: 8),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code', isDense: true), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true))),
            const SizedBox(width: 8),
            SizedBox(width: 100, child: TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Max Wt', isDense: true), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode', isDense: true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            try {
              final body = <String, dynamic>{'code': codeCtrl.text.trim().toUpperCase(), 'name': nameCtrl.text.trim(),
                'barcode': barcodeCtrl.text.trim(), 'max_weight_kg': double.tryParse(weightCtrl.text)};
              // Only update warehouse if it changed
              final uri = Uri.parse('http://localhost:8080/api/v1/warehouse/bins/$binId');
              final r = await http.put(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode(body));
              if (r.statusCode >= 400) throw Exception('Update failed');
              if (ctx.mounted) Navigator.pop(ctx);
              await _load(); _msg('Bin updated');
            } catch (e) { _msg('$e', isError: true); }
          }, child: const Text('Save')),
        ],
      ),
    ));
  }

  void _confirmDelete(dynamic bin) {
    final binId = bin['id'].toString();
    final binCode = bin['code'] ?? '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Bin'), content: Text('Delete bin "$binCode"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () async {
          Navigator.pop(ctx);
          try {
            await http.delete(Uri.parse('http://localhost:8080/api/v1/warehouse/bins/$binId'),
              headers: {'Authorization': 'Bearer $_token'});
            await _load(); _msg('Bin $binCode deleted');
          } catch (e) { _msg('$e', isError: true); }
        }, child: const Text('Delete')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {},
      title: 'Bin Locations',
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            // Warehouse filter
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _filterWhId,
                decoration: InputDecoration(
                  labelText: 'Filter by Warehouse',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Warehouses', style: TextStyle(fontSize: 12))),
                  ..._warehouses.map((w) => DropdownMenuItem(value: w['id'].toString(),
                    child: Text('${w['code'] ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))),
                ],
                onChanged: (v) async {
                  setState(() => _filterWhId = v);
                  await _loadBins();
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.search, size: 16)),
                style: const TextStyle(fontSize: 11),
                onSubmitted: (_) async { await _loadBins(); if (mounted) setState(() {}); },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 22, color: Colors.purple),
              onPressed: _showCreateDialog, tooltip: 'New Bin'),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load, tooltip: 'Refresh'),
          ]),
        ),
        const Divider(height: 1),
        // Header
        if (_bins.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), color: Colors.grey.shade100,
            child: Row(children: [
              const SizedBox(width: 24),
              const Expanded(flex: 2, child: Text('Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Warehouse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Site', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const SizedBox(width: 56),
            ]),
          ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bins.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No bin locations found', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: _bins.length,
                itemBuilder: (_, i) => _buildBinRow(_bins[i]),
              ),
        ),
      ]),
    );
  }

  Widget _buildBinRow(dynamic bin) {
    final isActive = bin['is_active'] as bool? ?? true;
    final whCode = bin['warehouse_code'] ?? bin['warehouse_name'] ?? '';
    final siteCode = bin['site_code'] ?? '';
    final siteName = bin['site_name'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.3))),
      child: Row(children: [
        Container(width: 20, height: 20,
          decoration: BoxDecoration(color: isActive ? Colors.blue.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
          child: Icon(Icons.inventory_2, size: 12, color: isActive ? Colors.blue.shade600 : Colors.grey)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Text(bin['code'] ?? '',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'monospace', color: isActive ? null : Colors.grey))),
        Expanded(flex: 3, child: Text(bin['name'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
        Expanded(flex: 2, child: Text(whCode.isNotEmpty ? whCode : '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        Expanded(flex: 2, child: Text(siteCode.isNotEmpty ? '$siteCode - $siteName' : '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
          child: Text(isActive ? 'Active' : 'Inactive',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: isActive ? Colors.green.shade700 : Colors.grey.shade600))),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade400), onPressed: () => _showEditDialog(bin),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete, size: 16, color: Colors.red.shade300), onPressed: () => _confirmDelete(bin),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
      ]),
    );
  }
}
