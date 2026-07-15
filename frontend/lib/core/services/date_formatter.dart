import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'fmt.dart';

/// Global date formatter that reads active format from Settings > Date Formats.
/// Falls back to MM/dd/yyyy when no format is configured.
class AppDateFormatter {
  static final AppDateFormatter _instance = AppDateFormatter._();
  factory AppDateFormatter() => _instance;
  AppDateFormatter._();

  String? _token;
  String? _cachedPattern;
  DateTime? _lastFetch;

  static const String _defaultPattern = 'MM/dd/yyyy';

  /// Initialize with auth token (call once from main or after login)
  void init(String? token) {
    _token = token;
    _cachedPattern = null;
    _lastFetch = null;
    _refreshIfNeeded();
  }

  /// Fetch the active date format from the backend (cached 5 minutes)
  Future<void> _refreshIfNeeded() async {
    if (_cachedPattern != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return;
    }
    if (_token == null) return;

    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/date-formats?mode=active'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode >= 400) return;
      final data =
          (jsonDecode(resp.body)['data'] as Map<String, dynamic>?) ?? {};
      _cachedPattern = data['date_pattern'] as String?;
      _lastFetch = DateTime.now();
      // Sync with fast helper
      Fmt.setPattern(_cachedPattern);
    } catch (_) {
      // Use defaults on error
    }
  }

  /// Convert SAP-style pattern (dd.MM.yyyy) to Dart intl DateFormat pattern
  /// SAP: dd.MM.yyyy, MM/dd/yyyy, yyyy-MM-dd, dd/MM/yyyy, yyyyMMdd
  /// Dart: dd.MM.yyyy, MM/dd/yyyy, yyyy-MM-dd (mostly compatible)
  String get _effectivePattern {
    return Fmt.normalizePattern(_cachedPattern ?? _defaultPattern);
  }

  /// Format a DateTime to the active date format string
  Future<String> format(DateTime? date) async {
    if (date == null) return '';
    await _refreshIfNeeded();
    try {
      return DateFormat(_effectivePattern).format(date);
    } catch (_) {
      return DateFormat(_defaultPattern).format(date);
    }
  }

  /// Format a date string (YYYY-MM-DD) to the active format
  Future<String> formatString(String? dateStr) async {
    if (dateStr == null || dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      // Try YYYY-MM-DD first
      if (dateStr.length >= 10) {
        dt = DateTime.tryParse(dateStr.substring(0, 10));
      }
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return format(dt);
  }

  /// Sync format — returns formatted date using cached pattern.
  /// Call [refresh] first if you need the latest.
  String formatSync(DateTime? date) {
    if (date == null) return '';
    try {
      return DateFormat(_effectivePattern).format(date);
    } catch (_) {
      return DateFormat(_defaultPattern).format(date);
    }
  }

  String formatStringSync(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      if (dateStr.length >= 10)
        dt = DateTime.tryParse(dateStr.substring(0, 10));
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return formatSync(dt);
  }

  /// Refresh the cache (call after changing the active format)
  Future<void> refresh() async {
    _lastFetch = null;
    await _refreshIfNeeded();
  }

  /// Get the current pattern (for display/debug)
  String get currentPattern => _cachedPattern ?? _defaultPattern;
}
