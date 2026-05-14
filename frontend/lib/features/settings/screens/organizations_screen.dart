import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';
import 'package:swiftai_erp/features/settings/screens/sites_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    setState(() => _loading = true);
    try {
      _orgs = await widget.orgService.getOrganizations();
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

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'USD');
    final taxIdCtrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 5,
      onIndexChanged: (_) {},
      title: 'Organizations',
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Legal Entities / Company Codes',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
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
                    ? const Center(child: Text('No organizations defined'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _orgs.length,
                        itemBuilder: (context, i) => _OrgCard(
                          org: _orgs[i],
                          orgColor: _orgColor(_orgs[i]['org_code'] ?? ''),
                          onTap: () => _openOrgDetail(_orgs[i]),
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
        builder: (_) => SitesScreen(
          authService: widget.authService,
          orgService: widget.orgService,
          orgId: org['id'],
          orgCode: org['org_code'] ?? '',
          orgName: org['org_name'] ?? '',
          orgCurrency: org['currency'] ?? 'USD',
        ),
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final dynamic org;
  final Color orgColor;
  final VoidCallback onTap;

  const _OrgCard({
    required this.org,
    required this.orgColor,
    required this.onTap,
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
        subtitle: Row(
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
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }
}

extension StringIfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
