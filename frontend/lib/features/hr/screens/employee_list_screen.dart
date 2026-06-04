import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/hr/services/employee_service.dart';
import 'package:swiftai_erp/features/hr/services/position_service.dart';
import 'package:swiftai_erp/features/hr/services/department_service.dart';
import 'package:swiftai_erp/features/hr/screens/employee_detail_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  final AuthService authService;
  final EmployeeService employeeService;
  const EmployeeListScreen({super.key, required this.authService, required this.employeeService});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_onSearchChanged); }
  @override
  void dispose() { _searchCtrl.removeListener(_onSearchChanged); _debounceTimer?.cancel(); _searchCtrl.dispose(); super.dispose(); }
  String get _q => _searchCtrl.text.trim();
  void _onSearchChanged() { _debounceTimer?.cancel(); _debounceTimer = Timer(const Duration(milliseconds: 300), _load); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await widget.employeeService.getEmployees(search: _q);
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) _msg('Failed to load: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => _EmployeeFormDialog(
      authService: widget.authService,
      title: 'New Employee',
      isEdit: false,
      onSave: (data) async {
        await widget.employeeService.createEmployee(data);
        _load();
        _msg('Employee created');
      },
    ));
  }

  void _showEditDialog(dynamic item) {
    showDialog(context: context, builder: (_) => _EmployeeFormDialog(
      authService: widget.authService,
      title: 'Edit ${item['employee_code'] ?? ''}',
      isEdit: true,
      initialData: {
        'employee_code': item['employee_code'],
        'first_name': item['first_name'],
        'middle_name': item['middle_name'] ?? '',
        'last_name': item['last_name'] ?? '',
        'tax_id': item['tax_id'],
        'date_of_birth': item['date_of_birth'],
        'hire_date': item['hire_date'],
        'email': item['email'],
        'phone': item['phone'],
        'legal_address': item['legal_address'],
        'emergency_contacts': item['emergency_contacts'],
        'worker_type': item['worker_type'] ?? 'Regular',
        'is_active': item['is_active'] as bool? ?? true,
        'position_id': item['position_id']?.toString(),
        'department_id': item['department_id']?.toString(),
        'manager_id': item['manager_id']?.toString(),
      },
      onSave: (data) async {
        final empId = item['employee_id']?.toString() ?? item['id']?.toString() ?? '';
        if (empId.isEmpty) throw Exception('Missing employee ID');
        await widget.employeeService.updateEmployee(empId, data);
        _load();
      },
    ));
  }

  Future<void> _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Employee'),
      content: Text('Delete "${item['employee_code']} — ${item['full_name'] ?? item['first_name'] ?? ''}"?\nThis will also remove all history records.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try {
        await widget.employeeService.deleteEmployee(item['employee_id']?.toString() ?? item['id']?.toString() ?? '');
        _load();
        _msg('Employee deleted');
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 5, onIndexChanged: (_) {}, title: 'Employees',
      body: Column(children: [
        Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: TextField(controller: _searchCtrl,
          decoration: InputDecoration(hintText: 'Search by code, name or email...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
            suffixIcon: _q.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear()) : null,
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor))),
          style: const TextStyle(fontSize: 14),
        )),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
          Text('Employees', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          if (_q.isNotEmpty) ...[const Spacer(), Text('${_items.length} result(s)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), const SizedBox(width: 8)],
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor), onPressed: _showCreateDialog, tooltip: 'Add Employee'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ])),
        const Divider(height: 1),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outlined, size: 48, color: Colors.grey.shade300), const SizedBox(height: 8),
                Text(_q.isNotEmpty ? 'No employees match "$_q"' : 'No employees defined', style: TextStyle(color: Colors.grey.shade500)),
              ]))
            : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _items.length, itemBuilder: (_, i) => _EmpCard(
                item: _items[i],
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailScreen(
                    authService: widget.authService, employeeService: widget.employeeService, 
                    employeeId: _items[i]['employee_id']?.toString() ?? _items[i]['id']?.toString() ?? '',
                    employeeCode: _items[i]['employee_code'] ?? '', 
                    employeeName: _items[i]['full_name'] ?? '${_items[i]['first_name'] ?? ''} ${_items[i]['last_name'] ?? ''}',
                  )));
                  _load();
                },
                onEdit: () => _showEditDialog(_items[i]),
                onDelete: () => _confirmDelete(_items[i]),
              ))),
      ]),
    );
  }
}

// ═══════════════════════════════════════
//  Employee Form Dialog (create + edit)
//  Uses Form + GlobalKey for validation
//  Uses DatePicker for date fields
// ═══════════════════════════════════════

class _EmployeeFormDialog extends StatefulWidget {
  final AuthService authService;
  final String title;
  final bool isEdit;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  const _EmployeeFormDialog({required this.authService, required this.title, this.isEdit = false, this.initialData, required this.onSave});
  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _fnCtrl = TextEditingController();
  final _mnCtrl = TextEditingController();
  final _lnCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _hireCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();
  final _emerRelationCtrl = TextEditingController();
  final _emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$');

  bool _isActive = true;
  String _workerType = 'Regular';
  String? _positionId;
  String? _deptId;
  String? _mgrId;
  bool _loadingRefs = true;
  bool _saving = false;
  List<dynamic> _positions = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _codeCtrl.text = d['employee_code'] ?? '';
      _fnCtrl.text = d['first_name'] ?? '';
      _mnCtrl.text = d['middle_name'] ?? '';
      _lnCtrl.text = d['last_name'] ?? '';
      _taxCtrl.text = d['tax_id'] ?? '';
      _dobCtrl.text = d['date_of_birth'] ?? '';
      _hireCtrl.text = d['hire_date'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _phoneCtrl.text = d['phone'] ?? '';
      _addrCtrl.text = d['legal_address'] ?? '';
      // Parse emergency_contacts JSON into 3 fields
      try {
        final ec = d['emergency_contacts'];
        if (ec != null && ec.isNotEmpty) {
          final parsed = jsonDecode(ec);
          if (parsed is List && parsed.isNotEmpty) {
            _emerNameCtrl.text = parsed[0]['name'] ?? '';
            _emerPhoneCtrl.text = parsed[0]['phone'] ?? '';
            _emerRelationCtrl.text = parsed[0]['relation'] ?? '';
          }
        }
      } catch (_) {}
      _isActive = d['is_active'] as bool? ?? true;
      _workerType = d['worker_type'] ?? 'Regular';
      _positionId = d['position_id']?.toString();
      _deptId = d['department_id']?.toString();
      _mgrId = d['manager_id']?.toString();
    }
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final token = widget.authService.accessToken ?? '';
    // Load each list independently so one failure doesn't block the others
    try { _positions = await PositionService(token).getPositions(); } catch (_) {}
    try { _departments = await DepartmentService(token).getOrgUnits(); } catch (_) {}
    try { _employees = await EmployeeService(token).getEmployees(); } catch (_) {}
    if (mounted) setState(() => _loadingRefs = false);
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _fnCtrl.dispose(); _mnCtrl.dispose(); _lnCtrl.dispose();
    _taxCtrl.dispose(); _dobCtrl.dispose(); _hireCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _addrCtrl.dispose();
    _emerNameCtrl.dispose(); _emerPhoneCtrl.dispose(); _emerRelationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
      firstDate: DateTime(1920), lastDate: DateTime(2100));
    if (d != null) ctrl.text = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // Build emergency contacts JSON from 3 fields
      final emerName = _emerNameCtrl.text.trim();
      String emergencyContacts = '[]';
      if (emerName.isNotEmpty) {
        final ec = <String, dynamic>{'name': emerName, 'phone': _emerPhoneCtrl.text.trim(), 'relation': _emerRelationCtrl.text.trim()};
        emergencyContacts = jsonEncode([ec]);
      }

      final data = <String, dynamic>{
        if (!widget.isEdit) 'employee_code': _codeCtrl.text,
        'first_name': _fnCtrl.text,
        'middle_name': _mnCtrl.text,
        'last_name': _lnCtrl.text,
        'tax_id': _taxCtrl.text,
        'date_of_birth': _dobCtrl.text,
        'hire_date': _hireCtrl.text,
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text,
        'legal_address': _addrCtrl.text,
        'emergency_contacts': emergencyContacts,
        'worker_type': _workerType,
        'is_active': _isActive,
      };
      if (_positionId != null && _positionId!.isNotEmpty) data['position_id'] = _positionId;
      if (_deptId != null && _deptId!.isNotEmpty) data['department_id'] = _deptId;
      if (_mgrId != null && _mgrId!.isNotEmpty) data['manager_id'] = _mgrId;
      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  Widget _ddField(String label, String? value, List<dynamic> items, String idField, String displayField, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, isDense: true),
      isExpanded: true, initialValue: value,
      items: [const DropdownMenuItem(value: null, child: Text('(None)', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ...items.map((i) => DropdownMenuItem(value: i[idField]?.toString(), child: Text(i[displayField]?.toString() ?? '', style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!widget.isEdit)
                TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Employee Code *', hintText: 'e.g. EMP-0001'),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              if (!widget.isEdit) const SizedBox(height: 10),

              // Name: First + Middle + Last
              Row(children: [
                Expanded(flex: 3, child: TextFormField(controller: _fnCtrl, decoration: const InputDecoration(labelText: 'First Name *'), style: const TextStyle(fontSize: 13),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(controller: _mnCtrl, decoration: const InputDecoration(labelText: 'M Name'), style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: TextFormField(controller: _lnCtrl, decoration: const InputDecoration(labelText: 'Last Name *'), style: const TextStyle(fontSize: 13),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 10),

              // Position + Department
              if (_loadingRefs)
                const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else ...[
                Row(children: [
                  Expanded(child: _ddField('Position', _positionId, _positions, 'id', 'position_title', (v) => setState(() => _positionId = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _ddField('Department', _deptId, _departments, 'id', 'unit_name', (v) => setState(() => _deptId = v))),
                ]),
                const SizedBox(height: 10),
              ],

              // Dates: DOB + Hire Date (with DatePicker)
              Row(children: [
                Expanded(child: TextFormField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Birth Date', hintText: 'YYYY-MM-DD', suffixIcon: Icon(Icons.date_range, size: 18)),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13), readOnly: true, onTap: () => _pickDate(_dobCtrl),
                  validator: (v) => v != null && v.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? 'Invalid date' : null)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _hireCtrl, decoration: const InputDecoration(labelText: 'Hire Date', hintText: 'YYYY-MM-DD', suffixIcon: Icon(Icons.date_range, size: 18)),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13), readOnly: true, onTap: () => _pickDate(_hireCtrl),
                  validator: (v) => v != null && v.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? 'Invalid date' : null)),
              ]),
              const SizedBox(height: 10),

              // Email + Phone
              Row(children: [
                Expanded(flex: 3, child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', hintText: 'user@company.com'),
                  keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 13),
                  validator: (v) => v != null && v.isNotEmpty && !_emailRegex.hasMatch(v) ? 'Invalid email format' : null)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), style: const TextStyle(fontSize: 13))),
              ]),
              const SizedBox(height: 10),

              // Legal Address
              TextFormField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Legal Address'), maxLines: 2, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),

              // Worker Type + Manager
              if (!_loadingRefs) ...[
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Worker Type', isDense: true), isExpanded: true,
                    initialValue: _workerType,
                    items: ['Regular','Part Time','Contractor','Intern'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _workerType = v ?? 'Regular'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ddField('Manager', _mgrId, _employees, 'employee_id', 'full_name', (v) => setState(() => _mgrId = v))),
                ]),
                const SizedBox(height: 8),
              ],

              // Emergency Contacts (3 fields)
              const Text('Emergency Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(flex: 3, child: TextFormField(controller: _emerNameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true), style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(controller: _emerPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true), style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _emerRelationCtrl, decoration: const InputDecoration(labelText: 'Relation', isDense: true), style: const TextStyle(fontSize: 13))),
              ]),
              const SizedBox(height: 8),
              CheckboxListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v ?? true), title: const Text('Active', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(widget.isEdit ? 'Save' : 'Create')),
      ],
    );
  }
}

// ═══════════════════════════════════════
//  Employee Card (list view)
//  Now with Edit + Delete buttons
// ═══════════════════════════════════════

class _EmpCard extends StatelessWidget {
  final dynamic item; final VoidCallback onTap, onEdit, onDelete;
  const _EmpCard({required this.item, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isActive = item['is_active'] as bool? ?? true;
    final name = item['full_name'] ?? '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}';
    final pos = item['position_title'] ?? '';
    final dept = item['dept_name'] ?? '';
    final email = item['email'] ?? '';
    final workerType = item['worker_type'] ?? 'Regular';
    final isPartTime = workerType != 'Regular';

    return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: ListTile(
      onTap: onTap,
      leading: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: (isActive ? Colors.blueGrey : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Center(child: Icon(Icons.person_outline, color: isActive ? Colors.blueGrey : Colors.grey, size: 22)),
      ),
      title: Row(children: [
        Text(item['employee_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Flexible(child: Text(name.trim(), style: const TextStyle(fontSize: 13))),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (pos.isNotEmpty || dept.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 2), child: Text([pos, dept].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        Row(children: [
          if (email.isNotEmpty) ...[Icon(Icons.email_outlined, size: 10, color: Colors.grey.shade400), const SizedBox(width: 2), Flexible(child: Text(email, style: TextStyle(fontSize: 9, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis))],
          if (isPartTime) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(3)),
            child: Text(workerType, style: TextStyle(fontSize: 9, color: Colors.orange.shade700)))],
          if (!isActive) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
            child: const Text('Inactive', style: TextStyle(fontSize: 9, color: Colors.grey)))],
        ]),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400), onPressed: onEdit, tooltip: 'Edit', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400), onPressed: onDelete, tooltip: 'Delete', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
      ]),
    ));
  }
}
