import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class SitesScreen extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;
  final String orgId;
  final String orgCode;
  final String orgName;
  final String orgCurrency;

  const SitesScreen({
    super.key,
    required this.authService,
    required this.orgService,
    required this.orgId,
    required this.orgCode,
    required this.orgName,
    required this.orgCurrency,
  });

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  List<dynamic> _sites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _loading = true);
    try {
      _sites = await widget.orgService.getSitesByOrg(widget.orgId);
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

  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String siteType = 'warehouse';
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Site'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Site Code', hintText: 'e.g. WH01'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Site Name', hintText: 'e.g. Main Warehouse'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: siteType,
                  decoration: const InputDecoration(labelText: 'Site Type'),
                  items: const [
                    DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                    DropdownMenuItem(value: 'plant', child: Text('Plant / Factory')),
                    DropdownMenuItem(value: 'store', child: Text('Store / Retail')),
                    DropdownMenuItem(value: 'office', child: Text('Office')),
                  ],
                  onChanged: (v) => setDlgState(() => siteType = v!),
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
                  await widget.orgService.createSite({
                    'organization_id': widget.orgId,
                    'site_code': codeCtrl.text,
                    'site_name': nameCtrl.text,
                    'site_type': siteType,
                    'address': addressCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadSites();
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

  void _showEditDialog(dynamic site) {
    final nameCtrl = TextEditingController(text: site['site_name'] ?? '');
    final addressCtrl = TextEditingController(text: site['address'] ?? '');
    String siteType = site['site_type'] ?? 'warehouse';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit Site'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Site Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: siteType,
                decoration: const InputDecoration(labelText: 'Site Type'),
                items: const [
                  DropdownMenuItem(value: 'warehouse', child: Text('Warehouse')),
                  DropdownMenuItem(value: 'plant', child: Text('Plant / Factory')),
                  DropdownMenuItem(value: 'store', child: Text('Store / Retail')),
                  DropdownMenuItem(value: 'office', child: Text('Office')),
                ],
                onChanged: (v) => setDlgState(() => siteType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.orgService.updateSite(site['id'], {
                    'site_name': nameCtrl.text,
                    'site_type': siteType,
                    'address': addressCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadSites();
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

  Future<void> _confirmDelete(dynamic site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site'),
        content: Text('Delete "${site['site_code']} ${site['site_name']}"?'),
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
    if (confirmed == true) {
      try {
        await widget.orgService.deleteSite(site['id']);
        _loadSites();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.orgName, style: const TextStyle(fontSize: 18)),
            Text(
              '${widget.orgCode} · ${widget.orgCurrency}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Business Units / Locations',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  onPressed: _showCreateDialog,
                  tooltip: 'Add Site',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sites.isEmpty
                    ? const Center(child: Text('No sites defined'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sites.length,
                        itemBuilder: (context, i) => _SiteCard(
                          site: _sites[i],
                          onEdit: () => _showEditDialog(_sites[i]),
                          onDelete: () => _confirmDelete(_sites[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final dynamic site;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SiteCard({
    required this.site,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = site['site_type'] ?? 'warehouse';
    final isActive = site['is_active'] as bool? ?? true;

    IconData icon;
    Color color;
    switch (type) {
      case 'plant':
        icon = Icons.factory;
        color = Colors.orange;
        break;
      case 'store':
        icon = Icons.store;
        color = Colors.green;
        break;
      case 'office':
        icon = Icons.business;
        color = Colors.purple;
        break;
      default:
        icon = Icons.warehouse;
        color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          site['site_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(site['site_code'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type[0].toUpperCase() + type.substring(1),
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
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
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
