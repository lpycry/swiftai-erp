import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';
import 'package:swiftai_erp/features/settings/screens/org_detail_screen.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class OrganizationsScreen extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;

  const OrganizationsScreen({
    super.key,
    required this.authService,
    required this.orgService,
  });

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  List<dynamic> _orgs = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _searchQuery => _searchCtrl.text.trim();

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _loadOrgs);
  }

  Future<void> _loadOrgs() async {
    setState(() => _loading = true);
    try {
      _orgs = await widget.orgService.getOrganizations(search: _searchQuery);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _orgColor(String code) {
    final hash = code.hashCode;
    final colors = [
      Colors.blue, Colors.teal, Colors.indigo, Colors.cyan,
      Colors.deepPurple, Colors.orange, Colors.brown,
    ];
    return colors[hash.abs() % colors.length];
  }

  // ═══════════════════════════════════════
  //  Create Dialog
  // ═══════════════════════════════════════

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'USD');
    final taxIdCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final websiteCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Organization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Organization Code', hintText: 'e.g. 1000'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Organization Name', hintText: 'e.g. US Entity'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currencyCtrl,
                        decoration: const InputDecoration(labelText: 'Currency', hintText: 'USD'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: taxIdCtrl,
                        decoration: const InputDecoration(labelText: 'Tax ID', hintText: 'optional'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'contact@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', hintText: '+1 555-1234'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: websiteCtrl,
                        decoration: const InputDecoration(labelText: 'Website', hintText: 'https://example.com'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', hintText: 'optional'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                try {
                  await widget.orgService.createOrganization({
                    'org_code': codeCtrl.text,
                    'org_name': nameCtrl.text,
                    'currency': currencyCtrl.text.ifEmpty('USD'),
                    'tax_id': taxIdCtrl.text,
                    'email': emailCtrl.text,
                    'phone': phoneCtrl.text,
                    'website': websiteCtrl.text,
                    'address': addressCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadOrgs();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Edit Dialog
  // ═══════════════════════════════════════

  void _showEditDialog(dynamic org) {
    final nameCtrl = TextEditingController(text: org['org_name'] ?? '');
    final currencyCtrl = TextEditingController(text: org['currency'] ?? 'USD');
    final taxIdCtrl = TextEditingController(text: org['tax_id'] ?? '');
    final emailCtrl = TextEditingController(text: org['email'] ?? '');
    final phoneCtrl = TextEditingController(text: org['phone'] ?? '');
    final websiteCtrl = TextEditingController(text: org['website'] ?? '');
    final addressCtrl = TextEditingController(text: org['address'] ?? '');
    final orgId = org['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit Organization — ${org['org_code'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Organization Name', hintText: 'e.g. US Entity'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: currencyCtrl,
                        decoration: const InputDecoration(labelText: 'Currency', hintText: 'USD'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: taxIdCtrl,
                        decoration: const InputDecoration(labelText: 'Tax ID', hintText: 'optional'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'contact@example.com'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', hintText: '+1 555-1234'),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: websiteCtrl,
                        decoration: const InputDecoration(labelText: 'Website', hintText: 'https://example.com'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', hintText: 'optional'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                try {
                  await widget.orgService.updateOrganization(orgId, {
                    'org_name': nameCtrl.text,
                    'currency': currencyCtrl.text.ifEmpty('USD'),
                    'tax_id': taxIdCtrl.text,
                    'email': emailCtrl.text,
                    'phone': phoneCtrl.text,
                    'website': websiteCtrl.text,
                    'address': addressCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadOrgs();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Organization updated'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
              child: const Text('Save'),
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
      title: 'Organizations',
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by org code or name...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
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
          // Toolbar row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Legal Entities / Company Codes',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                if (_searchQuery.isNotEmpty)
                  Text('${_orgs.length} result(s)',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  onPressed: _showCreateDialog,
                  tooltip: 'Add Organization',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrgs),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orgs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No organizations match "$_searchQuery"'
                                  : 'No organizations defined',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _orgs.length,
                        itemBuilder: (context, i) => _OrgCard(
                          org: _orgs[i],
                          orgColor: _orgColor(_orgs[i]['org_code'] ?? ''),
                          onTap: () => _openOrgDetail(_orgs[i]),
                          onEdit: () => _showEditDialog(_orgs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _openOrgDetail(dynamic org) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrgDetailScreen(
          authService: widget.authService,
          orgService: widget.orgService,
          warehouseService: WarehouseService(widget.authService.accessToken ?? ''),
          orgId: org['id'],
          orgCode: org['org_code'] ?? '',
          orgName: org['org_name'] ?? '',
          orgCurrency: org['currency'] ?? 'USD',
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ContactChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 10, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _OrgCard extends StatelessWidget {
  final dynamic org;
  final Color orgColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _OrgCard({
    required this.org,
    required this.orgColor,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = org['is_active'] as bool? ?? true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: orgColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              org['org_code'] ?? '?',
              style: TextStyle(
                color: orgColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          org['org_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(org['org_code'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    org['currency'] ?? 'USD',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
                if (org['tax_id'] != null && org['tax_id'] != '') ...[
                  const SizedBox(width: 6),
                  Text(org['tax_id'], style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                if (org['email'] != null && org['email'] != '')
                  _ContactChip(icon: Icons.email_outlined, text: org['email'], color: Colors.green.shade600),
                if (org['phone'] != null && org['phone'] != '')
                  _ContactChip(icon: Icons.phone_outlined, text: org['phone'], color: Colors.orange.shade700),
                if (org['website'] != null && org['website'] != '')
                  _ContactChip(icon: Icons.language_outlined, text: org['website'], color: Colors.purple.shade600),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade400),
              onPressed: onEdit,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

extension StringIfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
