import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/hr/services/employee_service.dart';
import 'package:swiftai_erp/features/hr/services/position_service.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final AuthService authService;
  final EmployeeService employeeService;
  final String employeeId;
  final String employeeCode;
  final String employeeName;

  const EmployeeDetailScreen({
    super.key, required this.authService, required this.employeeService,
    required this.employeeId, required this.employeeCode, required this.employeeName,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Map<String, dynamic>? _base;
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await widget.employeeService.getEmployeeDetail(widget.employeeId);
      final history = await widget.employeeService.getDataHistory(widget.employeeId);
      setState(() { _base = detail['base']; _history = history; });
    } catch (e) {
      if (mounted) _msg('Failed to load: $e', isError: true);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? AppTheme.errorColor : Colors.green,
    ));
  }

  void _showEditDialog() {
    showDialog(context: context, builder: (_) => _BaseEditDialog(
      authService: widget.authService,
      employeeId: widget.employeeId,
      base: _base,
      onSave: (data) async {
        await widget.employeeService.updateEmployee(widget.employeeId, data);
        _load();
        _msg('Employee updated');
      },
    ));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Employee'),
      content: Text('Delete ${widget.employeeCode} — ${widget.employeeName}?\nThis will also remove all Infotype history records.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try {
        await widget.employeeService.deleteEmployee(widget.employeeId);
        _msg('Employee deleted');
        if (mounted) Navigator.pop(context);
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  // ══════════════ Infotype Dialogs ══════════════

  void _showCreateInfotype(String infotypeCode) {
    final fromCtrl = TextEditingController(text: _today());
    final toCtrl = TextEditingController();
    final payload = <String, dynamic>{};

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget body;
      if (infotypeCode == 'POS_ASSIGN') {
        body = _PosAssignForm(payload: payload, authService: widget.authService);
      } else if (infotypeCode == 'SALARY') {
        body = _SalaryForm(payload: payload);
      } else if (infotypeCode == 'ADDRESS') {
        body = _AddressForm(payload: payload);
      } else if (infotypeCode == 'CONTACT') {
        body = _ContactForm(payload: payload);
      } else {
        body = Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Text('$infotypeCode Data', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
              decoration: const InputDecoration(labelText: 'JSON data'),
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              onChanged: (v) {
                try { final j = jsonDecode(v); if (j is Map) { payload.clear(); payload.addAll(j as Map<String, dynamic>); } } catch (_) {}
              },
            ),
          ]),
        );
      }
      return AlertDialog(
        title: Text('New $infotypeCode'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              body,
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'Valid From', hintText: 'YYYY-MM-DD'), style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Valid To (opt)', hintText: 'blank = open'), style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            try {
              await widget.employeeService.createDataHistory({
                'employee_id': widget.employeeId,
                'infotype_code': infotypeCode,
                'data_payload': payload,
                'valid_from': fromCtrl.text,
                'valid_to': toCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
              _msg('$infotypeCode record created');
            } catch (e) { _msg('$e', isError: true); }
          }, child: const Text('Create')),
        ],
      );
    }));
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Color _infotypeColor(String code) {
    switch (code) {
      case 'POS_ASSIGN': return Colors.indigo;
      case 'SALARY': return Colors.green;
      case 'ADDRESS': return Colors.orange;
      case 'CONTACT': return Colors.blue;
      case 'EDUCATION': return Colors.purple;
      case 'CERTIFICATION': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.employeeCode} — ${widget.employeeName}'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _showEditDialog, tooltip: 'Edit'),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _confirmDelete, tooltip: 'Delete'),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: _showCreateInfotype,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'POS_ASSIGN', child: ListTile(leading: Icon(Icons.work_outline, size: 18), title: Text('Position Assignment'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'SALARY', child: ListTile(leading: Icon(Icons.attach_money, size: 18), title: Text('Salary'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'ADDRESS', child: ListTile(leading: Icon(Icons.location_on_outlined, size: 18), title: Text('Address'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'CONTACT', child: ListTile(leading: Icon(Icons.contact_phone_outlined, size: 18), title: Text('Contact'), dense: true, contentPadding: EdgeInsets.zero)),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [Icon(Icons.add, size: 18), Text('Info Type')]),
            ),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        // Base info
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Employee Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const Divider(),
          _infoRow('Code', widget.employeeCode),
          _infoRow('First Name', _base?['first_name'] ?? ''),
          _infoRow('Middle Name', _base?['middle_name'] ?? ''),
          _infoRow('Last Name', _base?['last_name'] ?? ''),
          _infoRow('Email', _base?['email'] ?? ''),
          _infoRow('Phone', _base?['phone'] ?? ''),
          _infoRow('Worker Type', _base?['worker_type'] ?? 'Regular'),
          _infoRow('Hire Date', _base?['hire_date'] ?? ''),
          _infoRow('Birth Date', _base?['date_of_birth'] ?? ''),
          _infoRow('Tax ID', _base?['tax_id'] ?? ''),
          _infoRow('Status', (_base?['is_active'] == true) ? 'Active' : 'Inactive'),
        ]))),
        const SizedBox(height: 16),

        // Infotype timeline
        Text('Data History (Infotype Timeline)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            Icon(Icons.history, size: 36, color: Colors.grey.shade300), const SizedBox(height: 8),
            Text('No history records', style: TextStyle(color: Colors.grey.shade500)),
          ])))
        else
          ..._buildGroupedHistory(),
      ])),
    );
  }

  List<Widget> _buildGroupedHistory() {
    final grouped = <String, List<dynamic>>{};
    for (final rec in _history) {
      final code = rec['infotype_code'] as String? ?? '';
      grouped.putIfAbsent(code, () => []).add(rec);
    }
    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final code = entry.key;
      final records = entry.value;
      final color = _infotypeColor(code);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(code, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
          const Spacer(),
          Text('${records.length} record(s)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ));
      for (final rec in records) {
        final payload = rec['data_payload'] as Map<String, dynamic>? ?? {};
        final vf = _cleanDate(rec['valid_from']);
        final vt = _cleanDate(rec['valid_to']);
        final isCurrent = vt.isEmpty || vt == '9999-12-31';
        widgets.add(Card(
          margin: const EdgeInsets.only(left: 16, bottom: 4),
          child: ListTile(
            dense: true,
            title: Text(_payloadSummary(code, payload), style: const TextStyle(fontSize: 13)),
            subtitle: Row(children: [
              Text('$vf \u2192 $vt', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(3)),
                  child: Text('Current', style: TextStyle(fontSize: 9, color: Colors.green.shade700))),
              ],
            ]),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Delete Record'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ));
                  if (ok == true) {
                    try {
                      await widget.employeeService.deleteDataHistory(rec['record_id']);
                      _load();
                      _msg('Record deleted');
                    } catch (e) { _msg('$e', isError: true); }
                  }
                }
              },
              itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))],
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  String _payloadSummary(String code, Map<String, dynamic> p) {
    switch (code) {
      case 'POS_ASSIGN': return '${p['position_code'] ?? p['position_id'] ?? ''} — ${p['job_title'] ?? ''}';
      case 'SALARY': return '${p['salary_amount'] ?? ''} ${p['salary_currency'] ?? ''} / ${p['pay_frequency'] ?? ''}';
      case 'ADDRESS': return '${p['street'] ?? ''}, ${p['city'] ?? ''}, ${p['country'] ?? ''}';
      case 'CONTACT': return '${p['email'] ?? ''}  ${p['phone'] ?? ''}';
      default: return p.toString();
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]));
  }

  String _cleanDate(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }
}

// ═══════════════════════════════════════
//  Base Edit Dialog (from detail screen)
// ═══════════════════════════════════════

class _BaseEditDialog extends StatefulWidget {
  final AuthService authService;
  final String employeeId;
  final Map<String, dynamic>? base;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _BaseEditDialog({required this.authService, required this.employeeId, required this.base, required this.onSave});
  @override
  State<_BaseEditDialog> createState() => _BaseEditDialogState();
}

class _BaseEditDialogState extends State<_BaseEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fnCtrl = TextEditingController();
  final _mnCtrl = TextEditingController();
  final _lnCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();
  final _emerRelationCtrl = TextEditingController();
  final _emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$');
  bool _saving = false;
  bool _isActive = true;
  String _workerType = 'Regular';

  @override
  void initState() {
    super.initState();
    final b = widget.base;
    _fnCtrl.text = b?['first_name'] ?? '';
    _mnCtrl.text = b?['middle_name'] ?? '';
    _lnCtrl.text = b?['last_name'] ?? '';
    _emailCtrl.text = b?['email'] ?? '';
    _phoneCtrl.text = b?['phone'] ?? '';
    _addrCtrl.text = b?['legal_address'] ?? '';
    // Parse emergency contacts JSON
    try {
      final ec = b?['emergency_contacts'];
      if (ec != null && ec.isNotEmpty) {
        final parsed = jsonDecode(ec);
        if (parsed is List && parsed.isNotEmpty) {
          _emerNameCtrl.text = parsed[0]['name'] ?? '';
          _emerPhoneCtrl.text = parsed[0]['phone'] ?? '';
          _emerRelationCtrl.text = parsed[0]['relation'] ?? '';
        }
      }
    } catch (_) {}
    _isActive = b?['is_active'] as bool? ?? true;
    _workerType = b?['worker_type'] ?? 'Regular';
  }

  @override void dispose() {
    _fnCtrl.dispose(); _mnCtrl.dispose(); _lnCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _addrCtrl.dispose();
    _emerNameCtrl.dispose(); _emerPhoneCtrl.dispose(); _emerRelationCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'first_name': _fnCtrl.text, 'middle_name': _mnCtrl.text, 'last_name': _lnCtrl.text,
        'email': _emailCtrl.text.trim(), 'phone': _phoneCtrl.text,
        'legal_address': _addrCtrl.text,
        'emergency_contacts': _emerNameCtrl.text.trim().isEmpty ? '[]' : jsonEncode([{'name': _emerNameCtrl.text.trim(), 'phone': _emerPhoneCtrl.text.trim(), 'relation': _emerRelationCtrl.text.trim()}]),
        'worker_type': _workerType, 'is_active': _isActive,
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {} finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Employee'),
      content: SizedBox(width: 450, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(flex: 3, child: TextFormField(controller: _fnCtrl, decoration: const InputDecoration(labelText: 'First Name', isDense: true), style: const TextStyle(fontSize: 13),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: _mnCtrl, decoration: const InputDecoration(labelText: 'M Name', isDense: true), style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: TextFormField(controller: _lnCtrl, decoration: const InputDecoration(labelText: 'Last Name', isDense: true), style: const TextStyle(fontSize: 13),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', isDense: true), style: const TextStyle(fontSize: 13),
          validator: (v) => v != null && v.isNotEmpty && !_emailRegex.hasMatch(v) ? 'Invalid email' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextFormField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Legal Address', isDense: true), style: const TextStyle(fontSize: 13), maxLines: 2),
        const SizedBox(height: 10),
        const Text('Emergency Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(flex: 3, child: TextFormField(controller: _emerNameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true), style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: _emerPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true), style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: _emerRelationCtrl, decoration: const InputDecoration(labelText: 'Relation', isDense: true), style: const TextStyle(fontSize: 13))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Worker Type', isDense: true), isExpanded: true,
            initialValue: _workerType,
            items: ['Regular','Part Time','Contractor','Intern'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _workerType = v ?? 'Regular'),
          )),
          const Spacer(),
          CheckboxListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v ?? true), title: const Text('Active', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        ]),
      ])))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
      ],
    );
  }
}

// ═══════════════════════════════════════
//  Infotype Form Widgets
// ═══════════════════════════════════════

class _PosAssignForm extends StatefulWidget {
  final Map<String, dynamic> payload;
  final AuthService authService;
  const _PosAssignForm({required this.payload, required this.authService});
  @override
  State<_PosAssignForm> createState() => _PosAssignFormState();
}

class _PosAssignFormState extends State<_PosAssignForm> {
  List<dynamic> _positions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadRefs(); }

  Future<void> _loadRefs() async {
    try { _positions = await PositionService(widget.authService.accessToken).getPositions(); } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final jobTitleCtrl = TextEditingController();
    return _loading
        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
        : Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<dynamic>(
        decoration: const InputDecoration(labelText: 'Position', isDense: true), isExpanded: true,
        items: _positions.map((p) => DropdownMenuItem<dynamic>(value: p['id'],
          child: Text('${p['position_code']} — ${p['position_title']}', style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) { widget.payload['position_id'] = v.toString(); },
      ),
      const SizedBox(height: 10),
      TextField(controller: jobTitleCtrl, decoration: const InputDecoration(labelText: 'Job Title (override)', hintText: 'Optional'),
        style: const TextStyle(fontSize: 13), onChanged: (v) => widget.payload['job_title'] = v),
    ]);
  }
}

class _SalaryForm extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _SalaryForm({required this.payload});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(flex: 2, child: TextField(decoration: const InputDecoration(labelText: 'Amount', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13),
          onChanged: (v) => payload['salary_amount'] = v)),
        const SizedBox(width: 10),
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Currency', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['salary_currency'] = v)),
        const SizedBox(width: 10),
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Frequency', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['pay_frequency'] = v)),
      ]),
    ]);
  }
}

class _AddressForm extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _AddressForm({required this.payload});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(decoration: const InputDecoration(labelText: 'Street', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['street'] = v),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'City', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['city'] = v)),
        const SizedBox(width: 10),
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'State', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['state'] = v)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Zip', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['zip'] = v)),
        const SizedBox(width: 10),
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Country', isDense: true), style: const TextStyle(fontSize: 13), onChanged: (v) => payload['country'] = v)),
      ]),
    ]);
  }
}

class _ContactForm extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _ContactForm({required this.payload});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13), onChanged: (v) => payload['email'] = v),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(labelText: 'Phone', isDense: true), keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 13), onChanged: (v) => payload['phone'] = v),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(labelText: 'Mobile', isDense: true), keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 13), onChanged: (v) => payload['mobile'] = v),
    ]);
  }
}
