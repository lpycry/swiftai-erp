import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class QuotationFormScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  final Map<String, dynamic>? quotation;
  const QuotationFormScreen({super.key, required this.authService, required this.salesService, this.quotation});
  @override State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _calculatingTax = false;
  String? _customerId, _employeeId;
  String _currency = 'USD', _paymentTerms = 'Net 30';
  final _discountCtrl = TextEditingController(), _taxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(), _internalNotesCtrl = TextEditingController();
  DateTime _validFrom = DateTime.now();
  DateTime? _validTo;
  List<dynamic> _customers = [], _products = [], _employees = [];
  List<_LineItem> _items = [];
  bool get isEdit => widget.quotation != null;
  String get _token => widget.authService.accessToken ?? '';
  String? _taxCalcSource, _taxCalcDetail;
  double? _taxCalcRate, _taxCalcAmount;
  bool get _hasTaxCalc => _taxCalcSource != null;

  @override void initState() {
    super.initState();
    final q = widget.quotation;
    if (q != null) {
      _customerId = q['customer_id']?.toString();
      _employeeId = q['employee_id']?.toString();
      _currency = q['currency']?.toString() ?? 'USD';
      _paymentTerms = q['payment_terms']?.toString() ?? 'Net 30';
      _discountCtrl.text = (q['discount_pct'] as num?)?.toString() ?? '';
      _taxCtrl.text = (q['tax_amount'] as num?)?.toString() ?? '';
      _taxCalcSource = q['tax_calc_source']?.toString();
      _taxCalcDetail = q['tax_calc_detail']?.toString();
      _taxCalcRate = (q['tax_calc_rate'] as num?)?.toDouble();
      _taxCalcAmount = (q['tax_amount'] as num?)?.toDouble();
      _notesCtrl.text = q['notes']?.toString() ?? '';
      _internalNotesCtrl.text = q['internal_notes']?.toString() ?? '';
      if (q['valid_from'] != null) { _validFrom = DateTime.tryParse(q['valid_from'].toString()) ?? DateTime.now(); }
      if (q['valid_to'] != null) { _validTo = DateTime.tryParse(q['valid_to'].toString()); }
      final items = (q['items'] as List<dynamic>?) ?? [];
      for (final it in items) {
        _items.add(_LineItem(
          productId: it['product_id']?.toString() ?? '',
          productSku: it['product_sku']?.toString() ?? '',
          productName: it['product_name']?.toString() ?? '',
          description: it['description']?.toString() ?? '',
          quantity: (it['quantity'] as num?)?.toDouble() ?? 1,
          uom: it['unit_of_measure']?.toString() ?? 'EA',
          unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0,
          discountPct: (it['discount_pct'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    _loadLookups();
    if (_items.isEmpty) _addItem();
  }

  @override void dispose() { _discountCtrl.dispose(); _taxCtrl.dispose(); _notesCtrl.dispose(); _internalNotesCtrl.dispose(); super.dispose(); }

  Future<void> _loadLookups() async {
    try {
      final custResp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/customers'), headers: {'Authorization': 'Bearer $_token'});
      if (custResp.statusCode < 400) { _customers = ((jsonDecode(custResp.body)['data'] as List?) ?? []); }
      final prodResp = await http.get(Uri.parse('http://localhost:8080/api/v1/warehouse/products'), headers: {'Authorization': 'Bearer $_token'});
      if (prodResp.statusCode < 400) { _products = ((jsonDecode(prodResp.body)['data'] as List?) ?? []); }
      final empResp = await http.get(Uri.parse('http://localhost:8080/api/v1/employees?mode=current'), headers: {'Authorization': 'Bearer $_token'});
      if (empResp.statusCode < 400) { _employees = ((jsonDecode(empResp.body)['data'] as List?) ?? []); }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _addItem() => setState(() => _items.add(_LineItem(lineNo: _items.length + 1)));
  void _removeItem(int i) { if (_items.length > 1) setState(() => _items.removeAt(i)); }

  double get _totalAmount => _items.fold(0.0, (s, it) => s + it.lineTotal);
  double get _discountAmount => _totalAmount * (double.tryParse(_discountCtrl.text) ?? 0) / 100;
  double get _netAmount => _totalAmount - _discountAmount;
  double get _grandTotal => _netAmount + (double.tryParse(_taxCtrl.text) ?? 0);

  void _recalc(_LineItem it) {
    final qty = double.tryParse(it.quantityCtrl.text) ?? 1;
    final price = double.tryParse(it.unitPriceCtrl.text) ?? 0;
    final disc = double.tryParse(it.discountCtrl.text) ?? 0;
    it.lineTotal = qty * price * (1 - disc / 100);
    setState(() {});
  }

  Future<void> _calculateTax() async {
    if (_customerId == null) return;
    setState(() => _calculatingTax = true);
    try {
      final body = jsonEncode(<String, dynamic>{
        'customer_id': _customerId,
        'net_amount': _netAmount,
      });
      final resp = await http.post(
        Uri.parse('http://localhost:8080/api/v1/sales/quotations/calculate-tax'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: body,
      );
      if (resp.statusCode >= 400) {
        final b = jsonDecode(resp.body);
        throw Exception(b['message'] ?? 'Tax calc failed');
      }
      final bodyMap = jsonDecode(resp.body);
      final data = bodyMap['data'] as Map<String, dynamic>? ?? bodyMap;
      final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
      final taxRate = (data['tax_rate'] as num?)?.toDouble() ?? 0;
      final source = data['source'] as String? ?? '';
      final detail = data['detail'] as String? ?? '';
      if (mounted) {
        setState(() {
          _taxCtrl.text = taxAmount.toStringAsFixed(2);
          _taxCalcSource = source;
          _taxCalcDetail = detail;
          _taxCalcRate = taxRate;
          _taxCalcAmount = taxAmount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tax: \$${taxAmount.toStringAsFixed(2)} at ${(taxRate*100).toStringAsFixed(2)}% — $source'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tax calc error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _calculatingTax = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'customer_id': _customerId, 'currency': _currency, 'payment_terms': _paymentTerms,
        if (_employeeId != null) 'employee_id': _employeeId,
        'discount_pct': double.tryParse(_discountCtrl.text) ?? 0,
        'tax_amount': double.tryParse(_taxCtrl.text) ?? 0,
        if (_taxCalcSource != null) 'tax_calc_source': _taxCalcSource,
        if (_taxCalcSource != null) 'tax_calc_detail': _taxCalcDetail,
        if (_taxCalcRate != null) 'tax_calc_rate': _taxCalcRate,
        'notes': _notesCtrl.text.trim(), 'internal_notes': _internalNotesCtrl.text.trim(),
        'valid_from': '${_validFrom.year}-${_validFrom.month.toString().padLeft(2,'0')}-${_validFrom.day.toString().padLeft(2,'0')}',
        'items': _items.map((it) => <String, dynamic>{
          'product_id': it.productId, 'description': it.description,
          'quantity': it.quantity, 'unit_of_measure': it.uom,
          'unit_price': it.unitPrice, 'discount_pct': it.discountPct,
        }).toList(),
      };
      if (_validTo != null) data['valid_to'] = '${_validTo!.year}-${_validTo!.month.toString().padLeft(2,'0')}-${_validTo!.day.toString().padLeft(2,'0')}';
      final resp = await http.post(Uri.parse('http://localhost:8080/api/v1/sales/quotations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode(data));
      if (resp.statusCode >= 400) { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Create failed'); }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation created'), backgroundColor: Colors.green)); Navigator.pop(context, true); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  // ── Print / Export ──

  Future<void> _printQuotation() async {
    if (!isEdit) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/quotations/${widget.quotation!['id']}'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode >= 400) throw Exception('Failed to load');
      final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final pdf = await _buildPdf(data);
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportPdf() async {
    if (!isEdit) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/quotations/${widget.quotation!['id']}'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode >= 400) throw Exception('Failed to load');
      final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final pdf = await _buildPdf(data);
      await Printing.sharePdf(bytes: await pdf.save(), filename: '${widget.quotation!['quotation_no']}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportWord() async {
    if (!isEdit) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/quotations/${widget.quotation!['id']}'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode >= 400) throw Exception('Failed to load');
      final q = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
      final items = (q['items'] as List<dynamic>?) ?? [];
      final currency = q['currency']?.toString() ?? 'USD';

      // Fetch company info
      String companyName = '', companyAddress = '';
      try {
        final orgResp = await http.get(Uri.parse('http://localhost:8080/api/v1/orgs'), headers: {'Authorization': 'Bearer $_token'});
        if (orgResp.statusCode < 400) {
          final orgList = ((jsonDecode(orgResp.body)['data'] as List?) ?? []);
          if (orgList.isNotEmpty) {
            companyName = orgList[0]['org_name']?.toString() ?? '';
            companyAddress = orgList[0]['address']?.toString() ?? '';
          }
        }
      } catch (_) {}

      final sb = StringBuffer();
      sb.writeln('<html><head><meta charset="utf-8"><style>');
      sb.writeln('body{font-family:Arial,sans-serif;font-size:11pt;margin:40px}');
      sb.writeln('h1{color:#1565C0;font-size:22pt}');
      sb.writeln('.company{color:#0D47A1;font-size:14pt;font-weight:bold}');
      sb.writeln('.address{color:#666;font-size:9pt}');
      sb.writeln('table{width:100%;border-collapse:collapse;margin-top:20px}');
      sb.writeln('th,td{border:1px solid #ccc;padding:6px;text-align:left;font-size:10pt}');
      sb.writeln('th{background:#1565C0;color:white;font-weight:bold}');
      sb.writeln('.total{font-weight:bold;font-size:12pt;color:#1565C0}');
      sb.writeln('.right{text-align:right}');
      sb.writeln('</style></head><body>');
      if (companyName.isNotEmpty) {
        sb.writeln('<div class="company">${companyName}</div>');
        if (companyAddress.isNotEmpty) sb.writeln('<div class="address">${companyAddress}</div>');
        sb.writeln('<hr style="border:1px solid #1565C0;margin:10px 0">');
      }
      sb.writeln('<h1>QUOTATION</h1>');
      sb.writeln('<p><b>No:</b> ${q['quotation_no'] ?? ''} | <b>Date:</b> ${q['valid_from']?.toString()?.substring(0,10) ?? ''} | <b>Status:</b> ${q['status'] ?? ''}</p>');
      sb.writeln('<p><b>Customer:</b> ${q['customer_name'] ?? ''} (${q['customer_code'] ?? ''})</p>');
      sb.writeln('<table><tr><th>#</th><th>SKU</th><th>Description</th><th>Qty</th><th>UOM</th><th>Price</th><th>Disc%</th><th>Total</th></tr>');
      for (var i = 0; i < items.length; i++) {
        final it = items[i] as Map<String, dynamic>;
        sb.writeln('<tr><td>${i+1}</td><td>${it['product_sku'] ?? ''}</td><td>${it['description'] ?? it['product_name'] ?? ''}</td><td class="right">${(it['quantity'] as num?)?.toStringAsFixed(2) ?? '0'}</td><td>${it['unit_of_measure'] ?? 'EA'}</td><td class="right">$currency ${(it['unit_price'] as num?)?.toStringAsFixed(2) ?? '0'}</td><td class="right">${(it['discount_pct'] as num?)?.toString() ?? '0'}%</td><td class="right">$currency ${(it['line_total'] as num?)?.toStringAsFixed(2) ?? '0'}</td></tr>');
      }
      sb.writeln('</table>');
      sb.writeln('<p class="total">Total: $currency ${(q['total_amount'] as num?)?.toStringAsFixed(2) ?? '0'}</p>');
      if (((q['discount_pct'] as num?)?.toDouble() ?? 0) > 0) sb.writeln('<p>Discount: ${q['discount_pct']}%</p>');
      sb.writeln('<p>Net: $currency ${(q['net_amount'] as num?)?.toStringAsFixed(2) ?? '0'}</p>');
      sb.writeln('<p>Tax: $currency ${(q['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0'}</p>');
      sb.writeln('<p class="total">Grand Total: $currency ${(q['grand_total'] as num?)?.toStringAsFixed(2) ?? '0'}</p>');
      if ((q['notes']?.toString() ?? '').isNotEmpty) sb.writeln('<p><b>Notes:</b> ${q['notes']}</p>');
      sb.writeln('<p style="margin-top:40px">_________________________&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;_________________________</p>');
      sb.writeln('<p>Customer Signature&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Authorized Signature</p>');
      sb.writeln('</body></html>');
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}\\${q['quotation_no']}.html');
      await file.writeAsString(sb.toString(), flush: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Word error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<pw.Document> _buildPdf(Map<String, dynamic> q) async {
    final pdf = pw.Document();
    final items = (q['items'] as List<dynamic>?) ?? [];

    // Fetch company info
    String companyName = '', companyAddress = '';
    try {
      final orgResp = await http.get(Uri.parse('http://localhost:8080/api/v1/orgs'), headers: {'Authorization': 'Bearer $_token'});
      if (orgResp.statusCode < 400) {
        final orgList = ((jsonDecode(orgResp.body)['data'] as List?) ?? []);
        if (orgList.isNotEmpty) {
          companyName = orgList[0]['org_name']?.toString() ?? '';
          companyAddress = orgList[0]['address']?.toString() ?? '';
        }
      }
    } catch (_) {}

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        // Company header
        if (companyName.isNotEmpty)
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            if (companyAddress.isNotEmpty) pw.Text(companyAddress, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 6),
          ]),
        pw.Header(level: 0, text: 'QUOTATION', textStyle: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('No: ${q['quotation_no'] ?? ''}', style: pw.TextStyle(fontSize: 12)),
            pw.Text('Date: ${q['valid_from']?.toString()?.substring(0, 10) ?? ''}', style: pw.TextStyle(fontSize: 10)),
            if (q['valid_to'] != null) pw.Text('Valid Until: ${q['valid_to'].toString().substring(0, 10)}', style: pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Status: ${q['status'] ?? ''}', style: pw.TextStyle(fontSize: 12, color: PdfColors.blue700)),
          ]),
        ]),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Customer: ${q['customer_name'] ?? ''}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Code: ${q['customer_code'] ?? ''}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5), columnWidths: {
          0: const pw.FixedColumnWidth(20),
          1: const pw.FixedColumnWidth(60),
          2: const pw.FlexColumnWidth(),
          3: const pw.FixedColumnWidth(40),
          4: const pw.FixedColumnWidth(35),
          5: const pw.FixedColumnWidth(60),
          6: const pw.FixedColumnWidth(35),
          7: const pw.FixedColumnWidth(60),
        }, children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue800), children: ['#','SKU','Description','Qty','UOM','Price','Disc%','Total'].map((h) =>
            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))).toList()),
          ...items.asMap().entries.map((e) => pw.TableRow(children: [
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text('${e.key + 1}', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text(e.value['product_sku']?.toString() ?? '', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text(e.value['description']?.toString() ?? e.value['product_name']?.toString() ?? '', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text((e.value['quantity'] as num?)?.toStringAsFixed(2) ?? '0', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text(e.value['unit_of_measure']?.toString() ?? 'EA', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text('\$${(e.value['unit_price'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text((e.value['discount_pct'] as num?)?.toString() ?? '0', style: pw.TextStyle(fontSize: 7))),
            pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text('\$${(e.value['line_total'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
          ])),
        ]),
        pw.SizedBox(height: 16),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Total: \$${(q['total_amount'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 10)),
            if (((q['discount_pct'] as num?)?.toDouble() ?? 0) > 0) pw.Text('Discount: ${q['discount_pct']}%', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Net: \$${(q['net_amount'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Tax: \$${(q['tax_amount'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.Text('Grand Total: \$${(q['grand_total'] as num?)?.toStringAsFixed(2) ?? '0'}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          ]),
        ]),
        if ((q['notes']?.toString() ?? '').isNotEmpty) ...[pw.SizedBox(height: 20), pw.Text('Notes: ${q['notes']}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))],
        pw.SizedBox(height: 40),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 9)), pw.SizedBox(height: 30), pw.Container(width: 150, child: pw.Divider())]),
          pw.Column(children: [pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9)), pw.SizedBox(height: 30), pw.Container(width: 150, child: pw.Divider())]),
        ]),
      ],
    ));
    return pdf;
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Quotation' : 'New Quotation'), actions: [
        if (isEdit) ...[
          IconButton(icon: const Icon(Icons.print, size: 20), tooltip: 'Print', onPressed: _printQuotation),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download, size: 20),
            tooltip: 'Export',
            onSelected: (v) async { if (v == 'pdf') await _exportPdf(); else if (v == 'word') await _exportWord(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red), title: Text('Export PDF', style: TextStyle(fontSize: 12)), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'word', child: ListTile(leading: Icon(Icons.description, size: 18, color: Colors.blue), title: Text('Export Word', style: TextStyle(fontSize: 12)), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
          PopupMenuButton<String>(
        onSelected: (v) async { try { await http.put(Uri.parse('http://localhost:8080/api/v1/sales/quotations/${widget.quotation!['id']}/status'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode({'status': v})); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status: $v'), backgroundColor: Colors.green)); Navigator.pop(context, true); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); } },
        itemBuilder: (_) => ['OPEN', 'ACCEPTED', 'REJECTED', 'CONVERTED'].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
      ),
        ],
      ],
      ),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (isEdit) Text('${widget.quotation!['quotation_no']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
        if (!isEdit) DropdownButtonFormField<String>(value: _customerId, decoration: const InputDecoration(labelText: 'Customer *', isDense: true), isExpanded: true,
          items: _customers.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text('${c['customer_code']} - ${c['name']}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _customerId = v), style: const TextStyle(fontSize: 12), validator: (v) => v == null ? 'Required' : null),
        if (isEdit) Text('${widget.quotation!['customer_code']} - ${widget.quotation!['customer_name']}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _employeeId,
          decoration: const InputDecoration(labelText: 'Salesperson (Employee)', isDense: true, prefixIcon: Icon(Icons.person_outline, size: 18)),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('(None)', style: TextStyle(fontSize: 12, color: Colors.grey))),
            ..._employees.map((e) => DropdownMenuItem(value: e['employee_id']?.toString(),
              child: Text('${e['employee_code'] ?? ''} — ${e['full_name'] ?? ''} ${(e['position_title'] != null && (e['position_title'] as String).isNotEmpty) ? '(${e['position_title']})' : ''}', style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: (v) => setState(() => _employeeId = v as String?),),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _validFrom, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _validFrom = d); },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Valid From', isDense: true), child: Text('${_validFrom.year}-${_validFrom.month.toString().padLeft(2,'0')}-${_validFrom.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11))))),
          const SizedBox(width: 8),
          Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _validTo ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _validTo = d); },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Valid To', isDense: true), child: Builder(builder: (ctx) { final d = _validTo; return Text(d == null ? 'Open' : '${d!.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}', style: const TextStyle(fontSize: 11)); })))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _currency, decoration: const InputDecoration(labelText: 'Currency', isDense: true), items: ['USD','EUR','GBP','CNY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _currency = v ?? 'USD'))),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<String>(value: _paymentTerms, decoration: const InputDecoration(labelText: 'Payment Terms', isDense: true), items: ['Net 30','Net 15','Net 60','COD'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setState(() => _paymentTerms = v ?? 'Net 30'))),
        ]),
        const Divider(height: 24),

        // Items header
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.grey.shade100, child: Row(children: [
          const Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Disc%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const SizedBox(width: 32),
        ])),
        ..._items.asMap().entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(children: [
            Expanded(flex: 3, child: DropdownButtonFormField<String>(value: e.value.productId.isEmpty ? null : e.value.productId, isExpanded: true,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              items: _products.map((p) => DropdownMenuItem(value: p['id']?.toString(), child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 11)))).toList(),
              onChanged: (v) async { 
              setState(() { 
                  e.value.productId = v ?? ''; 
              }); 
              if (v != null && _customerId != null) {
                  try {
                      final resp = await http.get(
                          Uri.parse('http://localhost:8080/api/v1/sales/material-prices/lookup?customer_id=$_customerId&product_id=$v'),
                          headers: {'Authorization': 'Bearer $_token'},
                      );
                      if (resp.statusCode < 400) {
                          final body = jsonDecode(resp.body);
                          final mp = body['data'] as Map<String, dynamic>?;
                          if (mp != null && mp['price'] != null) {
                              final price = (mp['price'] as num).toDouble();
                              final priceUnit = (mp['price_unit'] as num?)?.toInt() ?? 1;
                              final unitPrice = price / priceUnit;
                              setState(() {
                                  e.value.unitPriceCtrl.text = unitPrice.toStringAsFixed(2);
                              });
                              _recalc(e.value);
                              return;
                          }
                      }
                  } catch (_) {}
                  setState(() {
                      e.value.unitPriceCtrl.text = '';
                  });
                  _recalc(e.value);
              }
          },
              style: const TextStyle(fontSize: 11))),
            Expanded(flex: 1, child: TextField(controller: e.value.quantityCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), decoration: const InputDecoration(isDense: true, border: InputBorder.none), onChanged: (_) => _recalc(e.value))),
            Expanded(flex: 2, child: TextField(controller: e.value.unitPriceCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 11), decoration: const InputDecoration(isDense: true, border: InputBorder.none, prefixText: '\$'), onChanged: (_) => _recalc(e.value))),
            Expanded(flex: 1, child: TextField(controller: e.value.discountCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), decoration: const InputDecoration(isDense: true, border: InputBorder.none, suffixText: '%'), onChanged: (_) => _recalc(e.value))),
            Expanded(flex: 2, child: Text('\$${e.value.lineTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade700))),
            IconButton(icon: Icon(Icons.close, size: 14, color: Colors.red.shade400), onPressed: () => _removeItem(e.key), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
          ]),
        )),
        TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add Line', style: TextStyle(fontSize: 12)), onPressed: _addItem),
        const Divider(),

        // Totals
        _totalRow('Subtotal', _totalAmount),
        _totalRow('Discount', -_discountAmount),
        TextField(controller: _discountCtrl, decoration: const InputDecoration(labelText: 'Discount %', isDense: true, suffixText: '%'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
        _totalRow('Net Amount', _netAmount),
        // Tax: read-only amount + Calculate Tax button
        Row(children: [
          Expanded(
            child: TextField(
              controller: _taxCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Tax', isDense: true, prefixText: '\$'),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            height: 38,
            child: ElevatedButton.icon(
              icon: _calculatingTax
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate, size: 16),
              label: Text('Calculate', style: const TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              onPressed: (_calculatingTax || _customerId == null || _items.isEmpty || _items.every((it) => it.productId.isEmpty))
                  ? null
                  : _calculateTax,
            ),
          ),
        ]),
        if (_hasTaxCalc)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 2),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(Icons.receipt_long, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text('Tax Calculation',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
              ]),
              const SizedBox(height: 6),
              _taxCalcRow('Tax Rate', '${_taxCalcRate != null ? (_taxCalcRate! * 100).toStringAsFixed(3) : "-"}%'),
              _taxCalcRow('Net Amount', '\$${_netAmount.toStringAsFixed(2)}'),
              _taxCalcRow('Tax Amount', '\$${_taxCalcAmount?.toStringAsFixed(2) ?? "-"}'),
              _taxCalcRow('Method', _taxCalcSource?.replaceAll('_', ' ') ?? '-'),
              if (_taxCalcDetail != null && _taxCalcDetail!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_taxCalcDetail!,
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontStyle: FontStyle.italic)),
                ),
            ]),
          ),
        const Divider(),
        _totalRow('Grand Total', _grandTotal, bold: true),
        const SizedBox(height: 16),
        TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (shown to customer)', isDense: true), maxLines: 2, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: _internalNotesCtrl, decoration: const InputDecoration(labelText: 'Internal Notes', isDense: true), maxLines: 2, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: (_saving || (!isEdit && _customerId == null)) ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEdit ? 'Save Changes' : 'Create Quotation')),
        const SizedBox(height: 24),
      ])),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      Text(label, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      const Spacer(),
      Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: bold ? 16 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? Colors.blue.shade800 : null)),
    ]));
  }

  Widget _taxCalcRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(children: [
      Text(label + ':', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
      const SizedBox(width: 8),
      Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
    ]));
  }
}

class _LineItem {
  String productId, productSku, productName, description, uom;
  double quantity, unitPrice, discountPct, lineTotal;
  int lineNo;
  late TextEditingController quantityCtrl, unitPriceCtrl, discountCtrl;
  _LineItem({this.productId = '', this.productSku = '', this.productName = '', this.description = '', this.quantity = 1, this.uom = 'EA', this.unitPrice = 0, this.discountPct = 0, this.lineTotal = 0, this.lineNo = 1}) {
    quantityCtrl = TextEditingController(text: quantity.toString());
    unitPriceCtrl = TextEditingController(text: unitPrice.toString());
    discountCtrl = TextEditingController(text: discountPct.toString());
    lineTotal = quantity * unitPrice * (1 - discountPct / 100);
  }
}
