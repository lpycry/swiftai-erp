import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/l10n/localization_service.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/router/app_router.dart';

class SettingsScreen extends StatelessWidget {
  final AuthService authService;
  const SettingsScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final user = authService.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      (user?['display_name'] ?? 'U').toString()[0].toUpperCase(),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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

          // General settings
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
                  subtitle: Text(LocalizationService.instance?.currentLocale.displayName ?? 'English'),
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

          // Administration
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
                  onTap: () => Navigator.pushNamed(context, '/admin/auth-objects'),
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
                  subtitle: const Text('Manage legal entities and company codes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/admin/organizations'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Accounting Periods'),
                  subtitle: const Text('Open/close fiscal periods by company'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/admin/periods'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notification settings
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

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About SwiftAI ERP'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () {
              authService.logout();
              Navigator.pushReplacementNamed(context, AppRouter.login);
            },
            icon: const Icon(Icons.logout, color: AppTheme.errorColor),
            label: const Text('Sign Out', style: TextStyle(color: AppTheme.errorColor)),
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
}
