import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/l10n/localization_service.dart';

class SwiftAIERPApp extends StatefulWidget {
  const SwiftAIERPApp({super.key});

  @override
  State<SwiftAIERPApp> createState() => _SwiftAIERPAppState();
}

class _SwiftAIERPAppState extends State<SwiftAIERPApp> {
  late final AuthService _authService;
  late final AppRouter _appRouter;
  bool _l10nReady = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _appRouter = AppRouter(_authService);
    _initL10n();
  }

  Future<void> _initL10n() async {
    final l10n = await LocalizationService.create();
    l10n.addListener(() => setState(() {}));
    if (mounted) setState(() => _l10nReady = true);
  }

  @override
  Widget build(BuildContext context) {
    // Single MaterialApp always rendered — avoids web router null-route crash.
    // Show a splash loader overlay until L10n is ready.
    return MaterialApp(
      title: 'SwiftAI ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: '/login',
      onGenerateRoute: _appRouter.generateRoute,
      builder: (context, child) {
        if (!_l10nReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
