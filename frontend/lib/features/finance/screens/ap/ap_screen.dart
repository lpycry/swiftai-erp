import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_create_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_list_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/vendor_payment_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/outstanding_invoices_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/payment_history_screen.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

import 'package:swiftai_erp/features/purchase/screens/invoice_document_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_overview_screen.dart';

class APScreen extends StatelessWidget {
  final AuthService authService;
  final ApService apService;

  const APScreen({
    super.key,
    required this.authService,
    required this.apService,
  });

  @override
  Widget build(BuildContext context) {
    final purchaseService = PurchaseService(authService.accessToken ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts Payable')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accounts Payable Header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_rounded, size: 28,
                        color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 12),
                    Text('Accounts Payable',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Down payments, supplier invoices, payments & auto-clearing',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Menu Cards ──
            _MenuCard(
              icon: Icons.add_circle_outline,
              title: 'Create Down Payment',
              subtitle: 'Vendor prepayment with auto GL posting',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DPCreateScreen(
                      authService: authService, apService: apService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.list_alt,
              title: 'Down Payment List',
              subtitle: 'View, search & manage down payments',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DPListScreen(
                      authService: authService, apService: apService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.receipt,
              title: 'Outstanding Invoices',
              subtitle: 'AP aging report with overdue status',
              color: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OutstandingInvoicesScreen(
                      authService: authService, apService: apService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.article,
              title: 'Display Invoice Document',
              subtitle: 'View invoice details, items & 3-way match info',
              color: Colors.deepOrange,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InvoiceDocumentScreen(
                      authService: authService, purchaseService: purchaseService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.pending_actions,
              title: 'Uninvoiced Goods Receipt',
              subtitle: 'Goods received, awaiting supplier invoice',
              color: Colors.brown,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InvoiceOverviewScreen(
                      authService: authService, purchaseService: purchaseService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.receipt_long,
              title: 'Payment History',
              subtitle: 'View all vendor payment records',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PaymentHistoryScreen(
                      authService: authService, apService: apService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.payments,
              title: 'Vendor Payment',
              subtitle: 'Pay vendor with auto-clearing & prepayment deduction',
              color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => VendorPaymentScreen(
                      authService: authService, apService: apService))),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
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
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
