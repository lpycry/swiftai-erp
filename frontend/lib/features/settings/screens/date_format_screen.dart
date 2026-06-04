import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/settings/services/date_format_service.dart';

class DateFormatScreen extends StatefulWidget {
  final AuthService authService;
  final DateFormatService dateFormatService;
  const DateFormatScreen({super.key, required this.authService, required this.dateFormatService});
  @override
  State<DateFormatScreen> createState() => _DateFormatScreenState();
}

class _DateFormatScreenState extends State<DateFormatScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try { final data = await widget.dateFormatService.getDateFormats(); if (mounted) setState(() => _items = data); }
    catch (e) { if (mounted) _msg('Failed to load: $e', isError: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  Future<void> _setActive(dynamic item) async {
    try {
      await widget.dateFormatService.activateDateFormat(item['id'].toString());
      _load();
      _msg('${item['display_name']} set as active');
    } catch (e) { _msg('$e', isError: true); }
  }

  void _showForm({Map<String, dynamic>? edit}) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: edit?['format_code'] ?? '');
    final nameCtrl = TextEditingController(text: edit?['display_name'] ?? '');
    final patternCtrl = TextEditingController(text: edit?['date_pattern'] ?? '');
    final sepCtrl = TextEditingController(text: edit?['separator'] ?? '.');
    final exampleCtrl = TextEditingController(text: edit?['example_output'] ?? '');
    final orderCtrl = TextEditingController(text: '${edit?['sort_order'] ?? 0}');
    bool isActive = edit?['is_active'] as bool? ?? false;
    bool isEditing = edit != null;
    final editId = edit?['id']?.toString();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      title: Text(isEditing ? 'Edit Date Format' : 'New Date Format'),
      content: SizedBox(width: 420, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!isEditing)
          TextFormField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code *', hintText: 'DD_MM_YYYY'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        if (!isEditing) const SizedBox(height: 10),
        TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name *', hintText: 'DD.MM.YYYY'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 10),
        TextFormField(controller: patternCtrl, decoration: const InputDecoration(labelText: 'Date Pattern *', hintText: 'dd.MM.yyyy'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: sepCtrl, decoration: const InputDecoration(labelText: 'Separator', hintText: '.'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: TextFormField(controller: exampleCtrl, decoration: const InputDecoration(labelText: 'Example', hintText: '31.12.2026'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 100, child: TextFormField(controller: orderCtrl, decoration: const InputDecoration(labelText: 'Sort', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
          const Spacer(),
          CheckboxListTile(value: isActive, onChanged: (v) => setDlg(() => isActive = v ?? false), title: const Text('Active', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        ]),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (!formKey.currentState!.validate()) return;
          try {
            final data = <String, dynamic>{
              if (!isEditing) 'format_code': codeCtrl.text,
              'display_name': nameCtrl.text,
              'date_pattern': patternCtrl.text,
              'separator': sepCtrl.text,
              'example_output': exampleCtrl.text,
              'sort_order': int.tryParse(orderCtrl.text) ?? 0,
              'is_active': isActive,
            };
            if (isEditing) { await widget.dateFormatService.updateDateFormat(editId!, data); }
            else { await widget.dateFormatService.createDateFormat(data); }
            if (ctx.mounted) Navigator.pop(ctx); _load();
            _msg(isEditing ? 'Updated' : 'Created');
          } catch (e) { _msg('$e', isError: true); }
        }, child: Text(isEditing ? 'Save' : 'Create')),
      ],
    )));
  }

  Future<void> _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Date Format'),
      content: Text('Delete "${item['display_name']}"?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok == true) { try { await widget.dateFormatService.deleteDateFormat(item['id'].toString()); _load(); _msg('Deleted'); } catch (e) { _msg('$e', isError: true); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Date Formats'), actions: [
        IconButton(icon: const Icon(Icons.add, color: AppTheme.primaryColor), onPressed: () => _showForm()),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8), Text('No date formats', style: TextStyle(color: Colors.grey.shade500)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (_, i) => _DFCard(
                key: ValueKey(_items[i]['id']),
                item: _items[i],
                isSingleActive: _items.where((e) => e['is_active'] == true).length <= 1,
                onEdit: () => _showForm(edit: _items[i]),
                onDelete: () => _confirmDelete(_items[i]),
                onSetActive: () => _setActive(_items[i]),
              ),
            ),
    );
  }
}

class _DFCard extends StatelessWidget {
  final dynamic item; final bool isSingleActive;
  final VoidCallback onEdit, onDelete, onSetActive;
  const _DFCard({super.key, required this.item, required this.isSingleActive, required this.onEdit, required this.onDelete, required this.onSetActive});

  @override
  Widget build(BuildContext context) {
    final isActive = item['is_active'] as bool? ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: isActive ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: isActive ? Colors.blue : Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
          child: Icon(isActive ? Icons.check_circle : Icons.circle_outlined, size: 18, color: isActive ? Colors.white : Colors.grey)),
        title: Row(children: [
          Text(item['display_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'monospace', color: isActive ? Colors.blue.shade800 : null)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)),
            child: Text(item['example_output'] ?? '', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontFamily: 'monospace'))),
          if (isActive) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(3)),
            child: Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)))],
        ]),
        subtitle: Row(children: [
          Text(item['format_code'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          if (item['date_pattern'] != null) Text('Pattern: ${item['date_pattern']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          const Spacer(),
          Text('Sort: ${item['sort_order'] ?? 0}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!isActive)
            IconButton(icon: Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade600), onPressed: onSetActive, tooltip: 'Set Active', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400), onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
      ),
    );
  }
}
