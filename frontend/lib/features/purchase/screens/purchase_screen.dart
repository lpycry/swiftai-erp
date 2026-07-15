import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/vendor_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/po_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/po_form_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/receipt_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_form_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/info_record_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/purchase_requisition_screen.dart';

class PurchaseScreen extends StatelessWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const PurchaseScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 4,
      onIndexChanged: (_) {},
      title: 'Procurement',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Procurement Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vendors, Purchase Orders, Receiving & Invoicing',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _PurchaseCard(
                  icon: Icons.business,
                  title: 'Vendors',
                  subtitle: 'Supplier master, profile, AI recommendations',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VendorListScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.handshake_outlined,
                  title: 'Info Records',
                  subtitle: 'Vendor-material-plant purchasing defaults for MRP',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchasingInfoRecordScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.request_quote_outlined,
                  title: 'Purchase Requisitions',
                  subtitle: 'Create, approve, source, and convert PRs to PO',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseRequisitionScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.description,
                  title: 'Purchase Orders',
                  subtitle: 'Create, manage & track PO lifecycle',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => POListScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.add_circle_outline,
                  title: 'New PO',
                  subtitle: 'Create purchase order with line items',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => POFormScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.inventory,
                  title: 'Goods Receipts',
                  subtitle: 'Purchase receipts & stock updates',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptListScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.receipt,
                  title: 'Invoices',
                  subtitle: 'Supplier invoices with 3-way matching',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceListScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
                _PurchaseCard(
                  icon: Icons.post_add,
                  title: 'New Invoice',
                  subtitle: 'Register supplier invoice with PO match',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceFormScreen(
                        authService: authService,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PurchaseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 900 ? 280 : double.infinity,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
