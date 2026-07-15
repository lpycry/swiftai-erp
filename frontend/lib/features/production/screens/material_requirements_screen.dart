import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class MaterialRequirementsScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;

  const MaterialRequirementsScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  State<MaterialRequirementsScreen> createState() =>
      _MaterialRequirementsScreenState();
}

class _MaterialRequirementsScreenState
    extends State<MaterialRequirementsScreen> {
  static const _baseUrl = 'http://localhost:8080/api/v1';

  bool _loading = true;
  bool _loadingList = false;
  List<dynamic> _products = [];
  List<dynamic> _sites = [];
  String? _productId;
  String? _siteId;
  Map<String, dynamic>? _requirements;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _loading = true);
    try {
      final headers = {
        'Authorization': 'Bearer ${widget.authService.accessToken}',
      };
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/warehouse/products'), headers: headers),
        http.get(Uri.parse('$_baseUrl/sites'), headers: headers),
      ]);
      final products = results[0].statusCode < 400
          ? (jsonDecode(results[0].body)['data'] as List<dynamic>? ?? [])
          : <dynamic>[];
      final allSites = results[1].statusCode < 400
          ? (jsonDecode(results[1].body)['data'] as List<dynamic>? ?? [])
          : <dynamic>[];
      final plants = allSites
          .where((s) => (s['site_type'] ?? '').toString() == 'plant')
          .toList();
      if (!mounted) return;
      setState(() {
        _products = products;
        _sites = plants.isEmpty ? allSites : plants;
        _productId ??= _products.isNotEmpty
            ? _products.first['id']?.toString()
            : null;
        _siteId ??= _sites.isNotEmpty ? _sites.first['id']?.toString() : null;
      });
      await _loadRequirements();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRequirements() async {
    if (_productId == null) return;
    setState(() => _loadingList = true);
    try {
      final data = await widget.productionService.getMaterialRequirementsList(
        productId: _productId!,
        siteId: _siteId,
      );
      if (mounted) setState(() => _requirements = data);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingList = false);
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

  String _fmt(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  String _selectedProductLabel() {
    if (_requirements == null) return '';
    return '${_requirements!['product_sku'] ?? ''} - ${_requirements!['product_name'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_requirements?['elements'] as List<dynamic>? ?? []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials Request List'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingList ? null : _loadRequirements,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
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
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _siteId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Plant',
                                prefixIcon: Icon(Icons.factory_outlined),
                              ),
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
                              onChanged: (v) async {
                                setState(() => _siteId = v);
                                await _loadRequirements();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _loadingList ? null : _loadRequirements,
                            icon: _loadingList
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search, size: 18),
                            label: const Text('Display'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_requirements != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              _headerValue(
                                'Description',
                                _selectedProductLabel(),
                              ),
                              _headerValue(
                                'MRP Type',
                                _requirements!['mrp_type']?.toString() ?? '',
                              ),
                              _headerValue(
                                'Material Type',
                                _requirements!['material_type']?.toString() ??
                                    '',
                              ),
                              _headerValue(
                                'Unit',
                                _requirements!['base_uom']?.toString() ?? '',
                              ),
                              _headerValue(
                                'Stock Qty',
                                _fmt(_requirements!['stock_qty']),
                              ),
                              _headerValue(
                                'Available Qty',
                                _fmt(_requirements!['available_qty']),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _loadingList
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                      ? const Center(child: Text('No requirements found'))
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowHeight: 36,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 52,
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('MRP Element')),
                                DataColumn(label: Text('MRP Element Data')),
                                DataColumn(label: Text('Receipt/Reqmt')),
                                DataColumn(label: Text('Available Qty')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: rows.map((raw) {
                                final row = Map<String, dynamic>.from(
                                  raw as Map,
                                );
                                final receipt =
                                    (row['receipt_qty'] as num?)?.toDouble() ??
                                    0;
                                final req =
                                    (row['requirement_qty'] as num?)
                                        ?.toDouble() ??
                                    0;
                                final qtyText = receipt > 0
                                    ? _fmt(receipt)
                                    : req > 0
                                    ? '${_fmt(req)}-'
                                    : '';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(row['date']?.toString() ?? ''),
                                    ),
                                    DataCell(
                                      Text(
                                        row['mrp_element']?.toString() ?? '',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        row['element_data']?.toString() ?? '',
                                      ),
                                    ),
                                    DataCell(Text(qtyText)),
                                    DataCell(Text(_fmt(row['available_qty']))),
                                    DataCell(
                                      Text(row['status']?.toString() ?? ''),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _headerValue(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
