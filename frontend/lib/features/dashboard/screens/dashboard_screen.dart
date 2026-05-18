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
    _StatDef(
      'Revenue MTD',
      '\$0.00',
      Icons.trending_up_rounded,
      AppTheme.accentGreen,
      '+12.5%',
    ),
    _StatDef(
      'Pending Invoices',
      '0',
      Icons.pending_actions_rounded,
      AppTheme.accentOrange,
      '3 overdue',
    ),
    _StatDef(
      'Active Projects',
      '0',
      Icons.rocket_launch_rounded,
      AppTheme.accentBlue,
      '--',
    ),
  ];

  final _modules = [
    _ModuleDef(
      'Finance',
      'Real-time P&L, Balance Sheet',
      Icons.account_balance_rounded,
      AppTheme.accentGradientStart,
      AppRouter.financeRoute,
    ),
    _ModuleDef(
      'Chart of Accounts',
      'Manage COA structure',
      Icons.account_tree_rounded,
      AppTheme.accentBlue,
      '/finance/chart-of-accounts',
    ),
    _ModuleDef(
      'Journal Entries',
      'Post and manage entries',
      Icons.receipt_long_rounded,
      AppTheme.accentTeal,
      '/finance/journal-entries',
    ),
    _ModuleDef(
      'Reports',
      'Balance Sheet & P&L',
      Icons.bar_chart_rounded,
      AppTheme.accentOrange,
      '/finance',
    ),
    _ModuleDef(
      'Inventory',
      'Stock & warehouse',
      Icons.inventory_2_rounded,
      AppTheme.accentPink,
      null,
    ),
    _ModuleDef(
      'Settings',
      'Org & configuration',
      Icons.settings_rounded,
      AppTheme.textMuted,
      AppRouter.settingsRoute,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.user;

    return AppLayout(
      authService: widget.authService,
      currentIndex: _currentIndex,
      onIndexChanged: (i) => setState(() => _currentIndex = i),
      title: 'Dashboard',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // 核心响应式断点计算
          int statCrossAxisCount = 3; // Stats 大屏一排 3 个
          int moduleCrossAxisCount = 3; // Modules 大屏一排 3-4 个
          double moduleRatio = 1.4; // Modules 宽高比

          if (width < 600) {
            // 手机移动端
            statCrossAxisCount = 1; // KPI 卡片单列纵向排列
            moduleCrossAxisCount = 1; // 模块卡片单列横向长条，看清副标题
            moduleRatio = 3.5; // 移动端单列时的扁平宽高比
          } else if (width < 960) {
            // 平板或窄屏
            statCrossAxisCount = 2; // KPI 两列
            moduleCrossAxisCount = 2; // 模块两列
            moduleRatio = 1.6;
          } else if (width > 1400) {
            // 宽屏桌面端
            moduleCrossAxisCount = 4; // 扩展为 4 列，一屏看完所有模块
            moduleRatio = 1.5;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Welcome Header 头部栏
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${user?['display_name'] ?? 'User'}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?['tenant_name'] ?? 'SwiftAI ERP',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'May 2026',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 2. Stats Grid (原 Row 改为响应式 GridView)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: statCrossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width < 600 ? 2.8 : 1.6, // 动态调整 KPI 卡片比例
                  ),
                  itemCount: _stats.length,
                  itemBuilder: (_, i) => _buildStatCard(_stats[i]),
                ),
                const SizedBox(height: 28),

                // 3. Quick Actions 快捷操作 (原 Row 改为 Wrap 自动流式换行)
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10, // 水平间距
                  runSpacing: 10, // 垂直换行间距
                  children: [
                    _actionChip(
                      Icons.add_rounded,
                      'New Entry',
                      AppTheme.accentBlue,
                      () => Navigator.pushNamed(
                        context,
                        '/finance/journal-entry',
                      ),
                    ),
                    _actionChip(
                      Icons.list_alt_rounded,
                      'View Ledger',
                      AppTheme.accentGreen,
                      () => Navigator.pushNamed(context, '/finance/ledger'),
                    ),
                    _actionChip(
                      Icons.balance_rounded,
                      'Balance Sheet',
                      AppTheme.accentTeal,
                      () => Navigator.pushNamed(context, '/finance'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 4. Modules Grid 业务模块区域
                Row(
                  children: [
                    const Text(
                      'Modules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouter.financeRoute),
                      child: const Text(
                        'View All',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: moduleCrossAxisCount,
                    childAspectRatio: moduleRatio,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _modules.length,
                  itemBuilder: (_, i) =>
                      _buildModuleCard(_modules[i], isCompact: width < 600),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // 优化后的 Stats 卡片布局：确保高度自适应并垂直居中平铺
  Widget _buildStatCard(_StatDef s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 顶底两端对齐，撑满卡片
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
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
                  color: s.change.startsWith('+')
                      ? AppTheme.accentGreen.withValues(alpha: 0.1)
                      : AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.change,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: s.change.startsWith('+')
                        ? AppTheme.accentGreen
                        : AppTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  s.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  s.title,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 优化后的 Module 卡片：兼容手机端长条样式与大屏方块样式
  Widget _buildModuleCard(_ModuleDef m, {required bool isCompact}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: m.route != null
            ? () => Navigator.pushNamed(context, m.route!)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isCompact
              ? Row(
                  // 手机端：左右结构，Icon 在左，文字在右
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(m.icon, color: m.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ],
                )
              : Column(
                  // 桌面/平板端：上下结构
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(m.icon, color: m.color, size: 20),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2, // 允许两行描述
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _actionChip(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
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
