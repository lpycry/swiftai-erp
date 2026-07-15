import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';

class DownPaymentListScreen extends StatefulWidget {
  final AuthService authService;
  const DownPaymentListScreen({super.key, required this.authService});
  @override
  State<DownPaymentListScreen> createState() => _DownPaymentListScreenState();
}

class _DownPaymentListScreenState extends State<DownPaymentListScreen> {
  List<dynamic> _items = [];
  List<dynamic> _customers = [];
  List<dynamic> _accounts = [];
  bool _loading = true;
  String get _token => widget.authService.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/ar/down-payments'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) {
        _items = ((jsonDecode(resp.body)['data'] as List?) ?? []);
      }
      final custResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/sales/customers'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (custResp.statusCode < 400) {
        _customers = ((jsonDecode(custResp.body)['data'] as List?) ?? []);
      }
      final acctResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/gl/accounts'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (acctResp.statusCode < 400) {
        _accounts = ((jsonDecode(acctResp.body)['data'] as List?) ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DownPaymentDialog(
        customers: _customers,
        accounts: _accounts,
        token: _token,
      ),
    );
    if (result == null) return;
    try {
      final resp = await http.post(
        Uri.parse('http://localhost:8080/api/v1/ar/down-payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(result),
      );
      final body = jsonDecode(resp.body);
      if (resp.statusCode >= 400)
        throw Exception(body['message'] ?? 'Create failed');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Down payment created & GL posted'),
            backgroundColor: Colors.green,
          ),
        );
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
    }
  }

  String _fmt(num? v) {
    if (v == null) return '\$0.00';
    return '\$${v.toStringAsFixed(2)}';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.grey;
      case 'POSTED':
        return Colors.green;
      case 'CLEARED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Down Payments'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _create),
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
                    Icons.payments_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('No down payments'),
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
                  final glOk = e['gl_posting_status']?.toString() == 'POSTED';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 40,
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
                                      e['dp_number']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Colors.grey.shade500,
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
                                        borderRadius: BorderRadius.circular(6),
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
                                    if (glOk) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e['customer_code'] ?? ''} - ${e['customer_name'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _fmt(e['amount'] as num?),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      e['reference_no']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  Fmt.dateStr(e['dp_date']?.toString()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _DownPaymentDialog extends StatefulWidget {
  final List<dynamic> customers, accounts;
  final String token;
  const _DownPaymentDialog({
    required this.customers,
    required this.accounts,
    required this.token,
  });
  @override
  State<_DownPaymentDialog> createState() => _DownPaymentDialogState();
}

class _DownPaymentDialogState extends State<_DownPaymentDialog> {
  String? _customerId;
  final _amountCtrl = TextEditingController();
  String _currency = 'USD';
  String _paymentMethod = 'BANK_TRANSFER';
  final _refCtrl = TextEditingController();
  DateTime _dpDate = DateTime.now();
  final _descCtrl = TextEditingController();
  String? _debitAccountId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Down Payment'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(
                  labelText: 'Customer *',
                  isDense: true,
                ),
                isExpanded: true,
                items: widget.customers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id']?.toString(),
                        child: Text(
                          '${c['customer_code']} - ${c['name']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _customerId = v),
                style: const TextStyle(fontSize: 12),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        isDense: true,
                      ),
                      items: ['USD', 'EUR', 'GBP', 'CNY']
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Debit account (Dr) — user selected
              DropdownButtonFormField<String>(
                value: _debitAccountId,
                decoration: const InputDecoration(
                  labelText: 'Debit Account (Dr) *',
                  isDense: true,
                  helperText: 'The account to debit',
                ),
                isExpanded: true,
                items: widget.accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id']?.toString(),
                        child: Text(
                          '${a['account_code']} - ${a['account_name']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _debitAccountId = v),
                style: const TextStyle(fontSize: 12),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        isDense: true,
                      ),
                      items: ['BANK_TRANSFER', 'CHECK', 'CASH', 'CREDIT_CARD']
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference No',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dpDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (d != null) setState(() => _dpDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'DP Date',
                    isDense: true,
                  ),
                  child: Text(
                    '${_dpDate.year}-${_dpDate.month.toString().padLeft(2, '0')}-${_dpDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_customerId == null || _debitAccountId == null) return;
            final amount = double.tryParse(_amountCtrl.text);
            if (amount == null || amount <= 0) return;
            Navigator.pop(context, {
              'customer_id': _customerId,
              'amount': amount,
              'currency': _currency,
              'payment_method': _paymentMethod,
              'reference_no': _refCtrl.text.trim(),
              'dp_date':
                  '${_dpDate.year}-${_dpDate.month.toString().padLeft(2, '0')}-${_dpDate.day.toString().padLeft(2, '0')}',
              'description': _descCtrl.text.trim(),
              'debit_account_id': _debitAccountId,
            });
          },
          child: const Text('Create & Post GL'),
        ),
      ],
    );
  }
}
