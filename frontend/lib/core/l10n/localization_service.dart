import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_zh.dart';
import 'app_localizations_zh_hant.dart';

/// Supported locales for SwiftAI ERP.
enum AppLocale {
  en('en', 'English'),
  zh('zh', '简体中文'),
  zhHant('zh_Hant', '繁體中文'),
  es('es', 'Español');

  final String code;
  final String displayName;
  const AppLocale(this.code, this.displayName);

  static AppLocale fromCode(String code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.en,
    );
  }
}

/// Service to manage current locale and provide translations.
class LocalizationService extends ChangeNotifier {
  static LocalizationService? _instance;
  static LocalizationService? get instance => _instance;
  static const String _localeKey = 'app_locale';

  AppLocale _currentLocale;

  LocalizationService._(this._currentLocale);

  /// Create the service, auto-detecting locale on first launch.
  static Future<LocalizationService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    final locale = saved != null
        ? AppLocale.fromCode(saved)
        : AppLocale.en; // default to English
    final svc = LocalizationService._(locale);
    _instance = svc;
    return svc;
  }

  AppLocale get currentLocale => _currentLocale;

  AppLocalizations get translations {
    switch (_currentLocale) {
      case AppLocale.zh:
        return AppLocalizationsZh();
      case AppLocale.zhHant:
        return AppLocalizationsZhHant();
      case AppLocale.es:
        return AppLocalizationsEs();
      case AppLocale.en:
        return AppLocalizationsEn();
    }
  }

  AppLocalizations get t => translations;

  Future<void> setLocale(AppLocale locale) async {
    if (locale == _currentLocale) return;
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.code);
    notifyListeners();
  }

  Future<void> cycleLocale() async {
    final values = AppLocale.values;
    final idx = (values.indexOf(_currentLocale) + 1) % values.length;
    await setLocale(values[idx]);
  }
}
