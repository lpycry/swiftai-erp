import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';

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
  bool _loading = true;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _loading = true);
    try {
      _roles = await widget.adminService.getRoles(category: _categoryFilter);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'single';
    String category = 'admin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Role ID (e.g. Z_CUSTOM_ROLE)'),
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
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Single')),
                  DropdownMenuItem(value: 'composite', child: Text('Composite')),
                  DropdownMenuItem(value: 'derived', child: Text('Derived')),
                ],
                onChanged: (v) => setDlgState(() => type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'logistics', child: Text('Logistics')),
                  DropdownMenuItem(value: 'procurement', child: Text('Procurement')),
                  DropdownMenuItem(value: 'sales', child: Text('Sales')),
                ],
                onChanged: (v) => setDlgState(() => category = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await widget.adminService.createRole({
                    'role_id': nameCtrl.text,
                    'description': descCtrl.text,
                    'role_type': type,
                    'role_category': category,
                  });
                  navigator.pop();
                  _loadRoles();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 5,
      onIndexChanged: (_) {},
      title: 'Role Management',
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip2('All', null, _categoryFilter == null, () {
                  setState(() => _categoryFilter = null);
                  _loadRoles();
                }),
                const SizedBox(width: 6),
                _FilterChip2('Finance', 'finance', _categoryFilter == 'finance', () {
                  setState(() => _categoryFilter = 'finance');
                  _loadRoles();
                }),
                const SizedBox(width: 6),
                _FilterChip2('Logistics', 'logistics', _categoryFilter == 'logistics', () {
                  setState(() => _categoryFilter = 'logistics');
                  _loadRoles();
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  onPressed: _showCreateDialog,
                  tooltip: 'Create Role',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRoles),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _roles.isEmpty
                    ? const Center(child: Text('No roles defined'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _roles.length,
                        itemBuilder: (context, i) => _RoleCard(
                          role: _roles[i],
                          onAssign: () {},
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip2(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final dynamic role;
  final VoidCallback onAssign;

  const _RoleCard({required this.role, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final type = role['role_type'] ?? 'single';
    final category = role['role_category'] ?? '';

    Color typeColor;
    switch (type) {
      case 'composite':
        typeColor = Colors.orange;
        break;
      case 'derived':
        typeColor = Colors.purple;
        break;
      default:
        typeColor = AppTheme.primaryLight;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              (role['role_id'] ?? '?').toString()[0],
              style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(role['role_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role['description'] != null) Text(role['description'], maxLines: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                _Badge(type, typeColor),
                if (category != '') ...[
                  const SizedBox(width: 6),
                  _Badge(category, Colors.grey),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'auth') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Placeholder(), // TODO: Auth values screen
                ),
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'auth', child: Text('Edit Auth Values')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
