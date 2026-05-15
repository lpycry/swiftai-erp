import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_screen.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class JournalEntryListScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService? orgService;

  const JournalEntryListScreen({
    super.key,
    required this.authService,
    required this.glService,
    this.orgService,
  });

  @override
  State<JournalEntryListScreen> createState() => _JournalEntryListScreenState();
}

class _JournalEntryListScreenState extends State<JournalEntryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['draft', 'posted'];
  static const _tabLabels = <String, String>{'draft': 'Draft', 'posted': 'Posted'};

  final Map<String, List<dynamic>> _data = {};
  final Map<String, bool> _loading = {};
  bool _reverseLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final key = _tabs[_tabController.index];
        if (!_data.containsKey(key)) _loadTab(key);
      }
    });
    _loadTab('draft');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(String status) async {
    setState(() => _loading[status] = true);
    try {
      final list = await widget.glService.listJournalEntries(status: status);
      setState(() {
        _data[status] = list;
        _loading[status] = false;
      });
    } catch (e) {
      setState(() => _loading[status] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ── Draft actions ──

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this draft entry? This cannot be undone.'),
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
    if (confirmed != true) return;
    try {
      await widget.glService.deleteJournalEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted'), backgroundColor: Colors.green),
        );
        _loadTab('draft');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _editEntry(dynamic entry) async {
    try {
      final detail = await widget.glService.getJournalEntry(entry['id']!.toString());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JournalEntryScreen(
            authService: widget.authService,
            glService: widget.glService,
            orgService: widget.orgService ?? OrgService(widget.authService.accessToken ?? ''),
            existingEntry: detail,
          ),
        ),
      );
      _loadTab('draft');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entry: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ── Posted actions ──

  Future<void> _reverseEntry(String id) async {
    if (_reverseLoading) return;
    setState(() => _reverseLoading = true);
    try {
      await widget.glService.unpostJournalEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry reversed to draft'), backgroundColor: Colors.green),
        );
        _loadTab('posted');
        _loadTab('draft');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reverse failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _reverseLoading = false);
    }
  }

  Future<void> _confirmReverse(String id, String docNo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Entry'),
        content: Text('Reverse "$docNo"?\n\nThis will set the entry back to draft and remove its effect from account balances.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _reverseEntry(id);
  }

  // ── View Detail ──

  void _viewDetail(dynamic entry) async {
    try {
      final detail = await widget.glService.getJournalEntry(entry['id']!.toString());
      if (mounted) _showDetailDialog(detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showDetailDialog(Map<String, dynamic> entry) {
    final lines = (entry['lines'] as List<dynamic>?) ?? [];
    final status = entry['status']?.toString() ?? 'draft';
    final docNo = entry['document_no']?.toString() ?? 'N/A';

    double totalDebit = 0, totalCredit = 0;
    for (final l in lines) {
      totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
      totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'posted' ? Icons.check_circle : Icons.edit_note,
              color: status == 'posted' ? AppTheme.successColor : AppTheme.warningColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(docNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (status == 'posted' ? AppTheme.successColor : AppTheme.warningColor).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                  color: status == 'posted' ? AppTheme.successColor : AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Description', entry['description']?.toString() ?? ''),
                _detailRow('Posting Date', _fmtDate(entry['posting_date'])),
                _detailRow('Document Date', _fmtDate(entry['document_date'])),
                _detailRow('Reference', entry['reference']?.toString() ?? ''),
                _detailRow('Type', entry['entry_type']?.toString() ?? 'normal'),
                if (entry['organization_name'] != null && (entry['organization_name'] as String).isNotEmpty)
                  _detailRow('Company', entry['organization_name'] as String),
                const Divider(height: 16),

                // Lines table
                const Text('Line Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 1, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 1, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 2, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                          ],
                        ),
                      ),
                      ...lines.asMap().entries.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text('${e.value['account_code'] ?? ''} ${e.value['account_name'] ?? ''}', style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 1, child: Text(
                              ((e.value['debit'] as num?)?.toDouble() ?? 0) > 0
                                  ? '\$${GlService.fmtAmount(e.value['debit'] as num?)}' : '',
                              textAlign: TextAlign.right, style: const TextStyle(fontSize: 11),
                            )),
                            Expanded(flex: 1, child: Text(
                              ((e.value['credit'] as num?)?.toDouble() ?? 0) > 0
                                  ? '\$${GlService.fmtAmount(e.value['credit'] as num?)}' : '',
                              textAlign: TextAlign.right, style: const TextStyle(fontSize: 11),
                            )),
                            Expanded(flex: 2, child: Text(e.value['description']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                          ],
                        ),
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(flex: 1, child: Text('\$${GlService.fmtAmount(totalDebit)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(flex: 1, child: Text('\$${GlService.fmtAmount(totalCredit)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            const Expanded(flex: 2, child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Helpers ──

  String _fmtDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Map<String, dynamic> _tabIconAndColor(String key) {
    switch (key) {
      case 'draft':
        return {'icon': Icons.edit_note, 'color': AppTheme.warningColor};
      case 'posted':
        return {'icon': Icons.check_circle_outline, 'color': AppTheme.successColor};
      default:
        return {'icon': Icons.receipt_long, 'color': Colors.grey};
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Journal Entries',
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.accentBlue,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _tabs.map((key) {
                final count = _data[key]?.length;
                final meta = _tabIconAndColor(key);
                return Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(meta['icon'] as IconData, size: 16),
                        const SizedBox(width: 4),
                        Text(_tabLabels[key]!, style: const TextStyle(fontSize: 13)),
                        if (count != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: (meta['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count', style: TextStyle(fontSize: 10, color: meta['color'] as Color, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((key) => _buildTab(key)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String key) {
    final loading = _loading[key] ?? false;
    final data = _data[key];

    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data == null || data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No ${_tabLabels[key]!.toLowerCase()} entries', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTab(key),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: data.length,
        itemBuilder: (context, i) => _buildCard(data[i], key),
      ),
    );
  }

  Widget _buildCard(dynamic entry, String key) {
    final meta = _tabIconAndColor(key);
    final statusColor = meta['color'] as Color;
    final dateStr = _fmtDate(entry['posting_date'] ?? entry['date']);
    final docNo = entry['document_no']?.toString() ?? 'N/A';
    final total = entry['total_debit'] as num? ?? entry['debit_sum'] as num? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: InkWell(
        onTap: () => _viewDetail(entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(meta['icon'] as IconData, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(docNo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      entry['description']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              // Amount + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${GlService.fmtAmount(total)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      key.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              // Action
              _buildActionButton(entry, key),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(dynamic entry, String key) {
    final id = entry['id']?.toString() ?? '';
    final docNo = entry['document_no']?.toString() ?? '';

    switch (key) {
      case 'draft':
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
          onSelected: (v) {
            if (v == 'view') _viewDetail(entry);
            if (v == 'edit') _editEntry(entry);
            if (v == 'delete') _deleteEntry(id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: ListTile(
              dense: true, leading: Icon(Icons.visibility_outlined, size: 18),
              title: Text('View', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero,
            )),
            const PopupMenuItem(value: 'edit', child: ListTile(
              dense: true, leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero,
            )),
            const PopupMenuItem(value: 'delete', child: ListTile(
              dense: true, leading: Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
              title: Text('Delete', style: TextStyle(fontSize: 13, color: AppTheme.errorColor)), contentPadding: EdgeInsets.zero,
            )),
          ],
        );

      case 'posted':
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
          onSelected: (v) {
            if (v == 'view') _viewDetail(entry);
            if (v == 'reverse') _confirmReverse(id, docNo);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: ListTile(
              dense: true, leading: Icon(Icons.visibility_outlined, size: 18),
              title: Text('View', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero,
            )),
            const PopupMenuItem(value: 'reverse', child: ListTile(
              dense: true, leading: Icon(Icons.undo, size: 18, color: AppTheme.errorColor),
              title: Text('Reverse', style: TextStyle(fontSize: 13, color: AppTheme.errorColor)), contentPadding: EdgeInsets.zero,
            )),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
