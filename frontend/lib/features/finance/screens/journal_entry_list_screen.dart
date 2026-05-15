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

class _JournalEntryListScreenState extends State<JournalEntryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Per-tab data
  final Map<String, List<dynamic>> _tabData = {};
  final Map<String, bool> _tabLoading = {};
  final Map<String, String?> _tabErrors = {};

  // Tab definitions: {tabKey: {apiStatus, apiEntryType, label, icon}}
  static const _tabDefs = [
    {'key': 'draft', 'status': 'draft', 'entryType': '', 'label': 'Draft'},
    {'key': 'posted', 'status': 'posted', 'entryType': '', 'label': 'Posted'},
    {'key': 'reversed', 'status': '', 'entryType': 'reversal', 'label': 'Reversed'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final key = _tabDefs[_tabController.index]['key'] as String;
        if (!_tabData.containsKey(key)) _loadTab(_tabDefs[_tabController.index]);
      }
    });
    _loadTab(_tabDefs[0]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(Map tab) async {
    final key = tab['key'] as String;
    setState(() => _tabLoading[key] = true);
    try {
      final data = await widget.glService.listJournalEntries(
        status: (tab['status'] as String).isNotEmpty ? tab['status'] as String : null,
        entryType: (tab['entryType'] as String).isNotEmpty ? tab['entryType'] as String : null,
      );
      setState(() {
        _tabData[key] = data;
        _tabLoading[key] = false;
        _tabErrors.remove(key);
      });
    } catch (e) {
      setState(() {
        _tabLoading[key] = false;
        _tabErrors[key] = e.toString();
      });
    }
  }

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
        _loadTab(_tabDefs[0]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _reverseEntry(String id, String postingDateStr) async {
    final postingDate = DateTime.tryParse(postingDateStr) ?? DateTime.now();
    final periodOpen = await widget.glService.isPeriodOpenForDate(postingDate);
    if (!periodOpen) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.red, size: 22),
                SizedBox(width: 10),
                Text('Period Closed', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: const Text(
              'Account Period is closed!\n\nThe reversal cannot be saved because the posting period is not open.',
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Entry'),
        content: const Text('Create a reversing entry for this posted entry?'),
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
    if (confirmed != true) return;
    try {
      await widget.glService.unpostJournalEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry reversed successfully'), backgroundColor: Colors.green),
        );
        _loadTab(_tabDefs[1]); // reload posted
        _loadTab(_tabDefs[2]); // reload reversed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reverse failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _editDraft(dynamic entry) async {
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
      _loadTab(_tabDefs[0]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entry: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _viewDetail(dynamic entry) async {
    try {
      final detail = await widget.glService.getJournalEntry(entry['id']!.toString());
      if (mounted) _showDetailDialog(detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load detail: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ── Detail Dialog (matches journal_entry_screen's style) ──

    void _fetchAndShowAttachments(BuildContext ctx, String entryId) async {
    try {
      final detail = await widget.glService.getJournalEntry(entryId);
      var attachmentList = detail['attachments'] as List<dynamic>?;
      // If attachments not pre-loaded, try fetching separately
      if (attachmentList == null || attachmentList.isEmpty) {
        // No separate attachments endpoint available via GlService
        // Try the getAttachments if it exists
      }
      // Show simple dialog with attachment count
      if (ctx.mounted) {
        Navigator.pop(ctx);
        _showAttachmentsForEntry(entryId);
      }
    } catch (_) {
      // Silently handle
    }
  }

  void _showAttachmentsForEntry(String entryId) async {
    final detail = await widget.glService.getJournalEntry(entryId);
    final attachments = detail['attachments'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: 8),
                  Text('Attachments ()', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: attachments.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Text('No attachments'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: attachments.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.attach_file, size: 20),
                        title: Text(attachments[i]['file_name']?.toString() ?? 'Attachment'),
                        subtitle: attachments[i]['file_size'] != null
                            ? Text(' bytes')
                            : null,
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
void _showDetailDialog(Map<String, dynamic> entry) {
    final lines = (entry['lines'] as List<dynamic>?) ?? [];
    final status = entry['status']?.toString() ?? 'draft';

    double totalDebit = 0, totalCredit = 0;
    for (final l in lines) {
      totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
      totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
    }

    final docNo = entry['document_no']?.toString() ?? 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'posted' ? Icons.check_circle : status == 'draft' ? Icons.edit_note : Icons.undo,
              color: status == 'posted' ? AppTheme.successColor : status == 'draft' ? AppTheme.warningColor : AppTheme.errorColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(docNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            _StatusBadge(status),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header info
                _detailRow('Description', entry['description']?.toString() ?? ''),
                _detailRow('Posting Date', _fmtDate(entry['posting_date'])),
                _detailRow('Document Date', _fmtDate(entry['document_date'])),
                _detailRow('Reference', entry['reference']?.toString() ?? ''),
                _detailRow('Type', entry['entry_type']?.toString() ?? 'normal'),
                if (entry['organization_name'] != null && (entry['organization_name'] as String).isNotEmpty)
                  _detailRow('Company', entry['organization_name'] as String)
                else if (entry['organization_id'] != null)
                  _detailRow('Company', entry['organization_id'].toString()),
                const Divider(height: 16),
                // Lines
                const Text('Line Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      // Header row
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
                      // Line rows
                      ...lines.asMap().entries.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(
                              '${e.value['account_code'] ?? ''} ${e.value['account_name'] ?? ''}',
                              style: const TextStyle(fontSize: 11),
                            )),
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
                            Expanded(flex: 2, child: Text(
                              e.value['description']?.toString() ?? '',
                              style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis,
                            )),
                          ],
                        ),
                      )),
                      // Totals
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            Expanded(flex: 1, child: Text(
                              '\$${GlService.fmtAmount(totalDebit)}',
                              textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            )),
                            Expanded(flex: 1, child: Text(
                              '\$${GlService.fmtAmount(totalCredit)}',
                              textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            )),
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
          TextButton(
            onPressed: () => _fetchAndShowAttachments(ctx, entry['id']!.toString()),
            child: const Text('Attachments'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

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
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
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
          // Narrow tab bar, left-aligned
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
              tabs: _tabDefs.map((tab) {
                final key = tab['key'] as String;
                final label = tab['label'] as String;
                final count = _tabData[key]?.length;
                return Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tabIcon(key), size: 16),
                        const SizedBox(width: 4),
                        Text(label, style: const TextStyle(fontSize: 13)),
                        if (count != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tabColor(key).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count', style: TextStyle(fontSize: 10, color: _tabColor(key), fontWeight: FontWeight.w600)),
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
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabDefs.map((tab) => _buildTabContent(tab['key'] as String)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _tabIcon(String key) {
    switch (key) {
      case 'draft': return Icons.edit_note;
      case 'posted': return Icons.check_circle_outline;
      case '': return Icons.undo;
      default: return Icons.receipt_long;
    }
  }

  Color _tabColor(String key) {
    switch (key) {
      case 'draft': return AppTheme.warningColor;
      case 'posted': return AppTheme.successColor;
      case '': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }

  String _tabLabel(String key) {
    switch (key) {
      case 'draft': return 'Draft';
      case 'posted': return 'Posted';
      case '': return 'Reversed';
      default: return '';
    }
  }

  Widget _buildTabContent(String key) {
    final loading = _tabLoading[key] ?? false;
    final data = _tabData[key];
    final error = _tabErrors[key];

    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 8),
            Text('Failed to load', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(error, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: () => _loadTab(_tabDefs[_tabController.index]),
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
            ),
          ],
        ),
      );
    }

    if (data == null || data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No ${_tabLabel(key).toLowerCase()} entries', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTab(_tabDefs[_tabController.index]),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: data.length,
        itemBuilder: (context, i) => _buildEntryCard(data[i], key),
      ),
    );
  }

  Widget _buildEntryCard(dynamic entry, String key) {
    final statusColor = _tabColor(key);
    final dateStr = _fmtDate(entry['posting_date'] ?? entry['date']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: InkWell(
        onTap: () => _viewDetail(entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_tabIcon(key), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['document_no']?.toString() ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry['description']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${GlService.fmtAmount(((entry['total_debit'] ?? entry['debit_sum'] ?? 0) as num))}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(entry['status']?.toString() ?? 'draft'),
                ],
              ),
              _buildActionButton(entry, key),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(dynamic entry, String key) {
    final id = entry['id']?.toString() ?? '';

    switch (key) {
      case 'draft':
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
          onSelected: (v) {
            if (v == 'view') _viewDetail(entry);
            if (v == 'update') _editDraft(entry);
            if (v == 'delete') _deleteEntry(id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: ListTile(
              dense: true, leading: Icon(Icons.visibility_outlined, size: 18),
              title: Text('View', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero,
            )),
            const PopupMenuItem(value: 'update', child: ListTile(
              dense: true, leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Update', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero,
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
            if (v == 'reverse') _reverseEntry(id, entry['posting_date']?.toString() ?? '');
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

      case '':
        return IconButton(
          icon: Icon(Icons.visibility_outlined, size: 18, color: Colors.grey.shade400),
          onPressed: () => _viewDetail(entry),
          tooltip: 'View',
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Shared widgets ──

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'posted' => AppTheme.successColor,
      'draft' => AppTheme.warningColor,
      'reversed' => AppTheme.errorColor,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }
}
