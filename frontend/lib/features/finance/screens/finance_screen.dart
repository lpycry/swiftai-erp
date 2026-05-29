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
import 'package:swiftai_erp/features/finance/screens/ap/ap_screen.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_rounded, size: 32,
                        color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 12),
                    Text('General Ledger',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Accounts, journal entries, financial reports & reconciliations',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Master Data ──
            _sectionTitle(context, 'Master Data'),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.account_tree_outlined,
                title: 'Chart of Accounts',
                subtitle: 'Account hierarchy & setup',
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChartOfAccountsScreen(
                        authService: authService, glService: glService))),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Transactions ──
            _sectionTitle(context, 'Transactions'),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.add_circle_outline,
                title: 'Journal Entry',
                subtitle: 'Create & post new voucher',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => JournalEntryScreen(
                        authService: authService, glService: glService, orgService: orgService))),
              ),
              _FinanceCard(
                icon: Icons.receipt_long_outlined,
                title: 'Journal Entry List',
                subtitle: 'View, reverse, delete entries',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => JournalEntryListScreen(
                        authService: authService, glService: glService))),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Reports ──
            _sectionTitle(context, 'Reports'),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.receipt_outlined,
                title: 'Account Ledger',
                subtitle: 'Running balances by account',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AccountLedgerScreen(
                        authService: authService, glService: glService))),
              ),
              _FinanceCard(
                icon: Icons.balance_outlined,
                title: 'Account Balances',
                subtitle: 'Period-end account balances',
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AccountBalanceScreen(
                        authService: authService, glService: glService))),
              ),
              _FinanceCard(
                icon: Icons.balance,
                title: 'Balance Sheet',
                subtitle: 'Assets, liabilities & equity',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BalanceSheetScreen(
                        authService: authService, glService: glService))),
              ),
              _FinanceCard(
                icon: Icons.trending_up,
                title: 'Profit & Loss',
                subtitle: 'Revenue & expense summary',
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProfitLossScreen(
                        authService: authService, glService: glService))),
              ),
              _FinanceCard(
                icon: Icons.dashboard_outlined,
                title: 'GL Dashboard',
                subtitle: 'Overview & KPIs',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => GLDashboardScreen(
                        authService: authService, glService: glService, orgService: orgService))),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Accounts Payable Section ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.payments_rounded, size: 28,
                      color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 12),
                  Text('Accounts Payable',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Text('Vendor down payments, refunds & invoice clearing',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.payments,
                title: 'Down Payments',
                subtitle: 'Vendor prepayments with auto GL posting',
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => APScreen(
                        authService: authService,
                        apService: ApService(authService.accessToken ?? '')))),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Accounts Receivable Section (Reserved) ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.receipt_long_rounded, size: 28,
                      color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 12),
                  Text('Accounts Receivable',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Text('Customer down payments (coming soon)',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.construction_rounded,
                title: 'Coming Soon',
                subtitle: 'AR features under development',
                color: Colors.grey,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AR features coming soon'),
                      behavior: SnackBarBehavior.floating),
                ),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
    final isWide = MediaQuery.of(context).size.width > 900;
    return SizedBox(
      width: isWide ? 230 : double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          maxLines: 2),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
