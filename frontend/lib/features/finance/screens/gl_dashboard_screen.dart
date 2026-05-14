import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/router/app_router.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/screens/chart_of_accounts_screen.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_screen.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class GLDashboardScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService orgService;

  const GLDashboardScreen({
    super.key,
    required this.authService,
    required this.glService,
    required this.orgService,
  });

  @override
  State<GLDashboardScreen> createState() => _GLDashboardScreenState();
}

class _GLDashboardScreenState extends State<GLDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _recentEntries = [];
  int _accountCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.glService.getDashboardSummary(),
        widget.glService.listJournalEntries(page: 1, pageSize: 5),
        widget.glService.getAccounts(),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _recentEntries = results[1] as List<Map<String, dynamic>>;
        _accountCount = (results[2] as List<AccountModel>).length;
      });
    } catch (e) {
      // If dashboard summary fails, try partial data
      try {
        final entries = await widget.glService.listJournalEntries(page: 1, pageSize: 5);
        final accounts = await widget.glService.getAccounts();
        setState(() {
          _recentEntries = entries;
          _accountCount = accounts.length;
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load GL dashboard data'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'General Ledger',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildRecentEntries(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final totalEntries = _summary['total_entries'] as int? ?? _recentEntries.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Accounts',
            value: '$_accountCount',
            icon: Icons.account_tree_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Total Entries',
            value: '$totalEntries',
            icon: Icons.receipt_long_outlined,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Pending',
            value: '${_summary['pending_entries'] ?? 0}',
            icon: Icons.pending_actions,
            color: AppTheme.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'New Entry',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.pushNamed(context, AppRouter.financeGL),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.account_tree_outlined,
                label: 'Chart of Accounts',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChartOfAccountsScreen(
                      authService: widget.authService,
                      glService: widget.glService,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalEntryScreen(
                      authService: widget.authService,
                      glService: widget.glService,
                      orgService: widget.orgService,
                    ),
                  ),
                );
              },
              child: const Text('New Entry'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentEntries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No journal entries yet', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          )
        else
          ..._recentEntries.map((entry) => _EntryCard(entry: entry)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${DateTime.parse(entry["posting_date"] ?? entry["date"] ?? "").year}-${DateTime.parse(entry["posting_date"] ?? entry["date"] ?? "").month.toString().padLeft(2, '0')}-${DateTime.parse(entry["posting_date"] ?? entry["date"] ?? "").day.toString().padLeft(2, '0')}';

    final statusColor = switch ((entry["status"] ?? "draft")) {
      'posted' => AppTheme.successColor,
      'draft' => AppTheme.warningColor,
      'reversed' => AppTheme.errorColor,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_outlined, color: statusColor, size: 20),
        ),
        title: Text(
          (entry["description"] ?? ""),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if ((entry["document_no"] ?? entry["entry_number"] ?? "") != null) ...[
              const SizedBox(width: 8),
              Text((entry["document_no"] ?? entry["entry_number"] ?? ""), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${(((entry["total_debit"] ?? entry["debit_sum"] ?? 0) as num).toDouble()).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (entry["status"] ?? "draft"),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
