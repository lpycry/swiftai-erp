import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class BalanceSheetScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  const BalanceSheetScreen({super.key, required this.authService, required this.glService});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  Map<String, dynamic>? _report;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      _report = await widget.glService.getBalanceSheet(year: _year, month: _month);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Export helpers ──

  Future<void> _printReport() async {
    await _saveFile('balance_sheet_print.html', _generateHTML());
  }

  Future<void> _exportCSV() async {
    await _saveFile('balance_sheet.csv', _generateCSV());
  }

  Future<void> _exportHTML() async {
    await _saveFile('balance_sheet.html', _generateHTML());
  }

  Future<void> _saveFile(String filename, String content) async {
    try {
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}\\$filename');
      await file.writeAsString(content, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Balance Sheet',
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildReport()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(10, (i) => DateTime.now().year - 4 + i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Year:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _year,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
            onChanged: (v) => setState(() { _year = v!; _loadReport(); }),
          ),
          const SizedBox(width: 16),
          const Text('Period:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _month,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Full Year')),
              ...List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][i]),
              )),
            ],
            onChanged: (v) => setState(() { _month = v!; _loadReport(); }),
          ),
          const Spacer(),
          Text(_month == 0 ? "FY $_year" : '$_year / ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][_month - 1]}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 18),
            tooltip: 'Print / PDF',
            onPressed: _printReport,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            tooltip: 'Export CSV (Excel)',
            onPressed: _exportCSV,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 18),
            tooltip: 'Export Word / HTML',
            onPressed: _exportHTML,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    if (_report == null) return const Center(child: Text('No data', style: TextStyle(color: AppTheme.textMuted)));
    final assets = _report!['assets'] as List? ?? [];
    final liabilities = _report!['liabilities'] as List? ?? [];
    final equity = _report!['equity'] as List? ?? [];
    final totalAssets = (_report!['total_assets'] as num?)?.toDouble() ?? 0;
    final totalLiabilities = (_report!['total_liabilities'] as num?)?.toDouble() ?? 0;
    final totalEquity = (_report!['total_equity'] as num?)?.toDouble() ?? 0;
    final totalLiabEquity = totalLiabilities + totalEquity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Center(
            child: Column(
              children: [
                const Text('Balance Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                Text(_month == 0 ? 'As of $_year' : 'As of ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][_month - 1]} $_year',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Two-column layout
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Assets
                Expanded(
                  child: _buildSide(
                    'ASSETS',
                    assets,
                    totalAssets,
                    Colors.blue,
                    'Total Assets',
                  ),
                ),
                const SizedBox(width: 16),
                // RIGHT: Liabilities + Equity
                Expanded(
                  child: Column(
                    children: [
                      _buildSide(
                        'LIABILITIES',
                        liabilities,
                        totalLiabilities,
                        Colors.orange,
                        'Total Liabilities',
                      ),
                      const SizedBox(height: 16),
                      _buildEquitySide(equity, totalEquity),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Bottom check
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (totalAssets - totalLiabEquity).abs() < 0.01
                  ? AppTheme.accentGreen.withValues(alpha: 0.08)
                  : AppTheme.accentOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (totalAssets - totalLiabEquity).abs() < 0.01
                    ? AppTheme.accentGreen.withValues(alpha: 0.3)
                    : AppTheme.accentOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _labelValue('Total Assets', totalAssets, Colors.blue.shade700),
                const Icon(Icons.compare_arrows_rounded, color: AppTheme.textMuted, size: 20),
                _labelValue('Total Liabilities + Equity', totalLiabEquity, Colors.green.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text('\$${GlService.fmtAmount(value)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildSide(String title, List items, double total, Color color, String totalLabel) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
            ),
            child: Text(title, style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13,
              color: color, letterSpacing: 1,
            )),
          ),
          // Items
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No accounts', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            )
          else
            ...items.map((item) => _buildItemRow(item)),
          // Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(totalLabel, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary,
                ))),
                Text('\$${GlService.fmtAmount(total)}', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: color,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquitySide(List equity, double totalEquity) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.purple.withValues(alpha: 0.2))),
            ),
            child: const Text('EQUITY', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13,
              color: Colors.purple, letterSpacing: 1,
            )),
          ),
          if (equity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No accounts', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            )
          else
            ...equity.map((item) => _buildItemRow(item)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Total Equity', style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary,
                ))),
                Text('\$${GlService.fmtAmount(totalEquity)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.purple.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final code = item['account_code'] as String? ?? '';
    final name = item['account_name'] as String? ?? '';
    final balance = (item['balance'] as num?)?.toDouble() ?? 0;
    final level = (item['level'] as int?) ?? 1;
    final netIncome = (item['from_pnl'] as num?)?.toDouble();

    return Container(
      padding: EdgeInsets.fromLTRB(12 + (level - 1) * 16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('L$level', style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      children: [
                        TextSpan(text: '[$code] ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        TextSpan(text: name),
                        if (netIncome != null) ...[
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: '(Net Income: \$${GlService.fmtAmount(netIncome)})',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('\$${GlService.fmtAmount(balance)}', style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: balance >= 0 ? AppTheme.textPrimary : AppTheme.errorColor,
          )),
        ],
      ),
    );
  }

  // ── Export generators ──

  String _generateCSV() {
    if (_report == null) return '';
    final buf = StringBuffer();
    buf.writeln('Balance Sheet,${_month == 0 ? "FY $_year" : "$_year/${_month.toString().padLeft(2,'0')}"}');
    buf.writeln();
    buf.writeln('ASSETS,,Balance');
    for (final item in (_report!['assets'] as List? ?? [])) {
      buf.writeln('${item['account_code']},${item['account_name']},${(item['balance'] as num?)?.toDouble() ?? 0}');
    }
    buf.writeln('Total Assets,,${_report!['total_assets']}');
    buf.writeln();
    buf.writeln('LIABILITIES,,Balance');
    for (final item in (_report!['liabilities'] as List? ?? [])) {
      buf.writeln('${item['account_code']},${item['account_name']},${(item['balance'] as num?)?.toDouble() ?? 0}');
    }
    buf.writeln('Total Liabilities,,${_report!['total_liabilities']}');
    buf.writeln();
    buf.writeln('EQUITY,,Balance');
    for (final item in (_report!['equity'] as List? ?? [])) {
      buf.writeln('${item['account_code']},${item['account_name']},${(item['balance'] as num?)?.toDouble() ?? 0}');
    }
    buf.writeln('Total Equity,,${_report!['total_equity']}');
    return buf.toString();
  }

  String _generateHTML() {
    if (_report == null) return '';
    final period = _month == 0 ? "Full Year $_year" : "${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_month - 1]} $_year";
    final totalAssets = (_report!['total_assets'] as num?)?.toDouble() ?? 0;
    final totalLiabilities = (_report!['total_liabilities'] as num?)?.toDouble() ?? 0;
    final totalEquity = (_report!['total_equity'] as num?)?.toDouble() ?? 0;
    final checked = (totalAssets - totalLiabilities - totalEquity).abs() < 0.01;

    String rows(List items, {bool debitCredit = false}) {
      return items.map((item) {
        final code = item['account_code'] ?? '';
        final name = item['account_name'] ?? '';
        final bal = (item['balance'] as num?)?.toDouble() ?? 0;
        final level = (item['level'] as int?) ?? 1;
        return '<tr><td style="padding:4px 8px 4px ${12 + (level - 1) * 16}px;border-bottom:1px solid #eee;font-size:13px">'
            '<span style="color:#94a3b8;font-size:10px;background:#f1f5f9;padding:1px 4px;border-radius:3px">L$level</span> '
            '<span style="color:#94a3b8;font-size:11px">[$code]</span> $name</td>'
            '<td style="padding:4px 12px;text-align:right;border-bottom:1px solid #eee;font-weight:600;font-size:13px">\$${bal.toStringAsFixed(2)}</td></tr>';
      }).join('\n');
    }

    final assets = rows(_report!['assets'] as List? ?? []);
    final liabilities = rows(_report!['liabilities'] as List? ?? []);
    final equity = rows(_report!['equity'] as List? ?? []);

    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Balance Sheet $_year</title>
<style>
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;padding:40px;color:#0f172a;background:#fff}
h1{font-size:22px;font-weight:800;text-align:center;margin:0}
.period{text-align:center;color:#64748b;font-size:13px;margin:4px 0 24px}
.report{display:flex;gap:24px;max-width:960px;margin:0 auto}
.side{flex:1}
.section{border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;margin-bottom:16px}
.section h3{margin:0;padding:10px 16px;font-size:12px;letter-spacing:1px;font-weight:800;border-bottom:1px solid}
table{width:100%;border-collapse:collapse}
td{padding:6px 16px;font-size:13px;border-bottom:1px solid #f1f5f9}
.total td{font-weight:800;font-size:13px;border-top:2px solid;border-bottom:none;padding:10px 16px}
.footer{max-width:960px;margin:24px auto 0;padding:16px;border-radius:12px;text-align:center}
.footer .vals{display:flex;justify-content:space-around;align-items:center}
.footer .v{text-align:center}
.footer .v .l{font-size:11px;color:#64748b}
.footer .v .n{font-size:16px;font-weight:800}
</style></head><body>
<h1>Balance Sheet</h1>
<p class="period">As of $period</p>
<div class="report">
<div class="side">
<div class="section" style="border-color:#3b82f6">
<h3 style="background:#eff6ff;color:#3b82f6;border-color:#bfdbfe">ASSETS</h3>
<table>$assets
<tr class="total"><td style="color:#3b82f6">Total Assets</td><td style="text-align:right;color:#3b82f6">\$${totalAssets.toStringAsFixed(2)}</td></tr></table></div></div>
<div class="side">
<div class="section" style="border-color:#f59e0b">
<h3 style="background:#fffbeb;color:#f59e0b;border-color:#fde68a">LIABILITIES</h3>
<table>$liabilities
<tr class="total"><td style="color:#f59e0b">Total Liabilities</td><td style="text-align:right;color:#f59e0b">\$${totalLiabilities.toStringAsFixed(2)}</td></tr></table></div>
<div class="section" style="border-color:#8b5cf6">
<h3 style="background:#f5f3ff;color:#8b5cf6;border-color:#ddd6fe">EQUITY</h3>
<table>$equity
<tr class="total"><td style="color:#8b5cf6">Total Equity</td><td style="text-align:right;color:#8b5cf6">\$${GlService.fmtAmount(totalEquity)}</td></tr></table></div></div></div>
<div class="footer" style="background:${checked ? '#f0fdf4' : '#fff7ed'};border:1px solid ${checked ? '#bbf7d0' : '#fed7aa'}">
<div class="vals"><div class="v"><p class="l">Total Assets</p><p class="n" style="color:#2563eb">\$${totalAssets.toStringAsFixed(2)}</p></div>
<span style="color:#94a3b8;font-size:20px">&#8652;</span>
<div class="v"><p class="l">Total Liabilities + Equity</p><p class="n" style="color:#16a34a">\$${(totalLiabilities + totalEquity).toStringAsFixed(2)}</p></div></div></div></body></html>''';
  }
}
