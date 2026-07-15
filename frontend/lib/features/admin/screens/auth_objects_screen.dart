import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';

class AuthObjectsScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;

  const AuthObjectsScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<AuthObjectsScreen> createState() => _AuthObjectsScreenState();
}

class _AuthObjectsScreenState extends State<AuthObjectsScreen> {
  final _searchCtrl = TextEditingController();
  final List<String> _classes = const [
    'finance',
    'logistics',
    'procurement',
    'sales',
    'production',
    'admin',
  ];

  List<dynamic> _objects = [];
  Map<String, dynamic>? _selectedDetail;
  bool _loading = true;
  bool _detailLoading = false;
  String? _classFilter;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadObjects() async {
    setState(() => _loading = true);
    try {
      final objects = await widget.adminService.getAuthObjects(
        classFilter: _classFilter,
      );
      if (!mounted) return;
      setState(() {
        _objects = objects;
        if (_selectedDetail != null &&
            !_objects.any(
              (o) => o['id'] == _selectedDetail?['object']?['id'],
            )) {
          _selectedDetail = null;
        }
      });
    } catch (e) {
      _showError('Failed to load authorization objects: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDetail(String id) async {
    setState(() => _detailLoading = true);
    try {
      final detail = await widget.adminService.getAuthObject(id);
      if (!mounted) return;
      setState(() => _selectedDetail = detail);
    } catch (e) {
      _showError('Failed to load authorization object detail: $e');
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  List<dynamic> get _filteredObjects {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _objects;
    return _objects.where((obj) {
      final code = (obj['object_code'] ?? '').toString().toLowerCase();
      final desc = (obj['description'] ?? '').toString().toLowerCase();
      final cls = (obj['object_class'] ?? '').toString().toLowerCase();
      return code.contains(query) ||
          desc.contains(query) ||
          cls.contains(query);
    }).toList();
  }

  Future<void> _showObjectDialog({Map<String, dynamic>? object}) async {
    final isEdit = object != null;
    final codeCtrl = TextEditingController(
      text: object?['object_code']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: object?['description']?.toString() ?? '',
    );
    String objectClass = object?['object_class']?.toString() ?? 'finance';
    final activities = <String>{
      ...((object?['activities'] as List<dynamic>?) ?? const []).map(
        (e) => e.toString(),
      ),
    };
    if (activities.isEmpty) activities.addAll(['read']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Authorization Object' : 'New Authorization Object',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 48,
                    child: DropdownButtonFormField<String>(
                      initialValue: objectClass,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Object Class *',
                      ),
                      items: _classes
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(_classLabel(c)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDlgState(() => objectClass = v ?? 'finance'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Object Code *',
                      hintText: 'e.g. S_DELIVERY',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Allowed Activities',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activityOptions.map((activity) {
                      final selected = activities.contains(activity);
                      return FilterChip(
                        label: Text(activity),
                        selected: selected,
                        onSelected: (checked) => setDlgState(() {
                          if (checked) {
                            activities.add(activity);
                          } else {
                            activities.remove(activity);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: Icon(isEdit ? Icons.save_outlined : Icons.add),
              label: Text(isEdit ? 'Save' : 'Create'),
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty || activities.isEmpty) {
                  _showError(
                    'Object Code and at least one activity are required.',
                  );
                  return;
                }
                final payload = {
                  'object_class': objectClass,
                  'object_code': code,
                  'description': descCtrl.text.trim(),
                  'activities': activities.toList()..sort(),
                };
                try {
                  if (isEdit) {
                    await widget.adminService.updateAuthObject(
                      object['id'].toString(),
                      payload,
                    );
                  } else {
                    await widget.adminService.createAuthObject(payload);
                  }
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadObjects();
                  if (isEdit) await _loadDetail(object['id'].toString());
                } catch (e) {
                  _showError('$e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldDialog(String objectId) async {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '10');
    String fieldType = 'general';
    bool required = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Authorization Field'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Field Name *',
                    hintText: 'e.g. plant',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Field Label'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    initialValue: fieldType,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Field Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'org',
                        child: Text('Organization'),
                      ),
                      DropdownMenuItem(
                        value: 'account',
                        child: Text('Account'),
                      ),
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General'),
                      ),
                      DropdownMenuItem(value: 'value', child: Text('Value')),
                    ],
                    onChanged: (v) =>
                        setDlgState(() => fieldType = v ?? 'general'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Display Order'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: required,
                  title: const Text('Required field'),
                  onChanged: (v) => setDlgState(() => required = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Field'),
              onPressed: () async {
                final name = nameCtrl.text.trim().toLowerCase();
                if (name.isEmpty) {
                  _showError('Field Name is required.');
                  return;
                }
                try {
                  await widget.adminService.addAuthObjectField(objectId, {
                    'field_name': name,
                    'field_label': labelCtrl.text.trim(),
                    'field_type': fieldType,
                    'is_required': required,
                    'display_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadDetail(objectId);
                } catch (e) {
                  _showError('$e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteObject(Map<String, dynamic> object) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Authorization Object'),
        content: Text(
          'Delete ${object['object_code']}? Roles using this object may lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.adminService.deleteAuthObject(object['id'].toString());
      setState(() => _selectedDetail = null);
      await _loadObjects();
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _deleteField(String objectId, String fieldId) async {
    try {
      await widget.adminService.deleteAuthObjectField(objectId, fieldId);
      await _loadDetail(objectId);
    } catch (e) {
      _showError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 6,
      onIndexChanged: (_) {},
      title: 'Authorization Objects',
      body: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                final list = _objectList();
                final detail = _detailPane();
                if (!wide) {
                  return Column(
                    children: [
                      SizedBox(height: 320, child: list),
                      const Divider(height: 1),
                      Expanded(child: detail),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 430, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 340,
            height: 48,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search object code or description',
              ),
            ),
          ),
          _classChip('All', null),
          ..._classes.map((c) => _classChip(_classLabel(c), c)),
          SizedBox(
            width: 132,
            height: 40,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Object'),
              onPressed: () => _showObjectDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadObjects,
          ),
        ],
      ),
    );
  }

  Widget _classChip(String label, String? value) {
    final selected = _classFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _classFilter = value);
        _loadObjects();
      },
    );
  }

  Widget _objectList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final list = _filteredObjects;
    if (list.isEmpty) {
      return const Center(child: Text('No authorization objects found'));
    }
    return SelectionArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final obj = list[index] as Map<String, dynamic>;
          final selected = obj['id'] == _selectedDetail?['object']?['id'];
          return Material(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _loadDetail(obj['id'].toString()),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _classBadge(obj['object_class']?.toString() ?? ''),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            obj['object_code']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (obj['is_active'] == true)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      obj['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children:
                          ((obj['activities'] as List<dynamic>?) ?? const [])
                              .map((a) => _miniChip(a.toString()))
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailPane() {
    if (_detailLoading) return const Center(child: CircularProgressIndicator());
    final detail = _selectedDetail;
    if (detail == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.security_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Select an authorization object to view details',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }
    final object = Map<String, dynamic>.from(detail['object'] ?? {});
    final fields = (detail['fields'] as List<dynamic>?) ?? const [];
    final objectId = object['id'].toString();

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _classBadge(object['object_class']?.toString() ?? ''),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              object['object_code']?.toString() ?? '',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        object['description']?.toString() ?? '',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit object',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showObjectDialog(object: object),
                ),
                IconButton(
                  tooltip: 'Delete object',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteObject(object),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('Activities'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ((object['activities'] as List<dynamic>?) ?? const [])
                  .map((a) => Chip(label: Text(a.toString())))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _sectionTitle('Authorization Fields')),
                SizedBox(
                  width: 118,
                  height: 36,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                    onPressed: () => _showFieldDialog(objectId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (fields.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No fields maintained for this object.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Field Name')),
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Required')),
                    DataColumn(label: Text('Order')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: fields.map((raw) {
                    final field = Map<String, dynamic>.from(raw as Map);
                    return DataRow(
                      cells: [
                        DataCell(Text(field['field_name']?.toString() ?? '')),
                        DataCell(Text(field['field_label']?.toString() ?? '')),
                        DataCell(Text(field['field_type']?.toString() ?? '')),
                        DataCell(
                          Icon(
                            field['is_required'] == true
                                ? Icons.check_circle
                                : Icons.remove_circle_outline,
                            size: 18,
                            color: field['is_required'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        DataCell(Text('${field['display_order'] ?? 0}')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Delete field',
                            onPressed: () =>
                                _deleteField(objectId, field['id'].toString()),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),
            _sectionTitle('How This Object Is Used'),
            const SizedBox(height: 8),
            Text(
              'Roles grant access by assigning this authorization object and enabling activities such as read, create, update, delete, approve, or print. Field rows define optional restrictions like company code, plant, warehouse, GL account, sales organization, or work center.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  Widget _classBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _classColor(value).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _classLabel(value),
        style: TextStyle(
          color: _classColor(value),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }

  Color _classColor(String value) {
    switch (value) {
      case 'finance':
        return Colors.teal;
      case 'logistics':
        return Colors.indigo;
      case 'procurement':
        return Colors.blue;
      case 'sales':
        return Colors.deepPurple;
      case 'production':
        return Colors.orange;
      case 'admin':
        return Colors.redAccent;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _classLabel(String value) {
    switch (value) {
      case 'finance':
        return 'Finance';
      case 'logistics':
        return 'Logistics';
      case 'procurement':
        return 'Procurement';
      case 'sales':
        return 'Sales';
      case 'production':
        return 'Production';
      case 'admin':
        return 'Admin';
      default:
        return value.isEmpty ? 'Other' : value;
    }
  }

  static const List<String> _activityOptions = [
    'read',
    'create',
    'update',
    'delete',
    'approve',
    'print',
    'transfer',
    'close',
    'open',
    'schedule',
  ];
}
