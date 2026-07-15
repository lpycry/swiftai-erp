import 'package:intl/intl.dart' show DateFormat;

/// Quick-access date formatting helper.
/// Uses AppDateFormatter singleton which reads from Settings > Date Formats.
class Fmt {
  static String? _pattern;

  static void setPattern(String? p) {
    _pattern = p;
  }

  static String get _effective {
    return normalizePattern(_pattern ?? 'MM/dd/yyyy');
  }

  /// Normalize user-entered ERP/SAP-style date patterns to Dart intl tokens.
  /// Users commonly enter mm/dd/yyyy; Dart requires MM for month and treats
  /// lowercase m as minutes.
  static String normalizePattern(String pattern) {
    return pattern.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
      final token = match.group(0) ?? '';
      final lower = token.toLowerCase();
      if (RegExp(r'^m+$').hasMatch(lower)) return 'MM';
      if (RegExp(r'^d+$').hasMatch(lower)) return 'dd';
      if (RegExp(r'^y+$').hasMatch(lower)) return 'yyyy';
      return token;
    });
  }

  /// Format DateTime to active pattern
  static String d(DateTime? dt) {
    if (dt == null) return '';
    try {
      return DateFormat(_effective).format(dt);
    } catch (_) {}
    return DateFormat('MM/dd/yyyy').format(dt);
  }

  /// Format a date-like value to active pattern.
  static String s(Object? value) {
    if (value == null) return '';
    if (value is DateTime) return d(value);
    final dateStr = value.toString();
    if (dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      if (dateStr.length >= 10)
        dt = DateTime.tryParse(dateStr.substring(0, 10));
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return d(dt);
  }

  static String dateStr(Object? dateStr) => s(dateStr);

  static String dateTimeStr(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      final date = d(value);
      final time =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    }
    final raw = value.toString();
    if (raw.isEmpty) return '';
    final date = s(raw);
    final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(raw);
    if (match == null) return date;
    return '$date ${match.group(1)}';
  }

  /// Compact date display still respects Settings > Date Formats.
  static String short(DateTime? dt) => d(dt);

  static String shortS(Object? value) {
    if (value == null) return '';
    if (value is DateTime) return short(value);
    final dateStr = value.toString();
    if (dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      if (dateStr.length >= 10)
        dt = DateTime.tryParse(dateStr.substring(0, 10));
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return short(dt);
  }
}
