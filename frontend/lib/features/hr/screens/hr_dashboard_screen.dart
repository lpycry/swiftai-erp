import 'dart:async';
import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/hr/services/department_service.dart';
import 'package:swiftai_erp/features/hr/services/employee_service.dart';
import 'package:swiftai_erp/features/hr/services/position_service.dart';
import 'package:swiftai_erp/features/hr/screens/department_screen.dart';
import 'package:swiftai_erp/features/hr/screens/employee_list_screen.dart';

class HrDashboardScreen extends StatelessWidget {
  final AuthService authService;
  const HrDashboardScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final token = authService.accessToken ?? '';
    return AppLayout(
      authService: authService,
      currentIndex: 5,
      onIndexChanged: (_) {},
      title: 'Human Resources',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF37474F), Color(0xFF607D8B)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Human Resources',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organization structure, employee master data & administration',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Master Data
            _sectionTitle(context, 'Master Data'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _HrCard(
                  icon: Icons.people_outlined,
                  title: 'Employees',
                  subtitle: 'Employee master data with SAP Infotype timeline',
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeListScreen(
                        authService: authService,
                        employeeService: EmployeeService(token),
                      ),
                    ),
                  ),
                ),
                _HrCard(
                  icon: Icons.account_tree_outlined,
                  title: 'Departments',
                  subtitle:
                      'Org units with hierarchy, cost center binding & time validity',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DepartmentScreen(
                        authService: authService,
                        departmentService: DepartmentService(token),
                      ),
                    ),
                  ),
                ),
                _HrCard(
                  icon: Icons.work_outline,
                  title: 'Positions',
                  subtitle:
                      'Position hierarchy linked to org units & departments',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _PositionScreen(
                        authService: authService,
                        positionService: PositionService(token),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _HrCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _HrCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return SizedBox(
      width: isWide ? 260 : double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Position Screen (inline for simplicity) ──

class _PositionScreen extends StatefulWidget {
  final AuthService authService;
  final PositionService positionService;
  const _PositionScreen({
    required this.authService,
    required this.positionService,
  });
  @override
  State<_PositionScreen> createState() => _PositionScreenState();
}

class _PositionScreenState extends State<_PositionScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _treeMode = false;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), _load);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  String get _q => _searchCtrl.text.trim();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await widget.positionService.getPositions(
        search: _q.isEmpty ? null : _q,
        tree: _treeMode && _q.isEmpty,
      );
    } catch (e) {
      if (mounted) _msg('Failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ),
    );
  }

  void _showCreateDialog({dynamic parent}) {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    DateTime validFrom = DateTime.now();
    DateTime? validTo;
    bool isActive = true;
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            parent != null
                ? 'New Position under ${parent['position_code']}'
                : 'New Position',
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Position Code *',
                      hintText: 'e.g. P-1001',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Position Title *',
                      hintText: 'e.g. Senior Developer',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: validFrom,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDlg(() => validFrom = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Valid From',
                            ),
                            child: Text(Fmt.d(validFrom)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: validTo ?? validFrom,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDlg(() => validTo = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Valid To (opt)',
                            ),
                            child: Text(validTo == null ? '' : Fmt.d(validTo)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isActive,
                    onChanged: (v) => setDlg(() => isActive = v ?? true),
                    title: const Text('Active', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
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
            FilledButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || titleCtrl.text.isEmpty) return;
                try {
                  final data = <String, dynamic>{
                    'position_code': codeCtrl.text,
                    'position_title': titleCtrl.text,
                    'is_active': isActive,
                    'valid_from': iso(validFrom),
                    'valid_to': validTo == null ? '' : iso(validTo!),
                  };
                  if (parent != null) data['parent_position_id'] = parent['id'];
                  await widget.positionService.createPosition(data);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  _msg('Position created');
                } catch (e) {
                  _msg('$e', isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(dynamic item) {
    final titleCtrl = TextEditingController(text: item['position_title'] ?? '');
    final fromCtrl = TextEditingController(
      text: _cleanDate(item['valid_from']),
    );
    final toCtrl = TextEditingController(text: _cleanDate(item['valid_to']));
    bool isActive = item['is_active'] as bool? ?? true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Edit — ${item['position_code'] ?? ''}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Position Title *',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid From',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid To',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v ?? true),
                  title: const Text('Active', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
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
                try {
                  await widget.positionService
                      .updatePosition(item['id'].toString(), {
                        'position_title': titleCtrl.text,
                        'is_active': isActive,
                        'valid_from': fromCtrl.text,
                        'valid_to': toCtrl.text,
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  _msg('Position updated');
                } catch (e) {
                  _msg('$e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Position'),
        content: Text(
          'Delete "${item['position_code']} — ${item['position_title']}"?',
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
    if (ok == true) {
      try {
        await widget.positionService.deletePosition(item['id'].toString());
        _load();
        _msg('Deleted');
      } catch (e) {
        _msg('$e', isError: true);
      }
    }
  }

  String _cleanDate(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    return Fmt.dateStr(d);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 5,
      onIndexChanged: (_) {},
      title: 'Positions',
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Positions',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _showCreateDialog(),
                  tooltip: 'Add Position',
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
                    child: Text(
                      'No positions',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: _treeMode && _q.isEmpty
                        ? _items.map((r) => _buildTree(r, 0)).toList()
                        : _items
                              .map(
                                (i) => _PosCard(
                                  item: i,
                                  onEdit: () => _showEditDialog(i),
                                  onDelete: () => _confirmDelete(i),
                                ),
                              )
                              .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTree(dynamic node, int depth) {
    final children = (node['children'] as List<dynamic>?) ?? [];
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            dense: true,
            leading: Container(
              margin: EdgeInsets.only(left: depth * 24.0),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.work_outline, size: 16, color: Colors.teal),
            ),
            title: Row(
              children: [
                Text(
                  '${node['position_code'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  node['position_title'] ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: 16,
                    color: Colors.blue.shade400,
                  ),
                  onPressed: () => _showCreateDialog(parent: node),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Colors.blue.shade400,
                  ),
                  onPressed: () => _showEditDialog(node),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
                if (children.isEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _confirmDelete(node),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
        ...children.map((c) => _buildTree(c, depth + 1)),
      ],
    );
  }
}

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
          _Btn(
            icon: Icons.list,
            label: 'List',
            selected: !isTree,
            onTap: () => onChanged(false),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _Btn(
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

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Btn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            Icon(
              icon,
              size: 14,
              color: selected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PosCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(Icons.work_outline, color: Colors.teal, size: 22),
          ),
        ),
        title: Row(
          children: [
            Text(
              item['position_code'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item['position_title'] ?? '',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        subtitle: Text(
          item['org_unit_id'] != null
              ? 'Linked to org unit'
              : 'No org unit binding',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.blue.shade400,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.shade400,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
