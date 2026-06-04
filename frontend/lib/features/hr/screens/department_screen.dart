import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/hr/services/department_service.dart';
import 'package:swiftai_erp/features/finance/services/cost_center_service.dart';

class DepartmentScreen extends StatefulWidget {
  final AuthService authService;
  final DepartmentService departmentService;

  const DepartmentScreen({
    super.key,
    required this.authService,
    required this.departmentService,
  });

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _treeMode = false;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _q => _searchCtrl.text.trim();

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_treeMode && _q.isEmpty) {
        _items = await widget.departmentService.getOrgUnitTree();
      } else {
        _items = await widget.departmentService.getOrgUnits(search: _q);
      }
    } catch (e) {
      if (mounted) _msg('Failed to load: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? AppTheme.errorColor : Colors.green,
    ));
  }

  // ═══════════════════════════════════════
  //  Create Dialog
  // ═══════════════════════════════════════

  void _showCreateDialog({dynamic parentUnit}) {
    showDialog(
      context: context,
      builder: (ctx) => _DepartmentFormDialog(
        authService: widget.authService,
        title: parentUnit != null
            ? 'New Sub-Unit under ${parentUnit['unit_code']}'
            : 'New Department',
        parentId: parentUnit?['id']?.toString(),
        onSave: (data) async {
          try {
            await widget.departmentService.createOrgUnit(data);
            _load();
            _msg('Department created');
          } catch (e) {
            _msg('$e', isError: true);
            rethrow;
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Edit Dialog
  // ═══════════════════════════════════════

  void _showEditDialog(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => _DepartmentFormDialog(
        authService: widget.authService,
        title: 'Edit — ${item['unit_code'] ?? ''}',
        isEdit: true,
        initialData: {
          'unit_name': item['unit_name'] ?? '',
          'cost_center_id': item['cost_center_id'] ?? '',
          'manager_id': item['manager_id'] ?? '',
          'valid_from': _cleanDate(item['valid_from']),
          'valid_to': _cleanDate(item['valid_to']),
          'is_active': item['is_active'] as bool? ?? true,
        },
        onSave: (data) async {
          try {
            await widget.departmentService.updateOrgUnit(item['id'].toString(), data);
            _load();
            _msg('Department updated');
          } catch (e) {
            _msg('$e', isError: true);
            rethrow;
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Delete
  // ═══════════════════════════════════════

  Future<void> _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Delete "${item['unit_code']} — ${item['unit_name']}"?\n\n'
            'Only units with no child units can be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.departmentService.deleteOrgUnit(item['id'].toString());
        _load();
        _msg('Department deleted');
      } catch (e) {
        _msg('$e', isError: true);
      }
    }
  }

  // ═══════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════

  String _cleanDate(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    if (d.length >= 10) return d.substring(0, 10);
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 5,
      onIndexChanged: (_) {},
      title: 'Departments',
      body: Column(
        children: [
          // Search + Toggle
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by code or name...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                      suffixIcon: _q.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                _ModeToggle(
                  isTree: _treeMode,
                  onChanged: (v) => setState(() {
                    _treeMode = v;
                    _load();
                  }),
                ),
              ],
            ),
          ),
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(_treeMode ? 'Org Chart' : 'Departments',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (_q.isNotEmpty) ...[
                  const Spacer(),
                  Text('${_items.length} result(s)',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  onPressed: () => _showCreateDialog(),
                  tooltip: 'Add Department',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_tree_outlined, size: 48,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              _q.isNotEmpty
                                  ? 'No departments match "$_q"'
                                  : 'No departments defined',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(8),
                        children: _treeMode && _q.isEmpty
                            ? _items.map((r) => _buildTreeNode(r, 0)).toList()
                            : _items.map((item) => _buildListItem(item)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(dynamic item) {
    return _UnitCard(
      item: item,
      onTap: () => _showEditDialog(item),
      onDelete: () => _confirmDelete(item),
    );
  }

  Widget _buildTreeNode(dynamic node, int depth) {
    final ccId = node['cost_center_id'] ?? '';
    final children = (node['children'] as List<dynamic>?) ?? [];
    final isExpired = !(node['is_active'] as bool? ?? true);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              leading: Container(
                margin: EdgeInsets.only(left: depth * 24.0),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isExpired ? Colors.grey : Colors.indigo)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  depth == 0
                      ? Icons.business
                      : (depth == 1
                          ? Icons.group_work_outlined
                          : Icons.group_outlined),
                  size: 18,
                  color: isExpired ? Colors.grey : Colors.indigo,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    '${node['unit_code'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: isExpired ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    node['unit_name'] ?? '',
                    style: TextStyle(
                        fontSize: 13,
                        color: isExpired ? Colors.grey.shade500 : null),
                  ),
                ],
              ),
              subtitle: ccId != ''
                  ? Row(children: [
                      Icon(Icons.monetization_on,
                          size: 10, color: Colors.green.shade500),
                      const SizedBox(width: 3),
                      Text('CC: $ccId',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade600,
                              fontFamily: 'monospace')),
                      if (node['valid_to'] != null &&
                          _cleanDate(node['valid_to']).isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('until ${_cleanDate(node['valid_to'])}',
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade400)),
                      ],
                    ])
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline,
                        size: 16, color: Colors.blue.shade400),
                    onPressed: () => _showCreateDialog(parentUnit: node),
                    tooltip: 'Add Sub-Unit',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 16, color: Colors.blue.shade400),
                    onPressed: () => _showEditDialog(node),
                    tooltip: 'Edit',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  if (children.isEmpty)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 16, color: Colors.red.shade400),
                      onPressed: () => _confirmDelete(node),
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
            ),
          ),
        ),
        ...children.map((c) => _buildTreeNode(c, depth + 1)),
      ],
    );
  }
}

// ═══════════════════════════════════════
//  Shared Department Form Dialog
//  (with Cost Center dropdown from master data)
// ═══════════════════════════════════════

class _DepartmentFormDialog extends StatefulWidget {
  final AuthService authService;
  final String title;
  final bool isEdit;
  final String? parentId;
  final Map<String, dynamic>? initialData;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _DepartmentFormDialog({
    required this.authService,
    required this.title,
    this.isEdit = false,
    this.parentId,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  bool _isActive = true;
  String? _selectedCcId;
  List<dynamic> _ccList = [];
  bool _ccLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialData?['unit_name'] ?? '';
    _managerCtrl.text = widget.initialData?['manager_id'] ?? '';
    _fromCtrl.text = widget.initialData?['valid_from'] ?? _today();
    _toCtrl.text = widget.initialData?['valid_to'] ?? '';
    _isActive = widget.initialData?['is_active'] as bool? ?? true;
    _selectedCcId = widget.initialData?['cost_center_id'] as String?;
    _loadCCs();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCCs() async {
    try {
      final svc = CostCenterService(widget.authService.accessToken ?? '');
      _ccList = await svc.getCostCenters();
    } catch (_) {}
    if (mounted) setState(() => _ccLoading = false);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!widget.isEdit && (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty)) return;
    if (widget.isEdit && _nameCtrl.text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        if (!widget.isEdit) 'unit_code': _codeCtrl.text,
        'unit_name': _nameCtrl.text,
        'cost_center_id': _selectedCcId ?? '',
        'manager_id': _managerCtrl.text,
        'is_active': _isActive,
        'valid_from': _fromCtrl.text,
        'valid_to': _toCtrl.text,
      };
      if (widget.parentId != null) data['parent_id'] = widget.parentId;
      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // error handled by parent
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!widget.isEdit)
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Unit Code *', hintText: 'e.g. D-2001'),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            if (!widget.isEdit) const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Unit Name *', hintText: 'e.g. Sales Department'),
            ),
            const SizedBox(height: 10),

            // ── Cost Center Dropdown ──
            _ccLoading
                ? const SizedBox(
                    height: 40,
                    child: Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))))
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Cost Center',
                      isDense: true,
                      prefixIcon: Icon(Icons.monetization_on, size: 18),
                    ),
                    isExpanded: true,
                    initialValue: _selectedCcId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('(None)',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ),
                      ..._ccList.map((cc) => DropdownMenuItem(
                            value: cc['cost_center_id'] as String? ?? '',
                            child: Text(
                              '${cc['cost_center_id']} — ${cc['description'] ?? ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedCcId = v),
                  ),
            const SizedBox(height: 10),

            // Manager
            TextField(
              controller: _managerCtrl,
              decoration: const InputDecoration(
                  labelText: 'Manager ID (optional)'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),

            // Dates
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _fromCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Valid From', hintText: 'YYYY-MM-DD'),
                  style:
                      const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _toCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Valid To (opt)', hintText: 'YYYY-MM-DD'),
                  style:
                      const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v ?? true),
              title: const Text('Active', style: TextStyle(fontSize: 13)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════
//  Sub-widgets
// ═══════════════════════════════════════

class _ModeToggle extends StatelessWidget {
  final bool isTree;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isTree, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.list,
            label: 'List',
            selected: !isTree,
            onTap: () => onChanged(false),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _ToggleBtn(
            icon: Icons.account_tree_outlined,
            label: 'Tree',
            selected: isTree,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    selected ? AppTheme.primaryColor : Colors.grey.shade500),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _UnitCard(
      {required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isActive = item['is_active'] as bool? ?? true;
    final validTo = item['valid_to']?.toString() ?? '';
    final isExpired = !isActive ||
        (validTo.isNotEmpty &&
            validTo != '0001-01-01' &&
            DateTime.tryParse(validTo) != null &&
            DateTime.parse(validTo).isBefore(DateTime.now()));
    final ccId = item['cost_center_id'] ?? '';
    final parentId = item['parent_id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isExpired ? Colors.grey : Colors.indigo)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(Icons.group_outlined,
                color: isExpired ? Colors.grey : Colors.indigo, size: 22),
          ),
        ),
        title: Row(
          children: [
            Text(
              item['unit_code'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'monospace',
                color: isExpired ? Colors.grey : null,
              ),
            ),
            const SizedBox(width: 8),
            if (parentId.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(Icons.subdirectory_arrow_right,
                    size: 12, color: Colors.grey.shade400),
              ),
            if (ccId.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(ccId,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.green.shade700,
                        fontFamily: 'monospace')),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['unit_name'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.date_range,
                    size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(
                  _fmt(item['valid_from']),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace'),
                ),
                if (validTo.isNotEmpty && validTo != '0001-01-01') ...[
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward,
                      size: 10, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    _fmt(validTo),
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace'),
                  ),
                ],
                if (!isExpired && isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(3)),
                    child: Text('Active',
                        style: TextStyle(
                            fontSize: 9, color: Colors.green.shade700)),
                  ),
                ],
                if (isExpired || !isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3)),
                    child: Text('Inactive',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: Colors.blue.shade400),
              onPressed: onTap,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }
}
