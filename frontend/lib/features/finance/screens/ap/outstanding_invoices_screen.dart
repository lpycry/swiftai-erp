import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/vendor_payment_screen.dart';

class OutstandingInvoicesScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  const OutstandingInvoicesScreen({super.key, required this.authService, required this.apService});
  @override State<OutstandingInvoicesScreen> createState() => _OutstandingInvoicesScreenState();
}

class _OutstandingInvoicesScreenState extends State<OutstandingInvoicesScreen> {
  List<_InvoiceRow> _invoices = [];
  bool _loading = true;

  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _products = [];
  String? _vendorFilter;
  String? _productFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get _token => widget.authService.accessToken ?? '';

  @override void initState() { super.initState(); _loadFilters(); _load(); }

  Future<void> _loadFilters() async {
    final h = {'Authorization': 'Bearer $_token'};
    try {
      final vr = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/vendors'), headers: h);
      if (vr.statusCode < 400) _vendors = ((jsonDecode(vr.body)['data'] ?? []) as List).cast<Map<String, dynamic>>();
      final pr = await http.get(Uri.parse('http://localhost:8080/api/v1/warehouse/products'), headers: h);
      if (pr.statusCode < 400) {
        final pdata = jsonDecode(pr.body);
        _products = ((pdata['data'] ?? []) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_vendorFilter != null) params['vendor_id'] = _vendorFilter!;
      if (_productFilter != null) params['item_id'] = _productFilter!;
      if (_dateFrom != null) {
        final d = _dateFrom!;
        params['date_from'] = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
      }
      if (_dateTo != null) {
        final d = _dateTo!;
        params['date_to'] = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}';
      }
      final uri = Uri.parse('http://localhost:8080/api/v1/purchase/outstanding-invoices');
      final resp = await http.get(uri.replace(queryParameters: params), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        final data = (jsonDecode(resp.body)['data'] as List?) ?? [];
        _invoices = data.map((d) => _InvoiceRow.fromJson(d as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(_InvoiceRow inv) {
    if (inv.daysOverdue > 0) return Colors.red;
    if (inv.daysOverdue > -5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final totalOpen = _invoices.fold<double>(0, (s, i) => s + i.openAmount);
    return Scaffold(
      appBar: AppBar(title: const Text('Outstanding Invoices')),
      body: Column(children: [
        // Filters
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _vendorFilter,
                decoration: const InputDecoration(labelText: 'Vendor', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                isExpanded: true,
                items: [_dd('', 'All Vendors'), ..._vendors.map((v) => _dd(v['id'].toString(), '${v['vendor_code']} - ${v['name']}'))],
                onChanged: (v) { setState(() => _vendorFilter = v == '' ? null : v); _load(); },
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _productFilter,
                decoration: const InputDecoration(labelText: 'Material', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                isExpanded: true,
                items: [_dd('', 'All Materials'), ..._products.map((p) => _dd(p['id'].toString(), '${p['sku']} - ${p['name']}'))],
                onChanged: (v) { setState(() => _productFilter = v == '' ? null : v); _load(); },
              )),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              _dateField('From', _dateFrom, (d) { setState(() => _dateFrom = d); _load(); }),
              const SizedBox(width: 8),
              _dateField('To', _dateTo, (d) { setState(() => _dateTo = d); _load(); }),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
            ]),
          ]),
        ),
        // Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.blue.shade50,
          child: Row(children: [
            Text('${_invoices.length} invoices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade800)),
            const Spacer(),
            Text('Outstanding: \$${ApService.fmtAmount(totalOpen)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade700)),
          ]),
        ),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.grey.shade100,
          child: Row(children: [
            const SizedBox(width: 14),
            const Expanded(flex: 2, child: Text('Invoice', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 2, child: Text('Vendor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 1, child: Text('Due', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 1, child: Text('Open', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            const SizedBox(width: 12),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                  const SizedBox(height: 8), Text('No outstanding invoices', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(itemCount: _invoices.length, itemBuilder: (_, i) => _buildRow(_invoices[i])),
                ),
        ),
      ]),
    );
  }

  DropdownMenuItem<String> _dd(String value, String label) => DropdownMenuItem(value: value, child: Text(label, style: const TextStyle(fontSize: 12)));

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onChange) {
    return SizedBox(
      width: 120,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
          if (picked != null) onChange(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            prefixIcon: Icon(Icons.date_range, size: 14, color: Colors.grey.shade600),
          ),
          child: Text(value == null ? '' : '${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
      ),
    );
  }

  Widget _buildRow(_InvoiceRow inv) {
    final color = _statusColor(inv);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _InvoiceDetail(invoice: inv, authService: widget.authService, apService: widget.apService))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
        child: Row(children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
          Expanded(flex: 2, child: Text(inv.vendorName.isNotEmpty ? inv.vendorName : inv.vendorCode, style: const TextStyle(fontSize: 11))),
          Expanded(flex: 1, child: Text(inv.dueDate.length >= 10 ? inv.dueDate.substring(0, 10) : inv.dueDate, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
          Expanded(flex: 1, child: Text('\$${ApService.fmtAmount(inv.openAmount)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  final _InvoiceRow invoice;
  final AuthService authService;
  final ApService apService;
  const _InvoiceDetail({required this.invoice, required this.authService, required this.apService});

  @override
  Widget build(BuildContext context) {
    final color = invoice.daysOverdue > 0 ? Colors.red : invoice.daysOverdue > -5 ? Colors.orange : Colors.green;
    return Scaffold(
      appBar: AppBar(title: Text(invoice.invoiceNumber)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.circle, size: 14, color: color), const SizedBox(width: 8),
            Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace', fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(invoice.daysOverdue > 0 ? 'OVERDUE' : invoice.daysOverdue > -5 ? 'DUE SOON' : 'CURRENT', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 11)),
            ),
          ]),
          const Divider(),
          _row('Vendor', '${invoice.vendorCode} - ${invoice.vendorName}'),
          _row('Invoice Date', invoice.invoiceDate.length >= 10 ? invoice.invoiceDate.substring(0, 10) : invoice.invoiceDate),
          _row('Due Date', invoice.dueDate.length >= 10 ? invoice.dueDate.substring(0, 10) : invoice.dueDate),
          _row('Status', invoice.daysOverdue > 0 ? '${invoice.daysOverdue}d overdue' : '${-invoice.daysOverdue}d remaining', color),
          const Divider(),
          _row('Total Amount', '\$${ApService.fmtAmount(invoice.totalAmount)}', null, true),
          _row('Paid', '\$${ApService.fmtAmount(invoice.paidAmount)}', Colors.green),
          _row('Open Balance', '\$${ApService.fmtAmount(invoice.openAmount)}', color, true),
          if (invoice.poNumber.isNotEmpty) _row('PO Reference', invoice.poNumber),
        ]))),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Create Vendor Payment'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorPaymentScreen(authService: authService, apService: apService, preselectedVendorId: invoice.vendorId))),
          ),
        ),
      ]),
    );
  }

  Widget _row(String label, String value, [Color? valueColor, bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: valueColor))),
      ]),
    );
  }
}

class _InvoiceRow {
  final String id, orgId, orgCode, orgName, invoiceNumber, invoiceDate, dueDate;
  final double totalAmount, paidAmount, openAmount;
  final String currency, vendorId, vendorCode, vendorName, poNumber, status;
  final int daysOverdue;

  _InvoiceRow({required this.id, required this.orgId, this.orgCode = '', this.orgName = '', required this.invoiceNumber, required this.invoiceDate, required this.dueDate, required this.totalAmount, required this.paidAmount, required this.openAmount, this.currency = 'USD', required this.vendorId, this.vendorCode = '', this.vendorName = '', this.poNumber = '', this.status = '', required this.daysOverdue});

  factory _InvoiceRow.fromJson(Map<String, dynamic> json) {
    return _InvoiceRow(
      id: json['id']?.toString() ?? '', orgId: json['org_id']?.toString() ?? '',
      orgCode: json['org_code']?.toString() ?? '', orgName: json['org_name']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '', invoiceDate: json['invoice_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '', totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0, openAmount: (json['open_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD', vendorId: json['vendor_id']?.toString() ?? '',
      vendorCode: json['vendor_code']?.toString() ?? '', vendorName: json['vendor_name']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '', status: json['status']?.toString() ?? '',
      daysOverdue: (json['days_overdue'] as num?)?.toInt() ?? 0,
    );
  }
}