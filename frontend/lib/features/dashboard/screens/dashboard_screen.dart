import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/router/app_router.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';

class DashboardScreen extends StatefulWidget {
  final AuthService authService;
  const DashboardScreen({super.key, required this.authService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final _stats = [
    _StatDef('Revenue MTD', '\$0.00', Icons.trending_up_rounded, AppTheme.accentGreen, '+12.5%'),
    _StatDef('Pending Invoices', '0', Icons.pending_actions_rounded, AppTheme.accentOrange, '3 overdue'),
    _StatDef('Active Projects', '0', Icons.rocket_launch_rounded, AppTheme.accentBlue, '--'),
  ];

  final _modules = [
    _ModuleDef('Finance', 'Real-time P&L, Balance Sheet', Icons.account_balance_rounded, AppTheme.accentGradientStart, AppRouter.financeRoute),
    _ModuleDef('Chart of Accounts', 'Manage COA structure', Icons.account_tree_rounded, AppTheme.accentBlue, '/finance/chart-of-accounts'),
    _ModuleDef('Journal Entries', 'Post and manage entries', Icons.receipt_long_rounded, AppTheme.accentTeal, '/finance/journal-entries'),
    _ModuleDef('Reports', 'Balance Sheet & P&L', Icons.bar_chart_rounded, AppTheme.accentOrange, '/finance'),
    _ModuleDef('Inventory', 'Stock & warehouse', Icons.inventory_2_rounded, AppTheme.accentPink, null),
    _ModuleDef('Settings', 'Org & configuration', Icons.settings_rounded, AppTheme.textMuted, AppRouter.settingsRoute),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.user;
    return AppLayout(
      authService: widget.authService,
      currentIndex: _currentIndex,
      onIndexChanged: (i) => setState(() => _currentIndex = i),
      title: 'Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back, ${user?['display_name'] ?? 'User'}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(user?['tenant_name'] ?? 'SwiftAI ERP',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('May 2026', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Stats row
            Row(
              children: _stats.map((s) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: _stats.first == s ? 0 : 8),
                  child: _buildStatCard(s),
                ),
              )).toList(),
            ),
            const SizedBox(height: 28),

            // Quick actions
            const Text('Quick Actions', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
            )),
            const SizedBox(height: 14),
            Row(
              children: [
                _actionChip(Icons.add_rounded, 'New Entry', AppTheme.accentBlue, () => Navigator.pushNamed(context, '/finance/journal-entry')),
                const SizedBox(width: 10),
                _actionChip(Icons.list_alt_rounded, 'View Ledger', AppTheme.accentGreen, () => Navigator.pushNamed(context, '/finance/ledger')),
                const SizedBox(width: 10),
                _actionChip(Icons.balance_rounded, 'Balance Sheet', AppTheme.accentTeal, () => Navigator.pushNamed(context, '/finance')),
              ],
            ),
            const SizedBox(height: 28),

            // Modules grid
            Row(
              children: [
                const Text('Modules', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                )),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRouter.financeRoute),
                  child: const Text('View All', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _modules.length,
              itemBuilder: (_, i) => _buildModuleCard(_modules[i]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(_StatDef s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, color: s.color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: s.change.startsWith('+') ? AppTheme.accentGreen.withValues(alpha: 0.1) : AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(s.change, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: s.change.startsWith('+') ? AppTheme.accentGreen : AppTheme.accentOrange,
                )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(s.value, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
          )),
          const SizedBox(height: 2),
          Text(s.title, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildModuleCard(_ModuleDef m) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: m.route != null ? () => Navigator.pushNamed(context, m.route!) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.icon, color: m.color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(m.title, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary,
              )),
              const SizedBox(height: 2),
              Text(m.subtitle, style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondary,
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDef {
  final String title, value, change;
  final IconData icon;
  final Color color;
  _StatDef(this.title, this.value, this.icon, this.color, this.change);
}

class _ModuleDef {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final String? route;
  _ModuleDef(this.title, this.subtitle, this.icon, this.color, this.route);
}
