import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';
import 'package:swiftai_erp/features/sales/screens/quotation_form_screen.dart';

class QuotationListScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  const QuotationListScreen({
    super.key,
    required this.authService,
    required this.salesService,
  });
  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _statusFilter;
  String get _token => widget.authService.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_statusFilter != null) params['status'] = _statusFilter!;
      final uri = Uri.parse(
        'http://localhost:8080/api/v1/sales/quotations',
      ).replace(queryParameters: params);
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) {
        _items = ((jsonDecode(resp.body)['data'] as List?) ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.grey;
      case 'OPEN':
        return Colors.blue;
      case 'ACCEPTED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.orange;
      case 'CONVERTED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _printQuotation(Map<String, dynamic> q) async {
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/sales/quotations/${q['id']}'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode >= 400) throw Exception('Failed to load');
      final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final pdf = await _buildPdf(data);
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _exportPdf(Map<String, dynamic> q) async {
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/sales/quotations/${q['id']}'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode >= 400) throw Exception('Failed to load');
      final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final pdf = await _buildPdf(data);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${q['quotation_no']}.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<pw.Document> _buildPdf(Map<String, dynamic> q) async {
    final pdf = pw.Document();
    final items = (q['items'] as List<dynamic>?) ?? [];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => [
          pw.Header(
            level: 0,
            text: 'QUOTATION',
            textStyle: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'No: ${q['quotation_no'] ?? ''}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Date: ${Fmt.dateStr(q['valid_from']?.toString())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  if (q['valid_to'] != null)
                    pw.Text(
                      'Valid Until: ${Fmt.dateStr(q['valid_to'].toString())}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Status: ${q['status'] ?? ''}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.blue700),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Customer: ${q['customer_name'] ?? ''}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Code: ${q['customer_code'] ?? ''}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(35),
              5: const pw.FixedColumnWidth(60),
              6: const pw.FixedColumnWidth(35),
              7: const pw.FixedColumnWidth(60),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children:
                    [
                          '#',
                          'SKU',
                          'Description',
                          'Qty',
                          'UOM',
                          'Price',
                          'Disc%',
                          'Total',
                        ]
                        .map(
                          (h) => pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              ...items.asMap().entries.map(
                (e) => pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        '${e.key + 1}',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        e.value['product_sku']?.toString() ?? '',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        e.value['description']?.toString() ??
                            e.value['product_name']?.toString() ??
                            '',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        (e.value['quantity'] as num?)?.toStringAsFixed(2) ??
                            '0',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        e.value['unit_of_measure']?.toString() ?? 'EA',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        '\$${(e.value['unit_price'] as num?)?.toStringAsFixed(2) ?? '0'}',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        (e.value['discount_pct'] as num?)?.toString() ?? '0',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                        '\$${(e.value['line_total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total: \$${(q['total_amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  if (((q['discount_pct'] as num?)?.toDouble() ?? 0) > 0)
                    pw.Text(
                      'Discount: ${q['discount_pct']}%',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  pw.Text(
                    'Net: \$${(q['net_amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Tax: \$${(q['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Divider(),
                  pw.Text(
                    'Grand Total: \$${(q['grand_total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((q['notes']?.toString() ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Notes: ${q['notes']}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    'Customer Signature',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(width: 150, child: pw.Divider()),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    'Authorized Signature',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(width: 150, child: pw.Divider()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              hint: const Text('Status', style: TextStyle(fontSize: 12)),
              isDense: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'DRAFT',
                  child: Text('Draft', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'OPEN',
                  child: Text('Open', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'ACCEPTED',
                  child: Text('Accepted', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'CONVERTED',
                  child: Text('Converted', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _load();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuotationFormScreen(
                    authService: widget.authService,
                    salesService: widget.salesService,
                  ),
                ),
              );
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('No quotations'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final e = _items[i];
                  final status = e['status']?.toString() ?? 'DRAFT';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        // Fetch full quotation with items
                        try {
                          final resp = await http.get(
                            Uri.parse(
                              'http://localhost:8080/api/v1/sales/quotations/${e['id']}',
                            ),
                            headers: {'Authorization': 'Bearer $_token'},
                          );
                          if (resp.statusCode < 400) {
                            final full =
                                jsonDecode(resp.body)['data']
                                    as Map<String, dynamic>;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuotationFormScreen(
                                  authService: widget.authService,
                                  salesService: widget.salesService,
                                  quotation: full,
                                ),
                              ),
                            );
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuotationFormScreen(
                                  authService: widget.authService,
                                  salesService: widget.salesService,
                                  quotation: e,
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuotationFormScreen(
                                authService: widget.authService,
                                salesService: widget.salesService,
                                quotation: e,
                              ),
                            ),
                          );
                        }
                        _load();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        e['quotation_no']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e['customer_code'] ?? ''} - ${e['customer_name'] ?? ''}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '\$${(e['grand_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                          Icons.picture_as_pdf,
                                          size: 16,
                                          color: Colors.red.shade400,
                                        ),
                                        onPressed: () => _printQuotation(e),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Print / Preview',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.file_download,
                                          size: 16,
                                          color: Colors.blue.shade400,
                                        ),
                                        onPressed: () => _exportPdf(e),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        tooltip: 'Export PDF',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
