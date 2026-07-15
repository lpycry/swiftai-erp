import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';

class AccessRequestsScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;

  const AccessRequestsScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen> {
  List<dynamic> _requests = [];
  List<dynamic> _users = [];
  List<dynamic> _roles = [];
  String _status = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.adminService.getAccessRequests(status: _status),
        widget.adminService.getUsers(),
        widget.adminService.getRoles(),
      ]);
      _requests = results[0];
      _users = results[1];
      _roles = results[2];
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

  String _userName(String? id) {
    for (final user in _users) {
      if ((user['id'] ?? '').toString() == id)
        return '${user['display_name'] ?? user['email']}';
    }
    return id ?? '';
  }

  String _roleName(String? id) {
    for (final role in _roles) {
      if ((role['id'] ?? '').toString() == id) return '${role['role_id']}';
    }
    return id ?? '';
  }

  Future<void> _newRequest() async {
    String? userId;
    String? roleId;
    String requestType = 'role_assign';
    final reasonCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('New Access Request'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: userId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Target User *'),
                  items: _users
                      .map(
                        (u) => DropdownMenuItem<String>(
                          value: u['id'],
                          child: Text(
                            '${u['display_name'] ?? u['email']} - ${u['email']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlgState(() => userId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: requestType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Request Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'role_assign',
                      child: Text('Assign Role'),
                    ),
                    DropdownMenuItem(
                      value: 'role_remove',
                      child: Text('Remove Role'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDlgState(() => requestType = v ?? requestType),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: roleId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem<String>(
                          value: r['id'],
                          child: Text(
                            '${r['role_id']} - ${r['description'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlgState(() => roleId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Justification'),
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
                if (userId == null || roleId == null) return;
                try {
                  await widget.adminService.createAccessRequest({
                    'target_user_id': userId,
                    'request_type': requestType,
                    'request_data': {'role_id': roleId},
                    'justification': reasonCtrl.text.trim(),
                    'urgency': 'normal',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  _showError(e);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(String id, String action) async {
    try {
      if (action == 'approve')
        await widget.adminService.approveAccessRequest(id, comment: 'Approved');
      if (action == 'reject')
        await widget.adminService.rejectAccessRequest(id, comment: 'Rejected');
      if (action == 'execute')
        await widget.adminService.executeAccessRequest(id);
      await _load();
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
      title: 'Access Requests',
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
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v ?? 'all');
                      _load();
                    },
                  ),
                ),
                const Spacer(),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                FilledButton.icon(
                  onPressed: _newRequest,
                  icon: const Icon(Icons.add),
                  label: const Text('New Request'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? const Center(child: Text('No access requests found'))
                : ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final req = Map<String, dynamic>.from(_requests[index]);
                      final data = Map<String, dynamic>.from(
                        req['request_data'] ?? {},
                      );
                      final status = (req['approval_status'] ?? '').toString();
                      final executed = req['executed'] == true;
                      return SelectionArea(
                        child: ListTile(
                          leading: Icon(
                            executed
                                ? Icons.verified
                                : Icons.assignment_outlined,
                            color: executed
                                ? Colors.green
                                : AppTheme.primaryColor,
                          ),
                          title: Text(
                            '${req['request_type']}  ${status.toUpperCase()}',
                          ),
                          subtitle: Text(
                            'Target: ${_userName(req['target_user_id']?.toString())}   Role: ${_roleName(data['role_id']?.toString())}   ${req['justification'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Approve',
                                onPressed: status == 'pending'
                                    ? () => _action(req['id'], 'approve')
                                    : null,
                                icon: const Icon(Icons.check_circle_outline),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                onPressed: status == 'pending'
                                    ? () => _action(req['id'], 'reject')
                                    : null,
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                              IconButton(
                                tooltip: 'Execute',
                                onPressed: status == 'approved' && !executed
                                    ? () => _action(req['id'], 'execute')
                                    : null,
                                icon: const Icon(Icons.play_arrow),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
