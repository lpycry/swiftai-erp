import 'package:intl/intl.dart' show DateFormat;

/// Quick-access date formatting helper.
/// Uses AppDateFormatter singleton which reads from Settings > Date Formats.
class Fmt {
  static String? _pattern;

  static void setPattern(String? p) { _pattern = p; }

  static String get _effective {
    final p = _pattern ?? 'MM/dd/yyyy';
    // Normalize single M/d/y to double
    return p
        .replaceAll(RegExp(r'(?<![M])M(?!M)'), 'MM')
        .replaceAll(RegExp(r'(?<![d])d(?!d)'), 'dd')
        .replaceAll(RegExp(r'(?<![y])y(?!y)'), 'yyyy');
  }

  /// Format DateTime to active pattern
  static String d(DateTime? dt) {
    if (dt == null) return '';
    try { return DateFormat(_effective).format(dt); } catch (_) {}
    return DateFormat('MM/dd/yyyy').format(dt);
  }

  /// Format a date string (YYYY-MM-DD) to active pattern
  static String s(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      if (dateStr.length >= 10) dt = DateTime.tryParse(dateStr.substring(0, 10));
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return d(dt);
  }

  /// Short date: MMM dd, yyyy (always uses this format for compact display)
  static String short(DateTime? dt) {
    if (dt == null) return '';
    try { return DateFormat('MMM dd, yyyy').format(dt); } catch (_) { return ''; }
  }

  static String shortS(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    DateTime? dt;
    try {
      if (dateStr.length >= 10) dt = DateTime.tryParse(dateStr.substring(0, 10));
      if (dt == null) dt = DateTime.tryParse(dateStr);
    } catch (_) {}
    if (dt == null) return dateStr;
    return short(dt);
  }
}
