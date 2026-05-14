import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/finance/screens/chart_of_accounts_screen.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_screen.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_list_screen.dart';
import 'package:swiftai_erp/features/finance/screens/account_ledger_screen.dart';
import 'package:swiftai_erp/features/finance/screens/account_balance_screen.dart';
import 'package:swiftai_erp/features/finance/screens/balance_sheet_screen.dart';
import 'package:swiftai_erp/features/finance/screens/profit_loss_screen.dart';
import 'package:swiftai_erp/features/finance/screens/gl_dashboard_screen.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class FinanceScreen extends StatelessWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService orgService;

  const FinanceScreen({
    super.key,
    required this.authService,
    required this.glService,
    required this.orgService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Finance',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'General Ledger',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage accounts, journal entries, and financial reporting',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Master Data'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.account_tree_outlined,
                    title: 'Chart of Accounts',
                    subtitle: 'Manage account hierarchy',
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChartOfAccountsScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Transactions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.add_circle_outline,
                    title: 'Journal Entry',
                    subtitle: 'Create new voucher',
                    color: AppTheme.primaryColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEntryScreen(
                          authService: authService,
                          glService: glService,
                          orgService: orgService,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Journal Entry List',
                    subtitle: 'View, reverse, or delete',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEntryListScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Reports'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.receipt_outlined,
                    title: 'Account Ledger',
                    subtitle: 'View running balances',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountLedgerScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.balance_outlined,
                    title: 'Account Balances',
                    subtitle: 'Period-end balances',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountBalanceScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.balance,
                    title: 'Balance Sheet',
                    subtitle: 'Assets, Liabilities & Equity',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BalanceSheetScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.trending_up,
                    title: 'Profit & Loss',
                    subtitle: 'Revenue & Expenses',
                    color: Colors.red,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfitLossScreen(
                          authService: authService,
                          glService: glService,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FinanceCard(
                    icon: Icons.dashboard_outlined,
                    title: 'GL Dashboard',
                    subtitle: 'Overview and KPIs',
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GLDashboardScreen(
                          authService: authService,
                          glService: glService,
                          orgService: orgService,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FinanceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
