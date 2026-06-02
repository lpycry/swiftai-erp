import 'package:flutter/material.dart';
import '../../features/admin/screens/auth_objects_screen.dart';
import '../../features/admin/screens/roles_screen.dart';
import '../../features/admin/services/admin_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/finance/screens/finance_screen.dart';
import '../../features/finance/screens/chart_of_accounts_screen.dart';
import '../../features/finance/screens/journal_entry_screen.dart';
import '../../features/finance/screens/journal_entry_list_screen.dart';
import '../../features/finance/screens/account_ledger_screen.dart';
import '../../features/finance/screens/account_balance_screen.dart';
import '../../features/finance/services/gl_service.dart';
import '../../features/logistics/screens/logistics_screen.dart';
import '../../features/logistics/services/warehouse_service.dart';
import '../../features/settings/screens/organizations_screen.dart';
import '../../features/settings/screens/periods_screen.dart';
import '../../features/settings/screens/finance_settings/finance_settings_screen.dart';
import '../../features/settings/services/org_service.dart';
import '../../features/settings/services/finance_settings_service.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/sales/services/sales_service.dart';
import '../../features/sales/screens/sales_screen.dart';
import '../services/auth_service.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String settingsRoute = '/settings';
  static const String adminAuthObjects = '/admin/auth-objects';
  static const String adminRoles = '/admin/roles';
  static const String adminOrgs = '/admin/organizations';
  static const String adminPeriods = '/admin/periods';
  static const String financeRoute = '/finance';
  static const String financeGL = '/finance/gl';
  static const String financeChartOfAccounts = '/finance/chart-of-accounts';
  static const String financeJournalEntry = '/finance/journal-entry';
  static const String financeJournalEntryList = '/finance/journal-entries';
  static const String financeLedger = '/finance/ledger';
  static const String financeBalances = '/finance/balances';
  static const String logisticsRoute = '/logistics';
  static const String financeSettingsRoute = '/settings/finance';
  static const String salesRoute = '/sales';

  final AuthService _authService;

  AppRouter(this._authService);

  Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => LoginScreen(authService: _authService),
          settings: settings,
        );
      case register:
        return MaterialPageRoute(
          builder: (_) => RegisterScreen(authService: _authService),
          settings: settings,
        );
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => DashboardScreen(authService: _authService),
          settings: settings,
        );
      case settingsRoute:
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(authService: _authService, glService: GlService(_authService.accessToken)),
          settings: settings,
        );
      case financeSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => FinanceSettingsScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
            orgService: OrgService(_authService.accessToken),
            financeSettingsService: FinanceSettingsService(_authService.accessToken),
          ),
          settings: settings,
        );
      case adminAuthObjects:
        return MaterialPageRoute(
          builder: (_) => AuthObjectsScreen(
            authService: _authService,
            adminService: AdminService(_authService.accessToken),
          ),
          settings: settings,
        );
      case adminRoles:
        return MaterialPageRoute(
          builder: (_) => RolesScreen(
            authService: _authService,
            adminService: AdminService(_authService.accessToken),
          ),
          settings: settings,
        );
      case adminOrgs:
        return MaterialPageRoute(
          builder: (_) => OrganizationsScreen(
            authService: _authService,
            orgService: OrgService(_authService.accessToken),
          ),
          settings: settings,
        );
      case adminPeriods:
        return MaterialPageRoute(
          builder: (_) => PeriodsScreen(
            authService: _authService,
            orgService: OrgService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeRoute:
      case financeGL:
        return MaterialPageRoute(
          builder: (_) => FinanceScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
            orgService: OrgService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeChartOfAccounts:
        return MaterialPageRoute(
          builder: (_) => ChartOfAccountsScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeJournalEntry:
        return MaterialPageRoute(
          builder: (_) => JournalEntryScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
            orgService: OrgService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeJournalEntryList:
        return MaterialPageRoute(
          builder: (_) => JournalEntryListScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeLedger:
        return MaterialPageRoute(
          builder: (_) => AccountLedgerScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
          ),
          settings: settings,
        );
      case financeBalances:
        return MaterialPageRoute(
          builder: (_) => AccountBalanceScreen(
            authService: _authService,
            glService: GlService(_authService.accessToken),
          ),
          settings: settings,
        );
      case logisticsRoute:
        return MaterialPageRoute(
          builder: (_) => LogisticsScreen(
            authService: _authService,
            warehouseService: WarehouseService(_authService.accessToken ?? ''),
          ),
          settings: settings,
        );
      case salesRoute:
        return MaterialPageRoute(
          builder: (_) => SalesScreen(
            authService: _authService,
            salesService: SalesService(_authService.accessToken ?? ''),
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => LoginScreen(authService: _authService),
          settings: settings,
        );
    }
  }
}
