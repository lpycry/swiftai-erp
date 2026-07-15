import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';

const _activityKeys = [
  'create',
  'read',
  'update',
  'delete',
  'approve',
  'print',
  'transfer',
  'close',
];

class RolesScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;

  const RolesScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<dynamic> _roles = [];
  List<dynamic> _authObjects = [];
  Map<String, dynamic>? _selectedRole;
  Map<String, Map<String, dynamic>> _authValues = {};
  bool _loading = true;
  bool _detailLoading = false;
  String? _categoryFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.adminService.getRoles(category: _categoryFilter),
        widget.adminService.getAuthObjects(),
      ]);
      _roles = results[0];
      _authObjects = results[1];
      if (_selectedRole != null) {
        final selectedId = (_selectedRole!['id'] ?? '').toString();
        _selectedRole = _roles
            .cast<Map?>()
            .firstWhere(
              (r) => (r?['id'] ?? '').toString() == selectedId,
              orElse: () => null,
            )
            ?.cast<String, dynamic>();
      }
      _selectedRole ??= _roles.isEmpty
          ? null
          : Map<String, dynamic>.from(_roles.first);
      if (_selectedRole != null)
        await _loadAuthValues(_selectedRole!, keepSpinner: true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuthValues(
    Map<String, dynamic> role, {
    bool keepSpinner = false,
  }) async {
    if (!keepSpinner) setState(() => _detailLoading = true);
    try {
      final vals = await widget.adminService.getAuthValues(role['id']);
      _authValues = {
        for (final val in vals)
          (val['auth_object_id'] ?? '').toString(): Map<String, dynamic>.from(
            val,
          ),
      };
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted && !keepSpinner) setState(() => _detailLoading = false);
    }
  }

  Future<void> _selectRole(Map<String, dynamic> role) async {
    setState(() {
      _selectedRole = role;
      _authValues = {};
    });
    await _loadAuthValues(role);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'single';
    String category = 'admin';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create Role'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Role ID *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'single', child: Text('Single')),
                    DropdownMenuItem(
                      value: 'composite',
                      child: Text('Composite'),
                    ),
                    DropdownMenuItem(value: 'derived', child: Text('Derived')),
                  ],
                  onChanged: (v) => setDlgState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'finance', child: Text('Finance')),
                    DropdownMenuItem(
                      value: 'logistics',
                      child: Text('Logistics'),
                    ),
                    DropdownMenuItem(
                      value: 'procurement',
                      child: Text('Procurement'),
                    ),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    DropdownMenuItem(
                      value: 'production',
                      child: Text('Production'),
                    ),
                  ],
                  onChanged: (v) => setDlgState(() => category = v ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  _showError('Role ID is required.');
                  return;
                }
                try {
                  final role = await widget.adminService.createRole({
                    'role_id': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'role_type': type,
                    'role_category': category,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _selectedRole = role);
                  await _load();
                } catch (e) {
                  _showError(e);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedRole() async {
    final role = _selectedRole;
    if (role == null || role['is_system'] == true) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Delete ${role['role_id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.adminService.deleteRole(role['id']);
      setState(() => _selectedRole = null);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  List<dynamic> get _filteredRoles {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _roles;
    return _roles.where((role) {
      final text =
          '${role['role_id']} ${role['description']} ${role['role_category']}'
              .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 6,
      onIndexChanged: (_) {},
      title: 'Role Management',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _Toolbar(
                  filter: _categoryFilter,
                  onFilter: (v) {
                    setState(() => _categoryFilter = v);
                    _load();
                  },
                  onSearch: (v) => setState(() => _search = v),
                  onCreate: _showCreateDialog,
                  onRefresh: _load,
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 380,
                        child: _RoleList(
                          roles: _filteredRoles,
                          selectedRole: _selectedRole,
                          onSelect: _selectRole,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _selectedRole == null
                            ? const Center(child: Text('No role selected'))
                            : _RoleAuthWorkbench(
                                role: _selectedRole!,
                                roles: _roles,
                                authObjects: _authObjects,
                                authValues: _authValues,
                                loading: _detailLoading,
                                adminService: widget.adminService,
                                onRoleChanged: _load,
                                onSave: _saveAuthValue,
                                onDeleteRole: _deleteSelectedRole,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveAuthValue(
    Map<String, dynamic> authObject,
    Map<String, dynamic> next,
  ) async {
    final role = _selectedRole;
    if (role == null) return;
    try {
      await widget.adminService.setAuthValue(role['id'], {
        'auth_object_id': authObject['id'],
        ...next,
      });
      await _loadAuthValues(role);
    } catch (e) {
      _showError(e);
    }
  }
}

class _Toolbar extends StatelessWidget {
  final String? filter;
  final ValueChanged<String?> onFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _Toolbar({
    required this.filter,
    required this.onFilter,
    required this.onSearch,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String?>(
              initialValue: filter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'finance', child: Text('Finance')),
                DropdownMenuItem(value: 'logistics', child: Text('Logistics')),
                DropdownMenuItem(
                  value: 'procurement',
                  child: Text('Procurement'),
                ),
                DropdownMenuItem(value: 'sales', child: Text('Sales')),
                DropdownMenuItem(
                  value: 'production',
                  child: Text('Production'),
                ),
              ],
              onChanged: onFilter,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search role ID, description, category',
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Role'),
          ),
        ],
      ),
    );
  }
}

class _RoleList extends StatelessWidget {
  final List<dynamic> roles;
  final Map<String, dynamic>? selectedRole;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _RoleList({
    required this.roles,
    required this.selectedRole,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const Center(child: Text('No roles defined'));
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final role = Map<String, dynamic>.from(roles[index]);
        final selected = role['id'] == selectedRole?['id'];
        final type = (role['role_type'] ?? 'single').toString();
        return Material(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelect(role),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade200,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role['role_id'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _Badge(type, AppTheme.primaryColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    role['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(
                        role['role_category'] ?? 'uncategorized',
                        Colors.blueGrey,
                      ),
                      if (role['is_system'] == true)
                        _Badge('system', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleAuthWorkbench extends StatelessWidget {
  final Map<String, dynamic> role;
  final List<dynamic> roles;
  final List<dynamic> authObjects;
  final Map<String, Map<String, dynamic>> authValues;
  final bool loading;
  final AdminService adminService;
  final Future<void> Function() onRoleChanged;
  final Future<void> Function(Map<String, dynamic>, Map<String, dynamic>)
  onSave;
  final VoidCallback onDeleteRole;

  const _RoleAuthWorkbench({
    required this.role,
    required this.roles,
    required this.authObjects,
    required this.authValues,
    required this.loading,
    required this.adminService,
    required this.onRoleChanged,
    required this.onSave,
    required this.onDeleteRole,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role['role_id'] ?? '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role['description'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: role['is_system'] == true ? null : onDeleteRole,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Role'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (role['role_type'] == 'composite' || role['role_type'] == 'derived')
          _RoleRelationshipPanel(
            role: role,
            roles: roles,
            adminService: adminService,
            onChanged: onRoleChanged,
          ),
        if (role['role_type'] == 'composite' || role['role_type'] == 'derived')
          const Divider(height: 1),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: authObjects.isEmpty
              ? const Center(child: Text('No authorization objects found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: authObjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final obj = Map<String, dynamic>.from(authObjects[index]);
                    final value =
                        authValues[(obj['id'] ?? '').toString()] ?? {};
                    return _AuthObjectEditor(
                      authObject: obj,
                      authValue: value,
                      onSave: (next) => onSave(obj, next),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RoleRelationshipPanel extends StatefulWidget {
  final Map<String, dynamic> role;
  final List<dynamic> roles;
  final AdminService adminService;
  final Future<void> Function() onChanged;

  const _RoleRelationshipPanel({
    required this.role,
    required this.roles,
    required this.adminService,
    required this.onChanged,
  });

  @override
  State<_RoleRelationshipPanel> createState() => _RoleRelationshipPanelState();
}

class _RoleRelationshipPanelState extends State<_RoleRelationshipPanel> {
  List<dynamic> _members = [];
  String? _selectedMemberId;
  String? _selectedParentId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.role['parent_role_id']?.toString();
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant _RoleRelationshipPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role['id'] != widget.role['id']) {
      _selectedMemberId = null;
      _selectedParentId = widget.role['parent_role_id']?.toString();
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    if (widget.role['role_type'] != 'composite') {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      _members = await widget.adminService.getCompositeMembers(
        widget.role['id'],
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: widget.role['role_type'] == 'composite'
          ? _buildComposite(context)
          : _buildDerived(context),
    );
  }

  Widget _buildComposite(BuildContext context) {
    final memberIds = {
      for (final member in _members) (member['id'] ?? '').toString(),
    };
    final available = widget.roles
        .where(
          (role) =>
              (role['id'] ?? '').toString() !=
                  (widget.role['id'] ?? '').toString() &&
              !memberIds.contains((role['id'] ?? '').toString()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Composite Role Members',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMemberId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Add Child Role'),
                items: available
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role['id'],
                        child: Text(
                          '${role['role_id']} - ${role['description'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedMemberId = v),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _selectedMemberId == null || _saving
                  ? null
                  : _addMember,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _members.isEmpty
                ? [
                    Text(
                      'No child roles',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ]
                : _members
                      .map(
                        (member) => InputChip(
                          label: Text(member['role_id'] ?? ''),
                          onDeleted: _saving
                              ? null
                              : () => _removeMember(
                                  (member['id'] ?? '').toString(),
                                ),
                        ),
                      )
                      .toList(),
          ),
      ],
    );
  }

  Widget _buildDerived(BuildContext context) {
    final available = widget.roles
        .where(
          (role) =>
              (role['id'] ?? '').toString() !=
              (widget.role['id'] ?? '').toString(),
        )
        .toList();
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _selectedParentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Base Role'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              ...available.map(
                (role) => DropdownMenuItem<String?>(
                  value: role['id'],
                  child: Text(
                    '${role['role_id']} - ${role['description'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedParentId = v),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _saving ? null : _saveDerivedParent,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Base Role'),
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    setState(() => _saving = true);
    try {
      await widget.adminService.addCompositeMember(
        widget.role['id'],
        _selectedMemberId!,
      );
      _selectedMemberId = null;
      await _loadMembers();
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeMember(String childRoleId) async {
    setState(() => _saving = true);
    try {
      await widget.adminService.removeCompositeMember(
        widget.role['id'],
        childRoleId,
      );
      await _loadMembers();
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDerivedParent() async {
    setState(() => _saving = true);
    try {
      await widget.adminService.updateRole(widget.role['id'], {
        'role_id': widget.role['role_id'],
        'description': widget.role['description'] ?? '',
        'role_type': 'derived',
        'role_category': widget.role['role_category'] ?? '',
        'parent_role_id': _selectedParentId ?? '',
      });
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AuthObjectEditor extends StatefulWidget {
  final Map<String, dynamic> authObject;
  final Map<String, dynamic> authValue;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _AuthObjectEditor({
    required this.authObject,
    required this.authValue,
    required this.onSave,
  });

  @override
  State<_AuthObjectEditor> createState() => _AuthObjectEditorState();
}

class _AuthObjectEditorState extends State<_AuthObjectEditor> {
  late final Map<String, bool> _activities;
  late final Map<String, TextEditingController> _fieldValues;
  late final Map<String, TextEditingController> _rangeFrom;
  late final Map<String, TextEditingController> _rangeTo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activities = {
      for (final key in _activityKeys)
        key: widget.authValue['activity_$key'] == true,
    };
    final fields = (widget.authObject['fields'] ?? []) as List<dynamic>;
    final values = Map<String, dynamic>.from(
      widget.authValue['field_values'] ?? {},
    );
    final ranges = Map<String, dynamic>.from(
      widget.authValue['field_ranges'] ?? {},
    );
    _fieldValues = {};
    _rangeFrom = {};
    _rangeTo = {};
    for (final raw in fields) {
      final field = Map<String, dynamic>.from(raw);
      final name = (field['field_name'] ?? '').toString();
      final range = Map<String, dynamic>.from(ranges[name] ?? {});
      _fieldValues[name] = TextEditingController(
        text: (values[name] ?? '').toString(),
      );
      _rangeFrom[name] = TextEditingController(
        text: (range['from'] ?? '').toString(),
      );
      _rangeTo[name] = TextEditingController(
        text: (range['to'] ?? '').toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      ..._fieldValues.values,
      ..._rangeFrom.values,
      ..._rangeTo.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = (widget.authObject['fields'] ?? []) as List<dynamic>;
    final configured =
        _activities.values.any((v) => v) ||
        _fieldValues.values.any((c) => c.text.trim().isNotEmpty) ||
        _rangeFrom.values.any((c) => c.text.trim().isNotEmpty) ||
        _rangeTo.values.any((c) => c.text.trim().isNotEmpty);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: configured ? AppTheme.primaryColor : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.authObject['object_code'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _Badge(widget.authObject['object_class'] ?? '', Colors.blueGrey),
            ],
          ),
          subtitle: Text(
            widget.authObject['description'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in _activityKeys)
                    FilterChip(
                      label: Text(key.toUpperCase()),
                      selected: _activities[key] == true,
                      onSelected: (v) => setState(() => _activities[key] = v),
                    ),
                ],
              ),
            ),
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final raw in fields)
                _FieldLimitRow(
                  field: raw,
                  values: _fieldValues,
                  from: _rangeFrom,
                  to: _rangeTo,
                ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save Authorization'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fieldValues = <String, String>{};
      final fieldRanges = <String, Map<String, String>>{};
      for (final entry in _fieldValues.entries) {
        final value = entry.value.text.trim();
        if (value.isNotEmpty) fieldValues[entry.key] = value;
      }
      for (final key in _rangeFrom.keys) {
        final from = _rangeFrom[key]!.text.trim();
        final to = _rangeTo[key]!.text.trim();
        if (from.isNotEmpty || to.isNotEmpty) {
          fieldRanges[key] = {'from': from, 'to': to};
        }
      }
      await widget.onSave({
        for (final key in _activityKeys)
          'activity_$key': _activities[key] == true,
        'field_values': fieldValues,
        'field_ranges': fieldRanges,
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FieldLimitRow extends StatelessWidget {
  final dynamic field;
  final Map<String, TextEditingController> values;
  final Map<String, TextEditingController> from;
  final Map<String, TextEditingController> to;

  const _FieldLimitRow({
    required this.field,
    required this.values,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final f = Map<String, dynamic>.from(field);
    final name = (f['field_name'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              f['field_label'] ?? name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: values[name],
              decoration: const InputDecoration(labelText: 'Allowed Values'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: from[name],
              decoration: const InputDecoration(labelText: 'From'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: to[name],
              decoration: const InputDecoration(labelText: 'To'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
