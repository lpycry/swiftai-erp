import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';

class DeliveryBlockScreen extends StatefulWidget {
  final AuthService authService;
  const DeliveryBlockScreen({super.key, required this.authService});
  @override State<DeliveryBlockScreen> createState() => DeliveryBlockScreenState();
}

class DeliveryBlockScreenState extends State<DeliveryBlockScreen> {
  static const String _baseUrl = 'http://localhost:8080/api/v1';
  List<dynamic> _items = [];
  bool _loading = true;

  String get _token => widget.authService.accessToken ?? '';

  @override void initState() { super.initState(); _load(); }

  void triggerCreate() => _showCreateDialog();
  void triggerRefresh() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/sales/delivery-blocks'), headers: {'Authorization': 'Bearer $_token'});
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
      builder: (_) => _BlockFormDialog(authService: widget.authService),
    );
    if (result != null) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl/sales/delivery-blocks'),
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
      builder: (_) => _BlockFormDialog(authService: widget.authService, isEdit: true, item: item),
    );
    if (result != null) {
      try {
        final resp = await http.put(
          Uri.parse('$_baseUrl/sales/delivery-blocks/${item['id']}'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
        if (resp.statusCode < 400) { _msg('Updated'); _load(); }
        else { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Update failed'); }
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  Future<void> _confirmDelete(dynamic item) async {
    if (item['is_system'] == true) { _msg('Cannot delete system block', isError: true); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete'), content: Text('Delete "${item['block_code']} — ${item['description']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try {
        await http.delete(Uri.parse('$_baseUrl/sales/delivery-blocks/${item['id']}'), headers: {'Authorization': 'Bearer $_token'});
        _msg('Deleted'); _load();
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.block, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No delivery blocks', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final isSystem = item['is_system'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: (item['is_active'] == true ? Colors.red : Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text(item['block_code'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade600, fontFamily: 'monospace'))),
                        ),
                        title: Row(children: [
                          Text(item['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          if (isSystem) ...[
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)), child: Text('SYSTEM', style: TextStyle(fontSize: 8, color: Colors.blue.shade600))),
                          ],
                        ]),
                        subtitle: Row(children: [
                          Icon(Icons.circle, size: 6, color: item['is_active'] == true ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text(item['is_active'] == true ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Text('Sort: ${item['sort_order'] ?? 0}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showEditDialog(item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                          if (!isSystem)
                            IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _confirmDelete(item), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                        ]),
                      ),
                    );
                  },
                );
  }
}

// ═══════════════════════════════════════════════
//  Create / Edit Form Dialog
// ═══════════════════════════════════════════════

class _BlockFormDialog extends StatefulWidget {
  final AuthService authService;
  final bool isEdit;
  final dynamic item;
  const _BlockFormDialog({required this.authService, this.isEdit = false, this.item});
  @override State<_BlockFormDialog> createState() => _BlockFormDialogState();
}

class _BlockFormDialogState extends State<_BlockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();

  @override void initState() {
    super.initState();
    if (widget.isEdit && widget.item != null) {
      _descCtrl.text = widget.item['description'] ?? '';
      _sortCtrl.text = (widget.item['sort_order'] ?? 0).toString();
    }
  }

  @override void dispose() { _codeCtrl.dispose(); _descCtrl.dispose(); _sortCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        child: Row(children: [
          Icon(Icons.block, size: 20, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text(widget.isEdit ? 'Edit Delivery Block' : 'New Delivery Block', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
        ]),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!widget.isEdit)
              TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Block Code *', isDense: true, hintText: 'e.g. 07'), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true, hintText: 'Reason for delivery block'), style: const TextStyle(fontSize: 12), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _sortCtrl, decoration: const InputDecoration(labelText: 'Sort Order', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        ElevatedButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, {
              'block_code': widget.isEdit ? widget.item['block_code'] : _codeCtrl.text.trim(),
              'description': _descCtrl.text.trim(),
              'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
            });
          }
        }, child: Text(widget.isEdit ? 'Update' : 'Create', style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
