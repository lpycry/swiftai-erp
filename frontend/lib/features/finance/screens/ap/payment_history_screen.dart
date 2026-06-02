import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  const PaymentHistoryScreen({super.key, required this.authService, required this.apService});
  @override State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<_PaymentRow> _payments = [];
  bool _loading = true;

  List<Map<String, dynamic>> _vendors = [];
  String? _vendorFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get _token => widget.authService.accessToken ?? '';

  @override void initState() { super.initState(); _loadFilters(); _load(); }

  Future<void> _loadFilters() async {
    try {
      final vr = await http.get(Uri.parse('http://localhost:8080/api/v1/purchase/vendors'),
          headers: {'Authorization': 'Bearer $_token'});
      if (vr.statusCode < 400) _vendors = ((jsonDecode(vr.body)['data'] ?? []) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_vendorFilter != null) params['vendor_id'] = _vendorFilter!;
      if (_dateFrom != null) { final d = _dateFrom!; params['date_from'] = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}'; }
      if (_dateTo != null) { final d = _dateTo!; params['date_to'] = '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}'; }
      final uri = Uri.parse('http://localhost:8080/api/v1/purchase/payment-history');
      final resp = await http.get(uri.replace(queryParameters: params), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        final data = (jsonDecode(resp.body)['data'] as List?) ?? [];
        _payments = data.map((d) => _PaymentRow.fromJson(d as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _payments.fold<double>(0, (s, p) => s + p.paymentAmount);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _vendorFilter,
                decoration: const InputDecoration(labelText: 'Vendor', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                isExpanded: true,
                items: [const DropdownMenuItem(value: null, child: Text('All Vendors', style: TextStyle(fontSize: 12))),
                  ..._vendors.map((v) => DropdownMenuItem(value: v['id']?.toString(), child: Text('${v['vendor_code']} - ${v['name']}', style: const TextStyle(fontSize: 12))))],
                onChanged: (v) { setState(() => _vendorFilter = v); _load(); },
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.blue.shade50,
          child: Row(children: [
            Text('${_payments.length} payments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade800)),
            const Spacer(),
            Text('Total: \$${ApService.fmtAmount(total)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.grey.shade100,
          child: Row(children: [
            const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            const Expanded(flex: 2, child: Text('Vendor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            Expanded(flex: 1, child: Text('Status', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _payments.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8), Text('No payment records', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(itemCount: _payments.length, itemBuilder: (_, i) => _buildRow(_payments[i])),
                ),
        ),
      ]),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onChange) {
    return SizedBox(
      width: 120,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
          if (picked != null) onChange(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            prefixIcon: Icon(Icons.date_range, size: 14, color: Colors.grey.shade600)),
          child: Text(value == null ? '' : '${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
      ),
    );
  }

  Widget _buildRow(_PaymentRow p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(p.paymentDate.length >= 10 ? p.paymentDate.substring(0, 10) : p.paymentDate,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
        Expanded(flex: 2, child: Text(p.vendorName.isNotEmpty ? p.vendorName : p.vendorCode,
            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text('\$${ApService.fmtAmount(p.paymentAmount)}', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700))),
        Expanded(flex: 1, child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50, borderRadius: BorderRadius.circular(3)),
            child: Text(p.status, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
          ),
        )),
      ]),
    );
  }
}

class _PaymentRow {
  final String id, vendorId, vendorCode, vendorName, paymentDate, currency, status, description;
  final double paymentAmount;

  _PaymentRow({required this.id, required this.vendorId, this.vendorCode = '', this.vendorName = '',
    required this.paymentDate, this.currency = 'USD', required this.status, this.description = '',
    required this.paymentAmount});

  factory _PaymentRow.fromJson(Map<String, dynamic> json) {
    return _PaymentRow(
      id: json['id']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      vendorCode: json['vendor_code']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      paymentDate: json['payment_date']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      paymentAmount: (json['payment_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
