import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/router/app_router.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';

class AppLayout extends StatelessWidget {
  final AuthService authService;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final String title;
  final Widget body;

  const AppLayout({
    super.key,
    required this.authService,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.title,
    required this.body,
  });

  static const _navItems = [
    _NavDef(Icons.dashboard_rounded, 'Dashboard', AppRouter.dashboard),
    _NavDef(Icons.account_balance_rounded, 'Finance', AppRouter.financeRoute),
    _NavDef(Icons.inventory_2_rounded, 'Logistics', AppRouter.logisticsRoute),
    _NavDef(Icons.shopping_cart_rounded, 'Sales', AppRouter.salesRoute),

    _NavDef(Icons.people_alt_rounded, 'HR', AppRouter.hrRoute),

    _NavDef(Icons.settings_rounded, 'Settings', AppRouter.settingsRoute),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: isWide ? null : _buildMobileAppBar(context),
      drawer: !isWide ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (isWide) _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                if (isWide) _buildTopBar(context),
                Expanded(child: ClipRRect(child: body)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile App Bar ──
  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      actions: _headerActions(context),
    );
  }

  // ── Top Bar (Desktop) ──
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text(title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
          )),
          const Spacer(),
          _searchBar(),
          const SizedBox(width: 12),
          _iconBtn(Icons.notifications_outlined, 'Notifications'),
          const SizedBox(width: 8),
          _userAvatar(context),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      width: 220,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text('Search...', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: AppTheme.textSecondary),
        onPressed: () {},
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }

  Widget _userAvatar(BuildContext context) {
    final name = authService.user?['display_name'] ?? 'U';
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      onSelected: (v) {
        if (v == 'settings') {
          Navigator.pushNamed(context, AppRouter.settingsRoute);
        } else if (v == 'logout') {
          authService.logout();
          Navigator.pushReplacementNamed(context, AppRouter.login);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authService.user?['display_name'] ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(authService.user?['email'] ?? '',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            name.toString()[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }

  // ── Sidebar (Desktop) ──
  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('SwiftAI', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGradientStart.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ERP', style: TextStyle(
                    color: AppTheme.accentGradientStart, fontSize: 10, fontWeight: FontWeight.w700,
                  )),
                ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              itemCount: _navItems.length,
              itemBuilder: (_, i) => _buildNavItem(context, i),
            ),
          ),
          // User footer
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final item = _navItems[index];
    final selected = currentIndex == index;
    final isDisabled = item.route == null && index != currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isDisabled ? null : () => _navigate(context, index, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentGradientStart.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: AppTheme.accentGradientStart.withValues(alpha: 0.3), width: 0.5)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppTheme.accentGradientStart : AppTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Text(item.label, style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                )),
                const Spacer(),
                if (selected)
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int index, _NavDef item) {
    if (item.route != null) {
      if (item.route == AppRouter.dashboard) {
        Navigator.pushReplacementNamed(context, item.route!);
      } else {
        Navigator.pushNamed(context, item.route!);
      }
    }
    onIndexChanged(index);
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                (authService.user?['display_name'] ?? 'U').toString()[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authService.user?['display_name'] ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  authService.user?['email'] ?? '',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Drawer (Mobile) ──
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: 280,
      child: Container(
        color: AppTheme.sidebarBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rocket_launch, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 12),
                  const Text('SwiftAI ERP', style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                  )),
                ],
              ),
            ),
            ...List.generate(_navItems.length, (i) => _drawerItem(context, i)),
            const Divider(color: Color(0xFF1E293B)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 20),
              title: const Text('Logout', style: TextStyle(color: AppTheme.errorColor, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                authService.logout();
                Navigator.pushReplacementNamed(context, AppRouter.login);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, int index) {
    final item = _navItems[index];
    final selected = currentIndex == index;
    return ListTile(
      leading: Icon(item.icon, color: selected ? AppTheme.accentGradientStart : AppTheme.textMuted, size: 20),
      title: Text(item.label, style: TextStyle(
        color: selected ? Colors.white : AppTheme.textMuted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 14,
      )),
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        _navigate(context, index, item);
      },
    );
  }

  List<Widget> _headerActions(BuildContext context) {
    return [
      _iconBtn(Icons.notifications_outlined, 'Notifications'),
      const SizedBox(width: 4),
      _userAvatar(context),
      const SizedBox(width: 4),
    ];
  }
}

class _NavDef {
  final IconData icon;
  final String label;
  final String? route;
  const _NavDef(this.icon, this.label, this.route);
}
