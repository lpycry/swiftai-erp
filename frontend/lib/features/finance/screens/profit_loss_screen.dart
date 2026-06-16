import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class ProfitLossScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  const ProfitLossScreen({super.key, required this.authService, required this.glService});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  int _year = 2026;
  int _month = 0;
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
      _report = await widget.glService.getProfitLoss(year: _year, month: _month);
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

  // ── Export Functions ──────────────────────────────────────────────

  Future<void> _printReport() async {
    await _saveFile('profit_loss_print.html', _generatePrintHtml());
  }

  Future<void> _exportCSV() async {
    await _saveFile('profit_loss.csv', _generateCSV());
  }

  Future<void> _exportHTML() async {
    await _saveFile('profit_loss.html', _generateHTML());
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

  // ── CSV Generation ────────────────────────────────────────────────

  String _generateCSV() {
    final buf = StringBuffer();
    buf.writeln('Profit & Loss - $_year/${_month == 0 ? "Full Year" : _month}');
    buf.writeln();

    void writeSection(String title, List? items, double total) {
      buf.writeln('Section,$title');
      buf.writeln('Account Code,Account Name,Level,Balance');
      if (items != null) {
        for (final item in items) {
          final code = item['account_code'] ?? '';
          final name = item['account_name'] ?? '';
          final level = item['level'] ?? 0;
          final bal = (item['balance'] as num?)?.toDouble() ?? 0;
          buf.writeln('"$code","$name",$level,$bal');
        }
      }
      buf.writeln('Total $title,,,$total');
      buf.writeln();
    }

    writeSection('REVENUE', _report?['revenues'] as List?, _report?['total_revenue'] as double? ?? 0);
    writeSection('EXPENSES', _report?['expenses'] as List?, _report?['total_expense'] as double? ?? 0);

    final totalRev = _report?['total_revenue'] as double? ?? 0;
    final totalExp = _report?['total_expense'] as double? ?? 0;
    final netIncome = _report?['net_income'] as double? ?? 0;
    buf.writeln('Total Revenue,,,$totalRev');
    buf.writeln('Total Expenses,,,$totalExp');
    buf.writeln('Net Income,,,$netIncome');

    return buf.toString();
  }

  // ── HTML Generation ───────────────────────────────────────────────

  String _generateHTML() {
    final totalRev = _report?['total_revenue'] as double? ?? 0;
    final totalExp = _report?['total_expense'] as double? ?? 0;
    final netIncome = _report?['net_income'] as double? ?? 0;

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Profit & Loss - $_year/${_month == 0 ? "Full Year" : _month}</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; padding: 30px; color: #333; }
  h1 { font-size: 22px; margin-bottom: 4px; }
  h2 { font-size: 16px; color: #666; font-weight: normal; margin-top: 0; }
  table { width: 100%; border-collapse: collapse; margin-top: 12px; }
  th { background: #f0f0f0; text-align: left; padding: 6px 8px; font-size: 13px; border-bottom: 2px solid #ccc; }
  td { padding: 5px 8px; font-size: 13px; border-bottom: 1px solid #eee; }
  .section-title { background: #e8f0fe; font-weight: bold; }
  .section-title td { padding: 8px; }
  .section-title.revenue td { color: #1565c0; }
  .section-title.expenses td { color: #c62828; }
  .total td { font-weight: bold; border-top: 2px solid #333; padding-top: 8px; }
  .net-income td { font-weight: bold; font-size: 15px; border-top: 2px solid #333; padding-top: 8px; }
  .amount { text-align: right; }
  .indent-0 { padding-left: 8px; }
  .indent-1 { padding-left: 28px; }
  .indent-2 { padding-left: 48px; }
  .indent-3 { padding-left: 68px; }
  .indent-4 { padding-left: 88px; }
  .footer { margin-top: 30px; font-size: 11px; color: #aaa; text-align: center; }
  .positive { color: #2e7d32; }
  .negative { color: #c62828; }
  @media print { body { padding: 15px; } }
</style>
</head>
<body>
  <h1>Profit & Loss Statement</h1>
  <h2>${_month == 0 ? "Full Year $_year" : "$_year / $_month"}</h2>
  ${_buildHTMLSectionTable('REVENUE', _report?['revenues'] as List?, 'revenue')}
  ${_buildHTMLSectionTable('EXPENSES', _report?['expenses'] as List?, 'expenses')}
  <hr style="margin-top: 16px;">
  <table>
    <tr class="total"><td>Total Revenue</td><td class="amount positive">\$${totalRev.toStringAsFixed(2)}</td></tr>
    <tr class="total"><td>Total Expenses</td><td class="amount negative">\$${totalExp.toStringAsFixed(2)}</td></tr>
    <tr class="net-income"><td>${netIncome >= 0 ? 'Net Income' : 'Net Loss'}</td><td class="amount ${netIncome >= 0 ? 'positive' : 'negative'}">\$${netIncome.abs().toStringAsFixed(2)}</td></tr>
  </table>
  <div class="footer">Generated by SwiftAI ERP</div>
</body>
</html>''';
  }

  String _buildHTMLSectionTable(String title, List? items, String cls) {
    if (items == null || items.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('<table>');
    buf.writeln('<tr class="section-title $cls"><td colspan="2">$title</td></tr>');
    for (final item in items) {
      final level = item['level'] as int? ?? 0;
      final indentClass = 'indent-$level';
      final code = item['account_code'] ?? '';
      final name = item['account_name'] ?? '';
      final bal = (item['balance'] as num?)?.toDouble() ?? 0;
      final signClass = bal >= 0 ? 'positive' : 'negative';
      buf.writeln('<tr><td class="$indentClass">[$code] $name</td><td class="amount $signClass">\$${bal.toStringAsFixed(2)}</td></tr>');
    }
    buf.writeln('</table>');
    return buf.toString();
  }

  // ── Print HTML Generation ─────────────────────────────────────────

  String _generatePrintHtml() {
    return _generateHTML();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Profit & Loss',
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
    final years = List.generate(10, (i) => 2022 + i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Year:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _year,
            items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() { _year = v!; _loadReport(); }),
            isDense: true,
          ),
          const SizedBox(width: 16),
          const Text('Period:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _month,
            items: [
              const DropdownMenuItem(value: 0, child: Text('All Year', style: TextStyle(fontSize: 13))),
              ...List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_monthNames[i], style: const TextStyle(fontSize: 13)),
              )),
            ],
            onChanged: (v) => setState(() { _month = v!; _loadReport(); }),
            isDense: true,
          ),
          const Spacer(),
          Text(_month == 0 ? "Full Year $_year" : '$_year / ${_monthNames[_month - 1]}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  List<String> get _monthNames => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  Widget _buildReport() {
    if (_report == null) return const Center(child: Text('No data'));
    final revenues = _report!['revenues'] as List? ?? [];
    final expenses = _report!['expenses'] as List? ?? [];
    final totalRev = _report!['total_revenue'] as double? ?? 0;
    final totalExp = _report!['total_expense'] as double? ?? 0;
    final netIncome = _report!['net_income'] as double? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export buttons bar
          _buildExportBar(),
          const SizedBox(height: 12),
          // Revenue
          _buildSection('REVENUE', revenues, Colors.blue, totalRev),
          const SizedBox(height: 24),
          // Expenses
          _buildSection('EXPENSES', expenses, Colors.red, totalExp),
          const Divider(thickness: 2, height: 32),
          // Net Income
          Card(
            color: netIncome >= 0 ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Total Revenue', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Text('\$${totalRev.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Total Expenses', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Text('\$${totalExp.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(netIncome >= 0 ? 'Net Income' : 'Net Loss',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        '\$${netIncome.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: netIncome >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExportBar() {
    return Row(
      children: [
        _exportButton('Print', Icons.print, Colors.blue.shade600, _printReport),
        const SizedBox(width: 8),
        _exportButton('CSV', Icons.table_chart, Colors.green.shade600, _exportCSV),
        const SizedBox(width: 8),
        _exportButton('Word / HTML', Icons.description, Colors.orange.shade600, _exportHTML),
      ],
    );
  }

  Widget _exportButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSection(String title, List items, Color color, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No accounts', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              )
            else
              ...items.map((item) {
                final level = item['level'] as int? ?? 0;
                return Padding(
                  padding: EdgeInsets.only(left: level * 20.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // Level badge
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('L$level',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600, height: 1.2)),
                              ),
                              Expanded(
                                child: Text('[${item['account_code']}] ${item['account_name']}',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(item['balance'] as num).toDouble().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: (item['balance'] as num).toDouble() >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(child: Text('Total $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Text('\$${total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
