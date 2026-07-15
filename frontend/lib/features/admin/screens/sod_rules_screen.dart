import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';

class SoDRulesScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;

  const SoDRulesScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<SoDRulesScreen> createState() => _SoDRulesScreenState();
}

class _SoDRulesScreenState extends State<SoDRulesScreen> {
  List<dynamic> _rules = [];
  List<dynamic> _objects = [];
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
        widget.adminService.getSoDRules(),
        widget.adminService.getAuthObjects(),
      ]);
      _rules = results[0];
      _objects = results[1];
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

  String _objectLabel(String? id) {
    for (final obj in _objects) {
      if ((obj['id'] ?? '').toString() == id) {
        return '${obj['object_code']} - ${obj['description'] ?? ''}';
      }
    }
    return id ?? '';
  }

  Future<void> _newRule() async {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String severity = 'high';
    String? objectAId;
    String? objectBId;
    String activityA = 'read';
    String activityB = 'update';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('New SoD Rule'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Rule Code *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Dropdown(
                        label: 'Object A *',
                        value: objectAId,
                        items: _objects,
                        onChanged: (v) => setDlgState(() => objectAId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      child: _ActivityDropdown(
                        label: 'Activity A',
                        value: activityA,
                        onChanged: (v) => setDlgState(() => activityA = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Dropdown(
                        label: 'Object B *',
                        value: objectBId,
                        items: _objects,
                        onChanged: (v) => setDlgState(() => objectBId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 150,
                      child: _ActivityDropdown(
                        label: 'Activity B',
                        value: activityB,
                        onChanged: (v) => setDlgState(() => activityB = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(
                      value: 'critical',
                      child: Text('Critical'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (v) => setDlgState(() => severity = v ?? severity),
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
                if (codeCtrl.text.trim().isEmpty ||
                    objectAId == null ||
                    objectBId == null)
                  return;
                try {
                  await widget.adminService.createSoDRule({
                    'rule_code': codeCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'severity': severity,
                    'risk_category': 'authorization',
                    'object_a_id': objectAId,
                    'activity_a': activityA,
                    'object_b_id': objectBId,
                    'activity_b': activityB,
                    'is_active': true,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 6,
      onIndexChanged: (_) {},
      title: 'SoD Rules',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Spacer(),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                FilledButton.icon(
                  onPressed: _newRule,
                  icon: const Icon(Icons.add),
                  label: const Text('New Rule'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rules.isEmpty
                ? const Center(child: Text('No SoD rules found'))
                : ListView.separated(
                    itemCount: _rules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final rule = Map<String, dynamic>.from(_rules[index]);
                      return SelectionArea(
                        child: ListTile(
                          title: Text(
                            '${rule['rule_code']}  ${rule['severity']}'
                                .toUpperCase(),
                          ),
                          subtitle: Text(
                            '${_objectLabel(rule['object_a_id']?.toString())} / ${rule['activity_a']}  conflicts with  ${_objectLabel(rule['object_b_id']?.toString())} / ${rule['activity_b']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await widget.adminService.deleteSoDRule(
                                rule['id'],
                              );
                              await _load();
                            },
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

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<dynamic> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (obj) => DropdownMenuItem<String>(
              value: obj['id'],
              child: Text(
                '${obj['object_code']} - ${obj['description'] ?? ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ActivityDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _ActivityDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 'create', child: Text('Create')),
        DropdownMenuItem(value: 'read', child: Text('Read')),
        DropdownMenuItem(value: 'update', child: Text('Update')),
        DropdownMenuItem(value: 'delete', child: Text('Delete')),
        DropdownMenuItem(value: 'approve', child: Text('Approve')),
        DropdownMenuItem(value: 'print', child: Text('Print')),
        DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
        DropdownMenuItem(value: 'close', child: Text('Close')),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
