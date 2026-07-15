import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';

class UsersScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;

  const UsersScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _users = [];
  List<dynamic> _roles = [];
  bool _loading = true;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.adminService.getUsers(search: _searchCtrl.text, status: _status),
        widget.adminService.getRoles(),
      ]);
      _users = results[0];
      _roles = results[1];
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _openUserDialog({Map<String, dynamic>? user}) async {
    final isEdit = user != null;
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final nameCtrl = TextEditingController(text: user?['display_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final passCtrl = TextEditingController();
    bool active = user?['is_active'] ?? true;
    bool mfa = user?['is_mfa_enabled'] ?? false;
    final selectedRoles = <String>{
      for (final role in (user?['roles'] ?? [])) (role['id'] ?? '').toString(),
    }..remove('');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Create User'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Initial Password *',
                      ),
                      obscureText: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setDlgState(() => active = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('MFA Enabled'),
                    value: mfa,
                    onChanged: (v) => setDlgState(() => mfa = v),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Roles',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._roles.map((role) {
                      final id = (role['id'] ?? '').toString();
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(role['role_id'] ?? ''),
                        subtitle: Text(role['description'] ?? ''),
                        value: selectedRoles.contains(id),
                        onChanged: (v) {
                          setDlgState(() {
                            if (v == true) {
                              selectedRoles.add(id);
                            } else {
                              selectedRoles.remove(id);
                            }
                          });
                        },
                      );
                    }),
                  ],
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
                if (emailCtrl.text.trim().isEmpty ||
                    nameCtrl.text.trim().isEmpty ||
                    (!isEdit && passCtrl.text.length < 8)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Email, display name, and password are required.',
                      ),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return;
                }
                try {
                  if (isEdit) {
                    await widget.adminService.updateUser(user['id'], {
                      'email': emailCtrl.text.trim(),
                      'display_name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'is_active': active,
                      'is_mfa_enabled': mfa,
                    });
                  } else {
                    await widget.adminService.createUser({
                      'email': emailCtrl.text.trim(),
                      'display_name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'password': passCtrl.text,
                      'is_active': active,
                      'is_mfa_enabled': mfa,
                      'role_ids': selectedRoles.toList(),
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  _showError(e);
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
  }

  Future<void> _showRoles(Map<String, dynamic> user) async {
    var current = await widget.adminService.getUser(user['id']);
    String? selectedRoleId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final assigned = (current['roles'] ?? []) as List<dynamic>;
          final assignedIds = assigned
              .map((e) => (e['id'] ?? '').toString())
              .toSet();
          final available = _roles
              .where(
                (role) => !assignedIds.contains((role['id'] ?? '').toString()),
              )
              .toList();
          return AlertDialog(
            title: Text('Roles - ${current['display_name'] ?? ''}'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: assigned.isEmpty
                        ? [const Text('No roles assigned')]
                        : assigned.map((role) {
                            return InputChip(
                              label: Text(role['role_id'] ?? ''),
                              onDeleted: () async {
                                await widget.adminService.removeRole(
                                  current['id'],
                                  role['id'],
                                );
                                current = await widget.adminService.getUser(
                                  current['id'],
                                );
                                setDlgState(() {});
                                _load();
                              },
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Add Role'),
                    items: available
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role['id'],
                            child: Text(role['role_id'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlgState(() => selectedRoleId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: selectedRoleId == null
                    ? null
                    : () async {
                        await widget.adminService.assignRole(
                          current['id'],
                          selectedRoleId!,
                        );
                        current = await widget.adminService.getUser(
                          current['id'],
                        );
                        selectedRoleId = null;
                        setDlgState(() {});
                        _load();
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password - ${user['display_name'] ?? ''}'),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (passCtrl.text.length < 8) {
                _showError('Password must be at least 8 characters.');
                return;
              }
              try {
                await widget.adminService.resetUserPassword(
                  user['id'],
                  passCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset complete.')),
                  );
                }
              } catch (e) {
                _showError(e);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    passCtrl.dispose();
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    try {
      await widget.adminService.setUserActive(
        user['id'],
        !(user['is_active'] ?? false),
      );
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 6,
      onIndexChanged: (_) {},
      title: 'User Management',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v ?? 'all');
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search email, name, phone',
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _load,
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('New User'),
                  onPressed: () => _openUserDialog(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _UserTile(
                      user: _users[i],
                      onEdit: () => _openUserDialog(user: _users[i]),
                      onRoles: () => _showRoles(_users[i]),
                      onReset: () => _resetPassword(_users[i]),
                      onToggleActive: () => _toggleActive(_users[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onRoles;
  final VoidCallback onReset;
  final VoidCallback onToggleActive;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onRoles,
    required this.onReset,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final roles = (user['roles'] ?? []) as List<dynamic>;
    final active = user['is_active'] == true;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active ? AppTheme.primaryColor : Colors.grey.shade400,
        child: Text(
          ((user['display_name'] ?? user['email'] ?? 'U').toString())
              .substring(0, 1)
              .toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user['display_name'] ?? '',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(active: active),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user['email'] ?? ''}${(user['phone'] ?? '').toString().isEmpty ? '' : ' | ${user['phone']}'}',
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final role in roles) _SmallChip(role['role_id'] ?? ''),
                if (roles.isEmpty) const _SmallChip('No role'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Last login: ${Fmt.dateTimeStr(user['last_login_at'])}   Created: ${Fmt.dateStr(user['created_at'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (v) {
          switch (v) {
            case 'edit':
              onEdit();
              break;
            case 'roles':
              onRoles();
              break;
            case 'reset':
              onReset();
              break;
            case 'toggle':
              onToggleActive();
              break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'roles', child: Text('Roles')),
          const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
          PopupMenuItem(
            value: 'toggle',
            child: Text(active ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  const _SmallChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
