import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/l10n/localization_service.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/router/app_router.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class SettingsScreen extends StatelessWidget {
  final AuthService authService;
  final GlService glService;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.glService,
  });

  @override
  Widget build(BuildContext context) {
    final user = authService.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      (user?['display_name'] ?? 'U')
                          .toString()[0]
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['display_name'] ?? 'User',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?['email'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'General',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: Text(
                    LocalizationService.instance?.currentLocale.displayName ??
                        'English',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final current = LocalizationService.instance?.currentLocale;
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Select Language'),
                        children: AppLocale.values.map((locale) {
                          return RadioListTile<AppLocale>(
                            title: Text(locale.displayName),
                            value: locale,
                            groupValue: current,
                            onChanged: (v) {
                              LocalizationService.instance?.setLocale(v!);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('Default Currency'),
                  subtitle: const Text('USD'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Fiscal Year'),
                  subtitle: const Text('Jan - Dec'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Administration',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Authorization Objects'),
                  subtitle: const Text('Define permission objects and fields'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/admin/auth-objects'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Role Management'),
                  subtitle: const Text('Create and manage roles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/admin/roles'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: const Text('Organizations'),
                  subtitle: const Text(
                    'Manage legal entities and company codes',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/admin/organizations'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_rounded, color: AppTheme.accentBlue),
                  title: const Text('Finance Settings'),
                  subtitle: const Text('Periods, COA, Payment Terms, Incoterms'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/settings/finance'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.dangerous_outlined,
                    color: AppTheme.errorColor,
                  ),
                  title: Text(
                    'Database Reset',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  subtitle: const Text('Delete all transactional data'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmReset(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SwitchListTile(
                  title: Text('Push Notifications'),
                  subtitle: Text('Receive alerts for payments and updates'),
                  value: true,
                  onChanged: null,
                ),
                const Divider(height: 1),
                const SwitchListTile(
                  title: Text('Email Reports'),
                  subtitle: Text('Receive daily financial summaries'),
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About SwiftAI ERP'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () {
              authService.logout();
              Navigator.pushReplacementNamed(context, AppRouter.login);
            },
            icon: const Icon(Icons.logout, color: AppTheme.errorColor),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.errorColor),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.errorColor),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.errorColor,
              size: 24,
            ),
            SizedBox(width: 10),
            Text('Database Reset', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete ALL transactional data:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('\u2022 Journal entries & lines'),
            Text('\u2022 Account balances'),
            Text('\u2022 Attachments'),
            Text('\u2022 Audit logs'),
            Text('\u2022 Sessions'),
            Text('\u2022 User role assignments'),
            SizedBox(height: 12),
            Text(
              'Chart of accounts, organizations, fiscal periods, user accounts, and tenants will NOT be affected.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _executeReset(context);
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Reset Database'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _executeReset(BuildContext buildContext) {
    showDialog(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Database Reset'),
        content: const Text('Type RESET to confirm:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              showDialog(
                context: buildContext,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await glService.resetDatabase();
                if (buildContext.mounted) {
                  Navigator.pop(buildContext);
                  ScaffoldMessenger.of(buildContext).showSnackBar(
                    const SnackBar(
                      content: Text('Database reset complete.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (buildContext.mounted) {
                  Navigator.pop(buildContext);
                  ScaffoldMessenger.of(buildContext).showSnackBar(
                    SnackBar(
                      content: Text('Reset failed: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'RESET',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
