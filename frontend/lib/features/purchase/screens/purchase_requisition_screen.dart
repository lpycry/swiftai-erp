import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class PurchaseRequisitionScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;

  const PurchaseRequisitionScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });

  @override
  State<PurchaseRequisitionScreen> createState() =>
      _PurchaseRequisitionScreenState();
}

class _PurchaseRequisitionScreenState extends State<PurchaseRequisitionScreen> {
  static const _baseUrl = 'http://localhost:8080/api/v1';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String _status = '';
  List<Map<String, dynamic>> _prs = [];
  List<Map<String, dynamic>> _products = [];

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.authService.accessToken}',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prFuture = widget.purchaseService.listPRs(
        status: _status.isEmpty ? null : _status,
        query: _searchCtrl.text.trim(),
      );
      final productFuture = http.get(
        Uri.parse('$_baseUrl/warehouse/products'),
        headers: _headers,
      );
      final prs = await prFuture;
      final productsResp = await productFuture;
      if (!mounted) return;
      setState(() {
        _prs = prs;
        _products = productsResp.statusCode < 400
            ? ((jsonDecode(productsResp.body)['data'] as List<dynamic>?) ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
            : [];
      });
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDialog([Map<String, dynamic>? record]) async {
    final isEdit = record != null;
    final typeOptions = ['INVENTORY', 'EXPENSE', 'PROJECT', 'ADMIN'];
    var prType = record?['requisition_type']?.toString() ?? 'INVENTORY';
    var currency = record?['currency']?.toString() ?? 'USD';
    final deptCtrl = TextEditingController(
      text: record?['department']?.toString() ?? '',
    );
    final ccCtrl = TextEditingController(
      text: record?['cost_center']?.toString() ?? '',
    );
    final lines = <_PRLine>[];
    if (record != null) {
      final full = await widget.purchaseService.getPR(record['id'].toString());
      for (final raw in (full['items'] as List<dynamic>? ?? [])) {
        final item = Map<String, dynamic>.from(raw as Map);
        lines.add(
          _PRLine(
            productId: item['product_id']?.toString(),
            qty: _num(item['qty_requested']),
            price: _num(item['estimated_price']),
            date: _dateText(item['required_date']),
            acct: item['acct_assignment']?.toString() ?? '',
          ),
        );
      }
    }
    if (lines.isEmpty) lines.add(_PRLine(date: _formatDate(DateTime.now())));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            isEdit ? 'Edit Purchase Requisition' : 'New Purchase Requisition',
          ),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: prType,
                          decoration: const InputDecoration(
                            labelText: 'PR Type',
                          ),
                          items: typeOptions
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setD(() => prType = v ?? 'INVENTORY'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(deptCtrl, 'Department')),
                      const SizedBox(width: 12),
                      Expanded(child: _field(ccCtrl, 'Cost Center')),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          initialValue: currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                          ),
                          items: ['USD', 'CNY', 'EUR']
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setD(() => currency = v ?? 'USD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scan / Search SKU'),
                      onPressed: () => _snack(
                        'Camera scan hook is ready; use SKU search for now.',
                      ),
                    ),
                  ),
                  ...lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    final product = _productById(line.productId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text('${(index + 1) * 10}'),
                          ),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: line.productId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'SKU / Barcode *',
                              ),
                              items: _products
                                  .map(
                                    (p) => DropdownMenuItem<String>(
                                      value: p['id']?.toString(),
                                      child: Text(
                                        '${p['sku'] ?? ''} - ${p['name'] ?? ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setD(() {
                                line.productId = v;
                                final p = _productById(v);
                                line.uom =
                                    p?['unit_of_measure']?.toString() ?? 'EA';
                                if (line.price <= 0) {
                                  line.price = _num(
                                    p?['last_cost'] ?? p?['standard_cost'],
                                  );
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(product?['name']?.toString() ?? '-'),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 82,
                            child: TextFormField(
                              initialValue: line.qty.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  line.qty = double.tryParse(v) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 52, child: Text(line.uom)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: TextFormField(
                              initialValue: line.price.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  line.price = double.tryParse(v) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 132,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate:
                                      DateTime.tryParse(line.date) ??
                                      DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                );
                                if (picked != null)
                                  setD(() => line.date = _formatDate(picked));
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Required',
                                ),
                                child: Text(line.date),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: lines.length == 1
                                ? null
                                : () => setD(() => lines.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Line'),
                      onPressed: () => setD(
                        () => lines.add(
                          _PRLine(date: _formatDate(DateTime.now())),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final missing = <String>[];
                if ((prType == 'EXPENSE' || prType == 'ADMIN') &&
                    ccCtrl.text.trim().isEmpty) {
                  missing.add('Cost Center');
                }
                if (lines.any(
                  (l) => l.productId == null || l.qty <= 0 || l.date.isEmpty,
                )) {
                  missing.add('Valid line item');
                }
                if (missing.isNotEmpty) {
                  _snack('Required: ${missing.join(', ')}', isError: true);
                  return;
                }
                final data = {
                  'department': deptCtrl.text.trim(),
                  'cost_center': ccCtrl.text.trim(),
                  'requisition_type': prType,
                  'currency': currency,
                  'items': lines
                      .map(
                        (l) => {
                          'product_id': l.productId,
                          'qty_requested': l.qty,
                          'estimated_price': l.price,
                          'currency': currency,
                          'required_date': l.date,
                          'acct_assignment': l.acct,
                        },
                      )
                      .toList(),
                };
                try {
                  if (isEdit) {
                    await widget.purchaseService.updatePR(
                      record['id'].toString(),
                      data,
                    );
                  } else {
                    await widget.purchaseService.createPR(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  _snack('$e', isError: true);
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
    deptCtrl.dispose();
    ccCtrl.dispose();
    if (saved == true) await _load();
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(labelText: label),
    );
  }

  Map<String, dynamic>? _productById(String? id) {
    if (id == null) return null;
    for (final p in _products) {
      if (p['id']?.toString() == id) return p;
    }
    return null;
  }

  Future<void> _view(Map<String, dynamic> record) async {
    final pr = await widget.purchaseService.getPR(record['id'].toString());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${pr['pr_number']}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${pr['status']}   Type: ${pr['requisition_type']}   Total: ${pr['currency']} ${_fmt(pr['total_amount'])}',
                ),
                const SizedBox(height: 12),
                ...((pr['items'] as List<dynamic>? ?? []).map((raw) {
                  final it = Map<String, dynamic>.from(raw as Map);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${it['item_no']}  ${it['sku_code']} - ${it['goods_name']}',
                    ),
                    subtitle: Text(
                      'Qty ${_fmt(it['qty_requested'])} ${it['unit_of_measure']}  Price ${_fmt(it['estimated_price'])}  Required ${_dateText(it['required_date'])}  Vendor ${it['suggested_vendor'] ?? '-'}',
                    ),
                  );
                })),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _action(Future<void> Function() fn) async {
    try {
      await fn();
      await _load();
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _reject(Map<String, dynamic> pr) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject PR'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.purchaseService.rejectPR(
          pr['id'].toString(),
          ctrl.text.trim(),
        ),
      );
    }
    ctrl.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _dateText(dynamic v) => Fmt.dateStr(v?.toString());
  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  String _fmt(dynamic v) =>
      _num(v).toStringAsFixed(_num(v).truncateToDouble() == _num(v) ? 0 : 2);
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Requisitions'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: () => _action(() async {
              await widget.purchaseService.importMRPPRs();
            }),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Import MRP PR'),
          ),
          FilledButton.icon(
            onPressed: () => _createDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New PR'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                      DropdownMenuItem(
                        value: 'PENDING_APPROVAL',
                        child: Text('Pending Approval'),
                      ),
                      DropdownMenuItem(
                        value: 'APPROVED',
                        child: Text('Approved/Released'),
                      ),
                      DropdownMenuItem(
                        value: 'PROCESSING',
                        child: Text('Processing'),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'REJECTED',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (v) {
                      _status = v ?? '';
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search PR number',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _load,
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _prs.isEmpty
                ? const Center(child: Text('No purchase requisitions'))
                : ListView.separated(
                    itemCount: _prs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final pr = _prs[i];
                      final status = pr['status']?.toString() ?? '';
                      return ListTile(
                        leading: const Icon(Icons.request_quote_outlined),
                        title: Text(
                          '${pr['pr_number']}  ${pr['requisition_type']}',
                        ),
                        subtitle: Text(
                          '${pr['currency']} ${_fmt(pr['total_amount'])}  $status  ${_dateText(pr['created_at'])}',
                        ),
                        onTap: () => _view(pr),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () => _view(pr),
                            ),
                            if (status == 'DRAFT' || status == 'REJECTED')
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _createDialog(pr),
                              ),
                            if (status == 'DRAFT' || status == 'REJECTED')
                              IconButton(
                                tooltip: 'Submit',
                                icon: const Icon(Icons.send_outlined),
                                onPressed: () => _action(
                                  () => widget.purchaseService.submitPR(
                                    pr['id'].toString(),
                                  ),
                                ),
                              ),
                            if (status == 'PENDING_APPROVAL') ...[
                              IconButton(
                                tooltip: 'Approve',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _action(
                                  () => widget.purchaseService.approvePR(
                                    pr['id'].toString(),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: () => _reject(pr),
                              ),
                            ],
                            if (status == 'APPROVED' || status == 'PROCESSING')
                              IconButton(
                                tooltip: 'Convert to PO',
                                icon: const Icon(Icons.shopping_cart_checkout),
                                onPressed: () => _action(() async {
                                  await widget.purchaseService.convertPRToPO(
                                    pr['id'].toString(),
                                  );
                                }),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PRLine {
  String? productId;
  double qty;
  double price;
  String date;
  String acct;
  String uom;

  _PRLine({
    this.productId,
    this.qty = 1,
    this.price = 0,
    required this.date,
    this.acct = '',
    this.uom = 'EA',
  });
}
