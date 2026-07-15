import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';
import 'package:swiftai_erp/features/sales/screens/customer_list_screen.dart';
import 'package:swiftai_erp/features/sales/screens/material_price_screen.dart';
import 'package:swiftai_erp/features/sales/screens/quotation_list_screen.dart';
import 'package:swiftai_erp/features/sales/screens/so_list_screen.dart';
import 'package:swiftai_erp/features/sales/screens/delivery_note_screen.dart';
import 'package:swiftai_erp/features/sales/screens/invoice_screen.dart';

class SalesScreen extends StatelessWidget {
  final AuthService authService;
  final SalesService salesService;
  const SalesScreen({
    super.key,
    required this.authService,
    required this.salesService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 4,
      onIndexChanged: (_) {},
      title: 'Sales',
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
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.store_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sales',
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
                    'Sales prices & pricing configuration',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Master Data ──
            _sectionTitle('Master Data'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SalesCard(
                  icon: Icons.people_outline,
                  title: 'Customer Master',
                  subtitle: 'Manage customer accounts & tax exemption',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
                _SalesCard(
                  icon: Icons.attach_money,
                  title: 'Material Prices',
                  subtitle: 'Sales prices with validity periods',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaterialPriceListScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Documents ──
            // ── Documents ──
            _sectionTitle('Documents'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SalesCard(
                  icon: Icons.description_outlined,
                  title: 'Quotations',
                  subtitle: 'Customer inquiries & price quotes',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuotationListScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
                _SalesCard(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Sales Orders',
                  subtitle:
                      'Create, manage & process orders (OR/EC/CS/RM/CN/ST/SP)',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalesOrderListScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
                _SalesCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Delivery Notes',
                  subtitle: 'Create outbound deliveries, picking, and PGI',
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryNoteScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
                _SalesCard(
                  icon: Icons.receipt_outlined,
                  title: 'Invoices',
                  subtitle: 'Create customer invoices and post accounting',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalesInvoiceScreen(
                        authService: authService,
                        salesService: salesService,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
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

class _SalesCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SalesCard({
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
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
