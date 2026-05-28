import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

/// Org Detail Screen — Tree view of Org → Sites → Warehouses → Bins
/// Replaces the simple SitesScreen with full organizational structure

class OrgDetailScreen extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;
  final WarehouseService warehouseService;
  final String orgId;
  final String orgCode;
  final String orgName;
  final String orgCurrency;

  const OrgDetailScreen({
    super.key,
    required this.authService,
    required this.orgService,
    required this.warehouseService,
    required this.orgId,
    required this.orgCode,
    required this.orgName,
    required this.orgCurrency,
  });

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen> {
  bool _loading = true;
  List<dynamic> _sites = [];
  List<Map<String, dynamic>> _warehouses = [];
  final Map<String, List<dynamic>> _binsByWh = {};
  final Set<String> _expandedSites = {};
  final Set<String> _expandedWhs = {};

  @override
  void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sites = await widget.orgService.getSitesByOrg(widget.orgId);
      final whs = await widget.warehouseService.listWarehouses();
      _warehouses = whs.cast<Map<String, dynamic>>();

      // Load bins for each warehouse under this org
      final orgSiteIds = _sites.map((s) => s['id'].toString()).toSet();
      for (final wh in _warehouses) {
        final whSiteId = wh['site_id']?.toString() ?? '';
        final whOrgId = wh['organization_id']?.toString() ?? '';
        if (orgSiteIds.contains(whSiteId) || whOrgId == widget.orgId) {
          await _loadBins(wh['id'].toString());
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _msg('Failed to load: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBins(String whId) async {
    try {
      final r = await http.get(
        Uri.parse('http://localhost:8080/api/v1/warehouse/bins?warehouse_id=$whId'),
        headers: {'Authorization': 'Bearer $_token'});
      if (r.statusCode < 400) {
        _binsByWh[whId] = (jsonDecode(r.body)['data'] as List<dynamic>?) ?? [];
      }
    } catch (_) {}
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? AppTheme.errorColor : Colors.green,
    ));
  }

  List<dynamic> _whsForSite(String siteId) =>
      _warehouses.where((w) => (w['site_id']?.toString() ?? '') == siteId).toList();

  // ═══════════════════════════════════════
  //  Dialogs — Site CRUD
  // ═══════════════════════════════════════

  void _showCreateSiteDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String siteType = 'warehouse';
    final addressCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Add Site'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'e.g. WH01'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Main Warehouse')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: siteType, decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
              DropdownMenuItem(value: 'plant', child: Text('Plant / Factory')),
              DropdownMenuItem(value: 'store', child: Text('Store / Retail')),
              DropdownMenuItem(value: 'office', child: Text('Office')),
            ], onChanged: (v) => setDlg(() => siteType = v!)),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
            try {
              await widget.orgService.createSite({
                'organization_id': widget.orgId, 'site_code': codeCtrl.text,
                'site_name': nameCtrl.text, 'site_type': siteType, 'address': addressCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _load(); _msg('Site created');
            } catch (e) { _msg('$e', isError: true); }
          }, child: const Text('Create')),
        ],
      ),
    ));
  }

  void _showEditSiteDialog(dynamic site) {
    final nameCtrl = TextEditingController(text: site['site_name'] ?? '');
    String siteType = site['site_type'] ?? 'warehouse';
    final addressCtrl = TextEditingController(text: site['address'] ?? '');
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Edit Site'), content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: siteType, decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
              DropdownMenuItem(value: 'plant', child: Text('Plant / Factory')),
              DropdownMenuItem(value: 'store', child: Text('Store / Retail')),
              DropdownMenuItem(value: 'office', child: Text('Office')),
            ], onChanged: (v) => setDlg(() => siteType = v!)),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            try {
              await widget.orgService.updateSite(site['id'], {'site_name': nameCtrl.text, 'site_type': siteType, 'address': addressCtrl.text});
              if (ctx.mounted) Navigator.pop(ctx);
              await _load(); _msg('Site updated');
            } catch (e) { _msg('$e', isError: true); }
          }, child: const Text('Save')),
        ],
      ),
    ));
  }

  Future<void> _confirmDeleteSite(dynamic site) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Site'), content: Text('Delete "${site['site_code']} ${site['site_name']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try { await widget.orgService.deleteSite(site['id']); await _load(); _msg('Site deleted'); }
      catch (e) { _msg('$e', isError: true); }
    }
  }

  // ═══════════════════════════════════════
  //  Dialogs — Warehouse CRUD
  // ═══════════════════════════════════════

  void _showCreateWhDialog({String? siteId}) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String? selSiteId = siteId;
    String? error;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Row(children: [Icon(Icons.add_business, size: 20), SizedBox(width: 8), Text('New Warehouse', style: TextStyle(fontSize: 16))]),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl, decoration: InputDecoration(labelText: 'Code *', isDense: true, hintText: 'e.g. WH-MAIN', errorText: error, prefixIcon: Icon(Icons.tag, size: 18)),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', isDense: true, prefixIcon: Icon(Icons.business, size: 18))),
          const SizedBox(height: 8),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', isDense: true, prefixIcon: Icon(Icons.location_on, size: 18)), maxLines: 2),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selSiteId,
            decoration: const InputDecoration(labelText: 'Site (Plant)', isDense: true, prefixIcon: Icon(Icons.store, size: 18)),
            isExpanded: true, items: _sites.map((s) => DropdownMenuItem(value: s['id'].toString(),
              child: Text('${s['site_code'] ?? ''} - ${s['site_name'] ?? ''}', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setDlg(() => selSiteId = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(icon: const Icon(Icons.add, size: 16), onPressed: () async {
            if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
              setDlg(() => error = 'Code and Name required'); return;
            }
            final dup = _warehouses.any((w) => (w['code'] ?? '').toString().toUpperCase() == codeCtrl.text.trim().toUpperCase());
            if (dup) { setDlg(() => error = 'Code exists'); return; }
            try {
              await widget.warehouseService.createWarehouse({
                'code': codeCtrl.text.trim().toUpperCase(), 'name': nameCtrl.text.trim(),
                'address': addrCtrl.text.trim(), 'organization_id': widget.orgId, 'site_id': selSiteId,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _load(); _msg('Warehouse created');
            } catch (e) { _msg('$e', isError: true); }
          }, label: const Text('Create')),
        ],
      ),
    ));
  }

  void _showEditWhDialog(Map<String, dynamic> wh) {
    final codeCtrl = TextEditingController(text: wh['code'] ?? '');
    final nameCtrl = TextEditingController(text: wh['name'] ?? '');
    final addrCtrl = TextEditingController(text: wh['address'] ?? '');
    final whId = wh['id'].toString();
    String? selSiteId = wh['site_id']?.toString();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit Warehouse', style: TextStyle(fontSize: 16))]),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code', isDense: true, prefixIcon: Icon(Icons.tag, size: 18)),
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true, prefixIcon: Icon(Icons.business, size: 18))),
        const SizedBox(height: 8),
        TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', isDense: true, prefixIcon: Icon(Icons.location_on, size: 18)), maxLines: 2),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selSiteId,
          decoration: const InputDecoration(labelText: 'Site', isDense: true, prefixIcon: Icon(Icons.store, size: 18)),
          isExpanded: true, items: [const DropdownMenuItem(value: null, child: Text('(none)', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ..._sites.map((s) => DropdownMenuItem(value: s['id'].toString(),
              child: Text('${s['site_code'] ?? ''} - ${s['site_name'] ?? ''}', style: const TextStyle(fontSize: 12)))).toList()],
          onChanged: (v) => selSiteId = v,
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          try {
            await widget.warehouseService.updateWarehouse(whId, {
              'code': codeCtrl.text.trim().toUpperCase(), 'name': nameCtrl.text.trim(),
              'address': addrCtrl.text.trim(), 'site_id': selSiteId,
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await _load(); _msg('Warehouse updated');
          } catch (e) { _msg('$e', isError: true); }
        }, child: const Text('Save')),
      ],
    ));
  }

  void _confirmDeleteWh(Map<String, dynamic> wh) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.warning_amber, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete Warehouse', style: TextStyle(fontSize: 16))]),
      content: Text('Delete "${wh['code']}"? Fails if stock exists.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () async {
          Navigator.pop(ctx);
          try { await widget.warehouseService.deleteWarehouse(wh['id'].toString()); await _load(); _msg('Deleted'); }
          catch (e) { _msg('$e', isError: true); }
        }, child: const Text('Delete')),
      ],
    ));
  }

  // ═══════════════════════════════════════
  //  Dialogs — Bin CRUD
  // ═══════════════════════════════════════

  void _showCreateBinDialog(String whId) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New Bin'), content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code *', isDense: true, hintText: 'e.g. A-01'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (codeCtrl.text.trim().isEmpty) return;
          try {
            final r = await http.post(Uri.parse('http://localhost:8080/api/v1/warehouse/bins'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
              body: jsonEncode({'warehouse_id': whId, 'code': codeCtrl.text.trim().toUpperCase(), 'name': nameCtrl.text.trim()}));
            if (r.statusCode >= 400) throw Exception(jsonDecode(r.body)['message'] ?? 'Failed');
            if (ctx.mounted) Navigator.pop(ctx);
            await _load(); _msg('Bin created');
          } catch (e) { _msg('$e', isError: true); }
        }, child: const Text('Create')),
      ],
    ));
  }

  void _showEditBinDialog(dynamic bin, String whId) {
    final codeCtrl = TextEditingController(text: bin['code'] ?? '');
    final nameCtrl = TextEditingController(text: bin['name'] ?? '');
    final binId = bin['id'].toString();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Bin'), content: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code', isDense: true), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          try {
            await http.put(Uri.parse('http://localhost:8080/api/v1/warehouse/bins/$binId'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
              body: jsonEncode({'code': codeCtrl.text.trim().toUpperCase(), 'name': nameCtrl.text.trim()}));
            if (ctx.mounted) Navigator.pop(ctx);
            await _load(); _msg('Bin updated');
          } catch (e) { _msg('$e', isError: true); }
        }, child: const Text('Save')),
      ],
    ));
  }

  void _confirmDeleteBin(String binId, String binCode, String whId) {
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

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.orgName, style: const TextStyle(fontSize: 18)),
        Text('${widget.orgCode} · ${widget.orgCurrency} · ${_sites.length} site(s)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ])),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            // Sites
            ..._sites.map((site) => _buildSiteNode(site)),
            // Orphan warehouses (no site)
            ..._buildOrphanWhs(),
            // Create site button
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                onPressed: _showCreateSiteDialog,
                label: const Text('Add Site'),
              ),
            ),
          ]),
    );
  }

  Widget _buildSiteNode(dynamic site) {
    final siteId = site['id'].toString();
    final siteCode = site['site_code'] ?? '';
    final siteName = site['site_name'] ?? '';
    final siteType = site['site_type'] ?? 'warehouse';
    final whs = _whsForSite(siteId);
    final expanded = _expandedSites.contains(siteId);

    IconData icon;
    Color color;
    switch (siteType) {
      case 'plant': icon = Icons.factory; color = Colors.orange; break;
      case 'store': icon = Icons.store; color = Colors.green; break;
      case 'office': icon = Icons.business; color = Colors.purple; break;
      default: icon = Icons.warehouse; color = Colors.blue;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() { if (expanded) _expandedSites.remove(siteId); else _expandedSites.add(siteId); }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 10),
            Text(siteCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Text(siteName, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const Spacer(),
            Text('${whs.length} wh', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.grey), onPressed: () => _showEditSiteDialog(site),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            IconButton(icon: Icon(Icons.delete, size: 16, color: Colors.red.shade300), onPressed: () => _confirmDeleteSite(site),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          ]),
        ),
      ),
      if (expanded) ...[
        // Add warehouse button
        Padding(
          padding: const EdgeInsets.only(left: 56, top: 4, bottom: 2),
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            onPressed: () => _showCreateWhDialog(siteId: siteId),
            label: Text('Warehouse', style: TextStyle(fontSize: 11, color: Colors.purple.shade600)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ),
        ...whs.map((wh) => _buildWhNode(wh, siteId)),
      ],
    ]);
  }

  Widget _buildWhNode(Map<String, dynamic> wh, String siteId) {
    final whId = wh['id'].toString();
    final whCode = wh['code'] ?? '';
    final whName = wh['name'] ?? '';
    final bins = _binsByWh[whId] ?? [];
    final expanded = _expandedWhs.contains(whId);

    return Container(
      margin: const EdgeInsets.only(left: 56),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade50))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() { if (expanded) _expandedWhs.remove(whId); else _expandedWhs.add(whId); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Icon(Icons.warehouse, size: 14, color: Colors.purple.shade600),
              const SizedBox(width: 4),
              Text(whCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              const SizedBox(width: 6),
              Expanded(child: Text(whName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
              Text('${bins.length} bins', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.add, size: 14, color: Colors.blue), onPressed: () => _showCreateBinDialog(whId),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
              IconButton(icon: Icon(Icons.edit, size: 14, color: Colors.blue.shade300), onPressed: () => _showEditWhDialog(wh),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
              IconButton(icon: Icon(Icons.delete, size: 14, color: Colors.red.shade300), onPressed: () => _confirmDeleteWh(wh),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
            ]),
          ),
        ),
        if (expanded) ...bins.map((b) => _buildBinNode(b, whId)),
      ]),
    );
  }

  Widget _buildBinNode(dynamic bin, String whId) {
    final isActive = bin['is_active'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(left: 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(Icons.inventory_2, size: 12, color: isActive ? Colors.blue.shade400 : Colors.grey),
        const SizedBox(width: 6),
        Text(bin['code'] ?? '', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: isActive ? null : Colors.grey)),
        const SizedBox(width: 6),
        Expanded(child: Text(bin['name'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
        IconButton(icon: Icon(Icons.edit, size: 12, color: Colors.grey.shade400), onPressed: () => _showEditBinDialog(bin, whId),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
        IconButton(icon: Icon(Icons.delete, size: 12, color: Colors.red.shade200), onPressed: () => _confirmDeleteBin(bin['id'].toString(), bin['code'] ?? '', whId),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
      ]),
    );
  }

  List<Widget> _buildOrphanWhs() {
    final orphans = _warehouses.where((w) {
      final sId = w['site_id']?.toString() ?? '';
      final oId = w['organization_id']?.toString() ?? '';
      return oId == widget.orgId && !_sites.any((s) => s['id'].toString() == sId);
    }).toList();
    if (orphans.isEmpty) return [];
    return [
      Container(
        padding: const EdgeInsets.all(12),
        color: Colors.orange.shade50,
        child: Row(children: [
          Icon(Icons.warning_amber, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Unlinked Warehouses', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
        ]),
      ),
      ...orphans.map((wh) => Container(
        margin: const EdgeInsets.only(left: 16),
        child: _buildWhNode(wh, ''),
      )),
    ];
  }
}
