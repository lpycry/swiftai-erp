import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';
import 'package:swiftai_erp/features/logistics/screens/product_master_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/stock_movement_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/stock_on_hand_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/movement_list_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/warehouse_setup_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/gr_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/outbound_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/cycle_count_screen.dart';
import 'package:swiftai_erp/features/logistics/screens/mrp_console_screen.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/vendor_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/po_list_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/info_record_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/purchase_requisition_screen.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class LogisticsScreen extends StatelessWidget {
  final AuthService authService;
  final WarehouseService warehouseService;
  const LogisticsScreen({
    super.key,
    required this.authService,
    required this.warehouseService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 2,
      onIndexChanged: (_) {},
      title: 'Logistics',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Warehouse Management',
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
                    'Material Master, Goods Receipt, Goods Issue, Stock Transfers',
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
                _LogisticsCard(
                  icon: Icons.inventory,
                  title: 'Material Master',
                  subtitle:
                      'SKU management, UOM, batch/serial tracking, shelf life',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductMasterScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.arrow_downward,
                  title: 'Goods Receipt',
                  subtitle: 'Full GR flow: PO ref, batch, quality check',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoodReceiptScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.arrow_upward,
                  title: 'Goods Issue',
                  subtitle: 'Sales orders, production picking, packing',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OutboundScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.swap_horiz,
                  title: 'Stock Transfer',
                  subtitle: 'Bin-to-bin, zone-to-zone, warehouse-to-warehouse',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockMovementScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.receipt_long,
                  title: 'Movement History',
                  subtitle: 'View all stock movement transactions',
                  color: Colors.cyan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovementListScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.warehouse,
                  title: 'Stock On-Hand',
                  subtitle: 'Real-time inventory with Qty/Reserved/Available',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockOnHandScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.how_to_reg,
                  title: 'Cycle Count',
                  subtitle: 'AI-scheduled counts, variance tracking',
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CycleCountScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.add_business,
                  title: 'Bin Locations',
                  subtitle: 'Create & manage bin locations across warehouses',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WarehouseSetupScreen(
                        authService: authService,
                        warehouseService: warehouseService,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schema_rounded,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Material Requirements Planning',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Run MRP, review MD04 supply/demand, planned PRs and exceptions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _LogisticsCard(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'MRP',
                  subtitle:
                      'Global MRP run console, MD04 stock/requirements list, PR proposals',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MRPConsoleScreen(
                        authService: authService,
                        productionService: ProductionService(
                          authService.accessToken ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // ── Procurement Section ──
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
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Procurement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supplier management, purchasing & invoicing',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _LogisticsCard(
                  icon: Icons.business,
                  title: 'Vendors',
                  subtitle: 'Supplier master, profile, AI recommendations',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VendorListScreen(
                        authService: authService,
                        purchaseService: PurchaseService(
                          authService.accessToken ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.request_quote_outlined,
                  title: 'Purchase Requisitions',
                  subtitle: 'Create, approve, source, and convert PRs to PO',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseRequisitionScreen(
                        authService: authService,
                        purchaseService: PurchaseService(
                          authService.accessToken ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.description,
                  title: 'Purchase Orders',
                  subtitle: 'Create, manage & track PO lifecycle',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => POListScreen(
                        authService: authService,
                        purchaseService: PurchaseService(
                          authService.accessToken ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                _LogisticsCard(
                  icon: Icons.handshake_outlined,
                  title: 'Info Records',
                  subtitle: 'Vendor-material-plant purchasing defaults for MRP',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchasingInfoRecordScreen(
                        authService: authService,
                        purchaseService: PurchaseService(
                          authService.accessToken ?? '',
                        ),
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

class _LogisticsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _LogisticsCard({
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
