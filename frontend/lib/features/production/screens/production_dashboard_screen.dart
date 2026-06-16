import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';
import 'package:swiftai_erp/features/production/screens/bom_screen.dart';
import 'package:swiftai_erp/features/production/screens/work_center_screen.dart';
import 'package:swiftai_erp/features/production/screens/routing_template_screen.dart';
import 'package:swiftai_erp/features/production/screens/production_order_screen.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final AuthService authService;
  final ProductionService productionService;
  const ProductionDashboardScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 3,
      onIndexChanged: (_) {},
      title: 'Production',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
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
                        Icons.factory_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Production Management',
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
                    'Bill of Materials, Production Orders',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Master Data Section ──
            _sectionHeader('Master Data Management'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ProdCard(
                  icon: Icons.account_tree_rounded,
                  title: 'Bill of Materials (BOM)',
                  subtitle:
                      'Multi-version BOM with parent-child tree, scrap factor, valid-from/to',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BomScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
                _ProdCard(
                  icon: Icons.precision_manufacturing_rounded,
                  title: 'Work Centers',
                  subtitle:
                      'Define capacities, efficiency rates, cost per hour',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkCenterScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
                _ProdCard(
                  icon: Icons.route_rounded,
                  title: 'Routing Templates',
                  subtitle:
                      'Reusable process templates with sequenced operations & work centers',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoutingTemplateScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            // ── Production Execution Section ──
            _sectionHeader('Production Execution'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ProdCard(
                  icon: Icons.assignment_rounded,
                  title: 'Production Orders',
                  subtitle:
                      'Create and manage production orders with BOM, priority, and scheduling',
                  color: Colors.amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductionOrderScreen(
                        authService: authService,
                        productionService: productionService,
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

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProdCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProdCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
