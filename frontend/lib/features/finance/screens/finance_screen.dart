import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/finance/screens/chart_of_accounts_screen.dart';
import 'package:swiftai_erp/features/finance/screens/tax_management_screen.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_screen.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_list_screen.dart';
import 'package:swiftai_erp/features/finance/screens/account_ledger_screen.dart';
import 'package:swiftai_erp/features/finance/screens/account_balance_screen.dart';
import 'package:swiftai_erp/features/finance/screens/balance_sheet_screen.dart';
import 'package:swiftai_erp/features/finance/screens/profit_loss_screen.dart';
import 'package:swiftai_erp/features/finance/screens/gl_dashboard_screen.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/services/cost_center_service.dart';
import 'package:swiftai_erp/features/finance/screens/cost_center_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_create_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_list_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/vendor_payment_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/outstanding_invoices_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/payment_history_screen.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_document_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_overview_screen.dart';
import 'package:swiftai_erp/features/settings/services/finance_settings_service.dart';
import 'package:swiftai_erp/features/finance/screens/ar/credit_limit_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ar/down_payment_screen.dart';

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
              _FinanceCard(
                icon: Icons.percent_rounded,
                title: 'Tax Rate Management',
                subtitle: 'Tax jurisdictions & nexus setup',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TaxManagementScreen(
                        authService: authService,
                        financeSettingsService: FinanceSettingsService(authService.accessToken ?? '')
                    ))),
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
                Text('Down payments, supplier invoices, payments & auto-clearing',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.add_circle_outline,
                title: 'Create Down Payment',
                subtitle: 'Vendor prepayment with auto GL posting',
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DPCreateScreen(
                        authService: authService, apService: ApService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.list_alt,
                title: 'Down Payment List',
                subtitle: 'View, search & manage down payments',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DPListScreen(
                        authService: authService, apService: ApService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.receipt,
                title: 'Invoices',
                subtitle: 'Supplier invoices with 3-way matching',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InvoiceListScreen(
                        authService: authService,
                        purchaseService: PurchaseService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.article,
                title: 'Display Invoice Document',
                subtitle: 'View invoice details, items & 3-way match info',
                color: Colors.deepOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InvoiceDocumentScreen(
                        authService: authService,
                        purchaseService: PurchaseService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.pending_actions,
                title: 'Uninvoiced Goods Receipt',
                subtitle: 'Goods received, awaiting supplier invoice',
                color: Colors.brown,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InvoiceOverviewScreen(
                        authService: authService,
                        purchaseService: PurchaseService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.payments,
                title: 'Vendor Payment',
                subtitle: 'Pay vendor with auto-clearing & prepayment deduction',
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VendorPaymentScreen(
                        authService: authService, apService: ApService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.receipt_long,
                title: 'Payment History',
                subtitle: 'View all vendor payment records',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PaymentHistoryScreen(
                        authService: authService, apService: ApService(authService.accessToken ?? '')))),
              ),
              _FinanceCard(
                icon: Icons.warning_amber_rounded,
                title: 'Outstanding Invoices',
                subtitle: 'AP aging report with overdue indicators',
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OutstandingInvoicesScreen(
                        authService: authService, apService: ApService(authService.accessToken ?? '')))),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Accounts Receivable Section ──
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
                Text('Credit limits, customer down payments & auto GL posting',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.credit_card_outlined,
                title: 'Credit Limits',
                subtitle: 'Manage customer credit & risk categories',
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CreditLimitScreen(authService: authService))),
              ),
              _FinanceCard(
                icon: Icons.payments_outlined,
                title: 'Down Payments',
                subtitle: 'Customer prepayments with auto GL posting',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DownPaymentListScreen(authService: authService))),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Cost Management Section ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.monetization_on_rounded, size: 28,
                      color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 12),
                  Text('Cost Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Text('Cost centers, allocations & controlling',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              _FinanceCard(
                icon: Icons.account_balance_outlined,
                title: 'Cost Centers',
                subtitle: 'Cost center master data with validity periods',
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CostCenterScreen(
                        authService: authService,
                        costCenterService: CostCenterService(authService.accessToken ?? '')))),
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
