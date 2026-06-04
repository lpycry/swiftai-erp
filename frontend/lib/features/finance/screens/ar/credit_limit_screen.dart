import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';

class CreditLimitScreen extends StatefulWidget {
  final AuthService authService;
  const CreditLimitScreen({super.key, required this.authService});
  @override State<CreditLimitScreen> createState() => _CreditLimitScreenState();
}

class _CreditLimitScreenState extends State<CreditLimitScreen> {
  List<dynamic> _items = [];
  List<dynamic> _customers = [];
  bool _loading = true;
  String get _token => widget.authService.accessToken ?? '';
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/ar/credit-limits'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) { _items = ((jsonDecode(resp.body)['data'] as List?) ?? []); }
      final custResp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/customers'), headers: {'Authorization': 'Bearer $_token'});
      if (custResp.statusCode < 400) { _customers = ((jsonDecode(custResp.body)['data'] as List?) ?? []); }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _CreditLimitDialog(existing: existing, customers: _customers, token: _token));
    if (result == null) return;
    try {
      if (existing == null) {
        await http.post(Uri.parse('http://localhost:8080/api/v1/ar/credit-limits'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode(result));
      } else {
        await http.put(Uri.parse('http://localhost:8080/api/v1/ar/credit-limits/${existing['id']}'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode(result));
      }
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete'), content: const Text('Delete this credit limit?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red))],
    ));
    if (ok != true) return;
    try { await http.delete(Uri.parse('http://localhost:8080/api/v1/ar/credit-limits/$id'), headers: {'Authorization': 'Bearer $_token'}); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'OK': return Colors.green;
      case 'WARNING': return Colors.orange;
      case 'EXCEEDED': return Colors.red;
      case 'BLOCKED': return Colors.deepOrange;
      default: return Colors.grey;
    }
  }

  String _fmt(num? v) {
    if (v == null) return '\$0.00';
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Limits'), actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _upsert(null))]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.credit_card_outlined, size: 48, color: Colors.grey.shade400), const SizedBox(height: 12), const Text('No credit limits configured'), const SizedBox(height: 4), const Text('Add a credit limit for a customer')]))
          : RefreshIndicator(onRefresh: _load, child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _items.length,
              itemBuilder: (_, i) {
                final e = _items[i];
                final status = e['credit_status']?.toString() ?? 'OK';
                final limit = (e['credit_limit'] as num?)?.toDouble() ?? 0;
                final used = (e['used_credit'] as num?)?.toDouble() ?? 0;
                final avail = (e['available_credit'] as num?)?.toDouble() ?? limit - used;
                final pct = limit > 0 ? (used / limit * 100).toStringAsFixed(0) : '0';
                return Card(margin: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(borderRadius: BorderRadius.circular(12),
                    onTap: () => _upsert(e),
                    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status)))),
                        const SizedBox(width: 8),
                        Text('${e['customer_code'] ?? ''} - ${e['customer_name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(e['risk_category']?.toString() ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _metric('Limit', _fmt(e['credit_limit'] as num?)),
                        _metric('Used', _fmt(used)),
                        _metric('Available', _fmt(avail)),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pct == '0' ? Colors.green : pct == '100' ? Colors.red : Colors.orange)),
                          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: limit > 0 ? used / limit : 0, minHeight: 4, backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(pct == '0' ? Colors.green : pct == '100' ? Colors.red : Colors.orange))),
                        ])),
                      ]),
                    ])),
                  ),
                );
              },
            )),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(padding: const EdgeInsets.only(right: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ]));
  }
}

class _CreditLimitDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> customers;
  final String token;
  const _CreditLimitDialog({this.existing, required this.customers, required this.token});
  @override State<_CreditLimitDialog> createState() => _CreditLimitDialogState();
}

class _CreditLimitDialogState extends State<_CreditLimitDialog> {
  String? _customerId;
  final _limitCtrl = TextEditingController();
  final _usedCtrl = TextEditingController();
  String _currency = 'USD';
  String _riskCategory = 'LOW';
  final _notesCtrl = TextEditingController();

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _customerId = e['customer_id']?.toString();
      _limitCtrl.text = (e['credit_limit'] as num?)?.toStringAsFixed(2) ?? '';
      _usedCtrl.text = (e['used_credit'] as num?)?.toStringAsFixed(2) ?? '';
      _currency = e['currency']?.toString() ?? 'USD';
      _riskCategory = e['risk_category']?.toString() ?? 'LOW';
      _notesCtrl.text = e['notes']?.toString() ?? '';
    }
  }
  @override void dispose() { _limitCtrl.dispose(); _usedCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Credit Limit' : 'New Credit Limit'),
      content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!isEdit)
          DropdownButtonFormField<String>(value: _customerId, decoration: const InputDecoration(labelText: 'Customer *', isDense: true), isExpanded: true,
            items: widget.customers.map((c) => DropdownMenuItem(value: c['id']?.toString(), child: Text('${c['customer_code']} - ${c['name']}', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _customerId = v), style: const TextStyle(fontSize: 12), validator: (v) => v == null ? 'Required' : null),
        if (!isEdit) const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _limitCtrl, decoration: const InputDecoration(labelText: 'Credit Limit *', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: DropdownButtonFormField<String>(value: _currency, decoration: const InputDecoration(labelText: 'Ccy', isDense: true),
            items: ['USD','EUR','GBP'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _currency = v ?? 'USD'), style: const TextStyle(fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        if (isEdit) ...[
          TextField(controller: _usedCtrl, decoration: const InputDecoration(labelText: 'Used Credit', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(value: _riskCategory, decoration: const InputDecoration(labelText: 'Risk Category', isDense: true),
          items: ['LOW','MEDIUM','HIGH','CRITICAL'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _riskCategory = v ?? 'LOW'), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', isDense: true), maxLines: 2, style: const TextStyle(fontSize: 12)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_customerId == null && !isEdit) return;
          final limit = double.tryParse(_limitCtrl.text);
          if (limit == null || limit < 0) return;
          final data = <String, dynamic>{
            'credit_limit': limit, 'currency': _currency,
            'risk_category': _riskCategory, 'notes': _notesCtrl.text.trim(),
          };
          if (!isEdit) data['customer_id'] = _customerId;
          final used = double.tryParse(_usedCtrl.text);
          if (used != null && used > 0) data['used_credit'] = used;
          Navigator.pop(context, data);
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}
