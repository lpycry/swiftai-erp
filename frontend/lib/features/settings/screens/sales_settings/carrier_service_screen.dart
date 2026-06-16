import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';

class CarrierServiceScreen extends StatefulWidget {
  final AuthService authService;
  const CarrierServiceScreen({super.key, required this.authService});
  @override State<CarrierServiceScreen> createState() => CarrierServiceScreenState();
}

class CarrierServiceScreenState extends State<CarrierServiceScreen> {
  static const String _baseUrl = 'http://localhost:8080/api/v1';
  List<dynamic> _items = [];
  bool _loading = true;

  String get _token => widget.authService.accessToken ?? '';

  /// Grouped by carrier name for display
  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final item in _items) {
      final carrier = item['carrier']?.toString() ?? '';
      map.putIfAbsent(carrier, () => []).add(item);
    }
    // Sort carriers alphabetically
    final sorted = <String, List<dynamic>>{};
    final keys = map.keys.toList()..sort();
    for (final k in keys) {
      sorted[k] = map[k]!;
    }
    return sorted;
  }

  @override void initState() { super.initState(); _load(); }

  void triggerCreate() => _showCreateDialog();
  void triggerRefresh() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/sales/carrier-service-types'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        if (mounted) setState(() => _items = jsonDecode(resp.body)['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CarrierFormDialog(authService: widget.authService),
    );
    if (result != null) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl/sales/carrier-service-types'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
        if (resp.statusCode < 400) { _msg('Created'); _load(); }
        else { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Create failed'); }
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  Future<void> _showEditDialog(dynamic item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CarrierFormDialog(authService: widget.authService, isEdit: true, item: item),
    );
    if (result != null) {
      try {
        final resp = await http.put(
          Uri.parse('$_baseUrl/sales/carrier-service-types/${item['id']}'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
        if (resp.statusCode < 400) { _msg('Updated'); _load(); }
        else { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Update failed'); }
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  Future<void> _confirmDelete(dynamic item) async {
    if (item['is_system'] == true) { _msg('Cannot delete system service type', isError: true); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete "${item['carrier']} — ${item['service_type']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try {
        await http.delete(Uri.parse('$_baseUrl/sales/carrier-service-types/${item['id']}'), headers: {'Authorization': 'Bearer $_token'});
        _msg('Deleted'); _load();
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  /// Carrier-themed color
  Color _carrierColor(String carrier) {
    switch (carrier.toUpperCase()) {
      case 'FEDEX': return Colors.purple.shade700;
      case 'UPS':  return Colors.orange.shade800;
      case 'DHL':  return Colors.red.shade700;
      default:     return Colors.blue;
    }
  }

  IconData _carrierIcon(String carrier) {
    switch (carrier.toUpperCase()) {
      case 'FEDEX': return Icons.local_shipping;
      case 'UPS':  return Icons.local_shipping;
      case 'DHL':  return Icons.flight;
      default:     return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_shipping, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No carrier service types', style: TextStyle(color: Colors.grey.shade500)),
                ]))
            : ListView(
                padding: const EdgeInsets.all(8),
                children: _grouped.entries.map((entry) {
                  final carrier = entry.key;
                  final services = entry.value;
                  final color = _carrierColor(carrier);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_carrierIcon(carrier), color: color, size: 22),
                      ),
                      title: Text(carrier, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                      subtitle: Text('${services.length} service types', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      children: services.map<Widget>((item) {
                        final isSystem = item['is_system'] == true;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 72, right: 8),
                          title: Row(children: [
                            Icon(Icons.circle, size: 6, color: item['is_active'] == true ? Colors.green : Colors.red),
                            const SizedBox(width: 6),
                            Text(item['service_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                            if (isSystem) ...[
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)), child: Text('SYSTEM', style: TextStyle(fontSize: 8, color: Colors.blue.shade600))),
                            ],
                          ]),
                          subtitle: Text('Sort: ${item['sort_order'] ?? 0}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showEditDialog(item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                            if (!isSystem)
                              IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _confirmDelete(item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                          ]),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
  }
}

// ═══════════════════════════════════════════════
//  Create / Edit Form Dialog
// ═══════════════════════════════════════════════

class _CarrierFormDialog extends StatefulWidget {
  final AuthService authService;
  final bool isEdit;
  final dynamic item;
  const _CarrierFormDialog({required this.authService, this.isEdit = false, this.item});
  @override State<_CarrierFormDialog> createState() => _CarrierFormDialogState();
}

class _CarrierFormDialogState extends State<_CarrierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serviceTypeCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();
  final _carrierCtrl = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.item != null) {
      _carrierCtrl.text = widget.item['carrier'] ?? '';
      _serviceTypeCtrl.text = widget.item['service_type'] ?? '';
      _sortCtrl.text = (widget.item['sort_order'] ?? 0).toString();
      _isActive = widget.item['is_active'] == true;
    }
  }

  @override
  void dispose() { _carrierCtrl.dispose(); _serviceTypeCtrl.dispose(); _sortCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        child: Row(children: [
          Icon(Icons.local_shipping, size: 20, color: Colors.indigo.shade700),
          const SizedBox(width: 8),
          Text(widget.isEdit ? 'Edit Carrier Service Type' : 'New Carrier Service Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.indigo.shade800)),
        ]),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _carrierCtrl,
              decoration: const InputDecoration(labelText: 'Carrier *', isDense: true, hintText: 'e.g. FedEx, UPS, DHL, Canada Post'),
              style: const TextStyle(fontSize: 12),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _serviceTypeCtrl,
              decoration: const InputDecoration(labelText: 'Service Type *', isDense: true, hintText: 'e.g. Ground, Express, Priority Overnight'),
              style: const TextStyle(fontSize: 12),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _sortCtrl, decoration: const InputDecoration(labelText: 'Sort Order', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(width: 24, height: 24, child: Checkbox(value: _isActive, onChanged: (v) => setState(() => _isActive = v ?? true))),
              const SizedBox(width: 4),
              const Text('Active', style: TextStyle(fontSize: 12)),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        ElevatedButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, {
              'carrier': _carrierCtrl.text.trim(),
              'service_type': _serviceTypeCtrl.text.trim(),
              'is_active': _isActive,
              'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
            });
          }
        }, child: Text(widget.isEdit ? 'Update' : 'Create', style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
