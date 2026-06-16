import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';
import 'package:swiftai_erp/features/sales/screens/so_form_screen.dart';

class SalesOrderListScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  const SalesOrderListScreen({super.key, required this.authService, required this.salesService});
  @override State<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends State<SalesOrderListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _statusFilter = '';
  String? _token;

  @override void initState() { super.initState(); _token = widget.authService.accessToken; _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var url = 'http://localhost:8080/api/v1/sales/orders';
      if (_statusFilter.isNotEmpty) url += '?status=$_statusFilter';
      final resp = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) { if (mounted) setState(() => _items = jsonDecode(resp.body)['data'] ?? []); }
    } catch (e) { if (mounted) _msg('Error: $e', isError: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppTheme.errorColor : Colors.green));
  }

  /// Display label shown in the UI (maps backend status to user-facing names)
  String _displayStatus(String s) {
    switch (s) {
      case 'DRAFT': case 'PENDING_APPROVAL': return 'DRAFT';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT': case 'PENDING_APPROVAL': return Colors.grey;
      case 'CONFIRMED': return Colors.blue;
      case 'SHIPPED': return Colors.orange; case 'INVOICED': return Colors.teal;
      case 'COMPLETED': return Colors.green; case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _checkColor(String s) {
    switch (s) {
      case 'AVAILABLE': case 'PASSED': case 'ALLOCATED': case 'CALCULATED': return Colors.green;
      case 'PARTIAL': return Colors.orange;
      case 'UNAVAILABLE': case 'FAILED': case 'NOT_ALLOCATED': return Colors.red;
      case 'PENDING': return Colors.grey;
      case 'SKIPPED': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final resp = await http.put(Uri.parse('http://localhost:8080/api/v1/sales/orders/$id/status'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'}, body: jsonEncode({'status': status}));
      if (resp.statusCode >= 400) throw Exception('Status update failed');
      _load(); _msg('Status → $status');
    } catch (e) { _msg('$e', isError: true); }
  }



  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 3, onIndexChanged: (_) {}, title: 'Sales Orders',
      body: Column(children: [
        Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListView(scrollDirection: Axis.horizontal, children: [
            ['', 'All'], ['DRAFT', 'Draft'], ['CONFIRMED', 'Confirmed'], ['SHIPPED', 'Shipped'],
            ['INVOICED', 'Invoiced'], ['COMPLETED', 'Completed'], ['CANCELLED', 'Cancelled'],
          ].map((e) => Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(
            label: Text(e[1], style: TextStyle(fontSize: 11, color: _statusFilter == e[0] ? Colors.white : null)),
            selected: _statusFilter == e[0], selectedColor: _statusColor(e[0]),
            onSelected: (_) => setState(() { _statusFilter = _statusFilter == e[0] ? '' : e[0]; _load(); }),
            visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ))).toList()),
        ),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
          Text('${_items.length} order(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const Spacer(),
          if (_statusFilter.isNotEmpty) TextButton(onPressed: () => setState(() { _statusFilter = ''; _load(); }), child: const Text('Clear', style: TextStyle(fontSize: 11))),
          // 'From Quotation' button available in future release
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor), onPressed: () async {
            final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => SalesOrderFormScreen(authService: widget.authService, salesService: widget.salesService)));
            if (r == true) _load();
          }, tooltip: 'New Order'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ])),
        const Divider(height: 1),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8), Text('No sales orders', style: TextStyle(color: Colors.grey.shade500)),
              ]))
            : ListView.builder(padding: const EdgeInsets.all(6), itemCount: _items.length, itemBuilder: (_, i) {
                final item = _items[i];
                final rawStatus = item['status'] ?? 'DRAFT';
                final status = _displayStatus(rawStatus);
                final soType = item['so_type'] ?? 'OR';
                return Card(margin: const EdgeInsets.symmetric(vertical: 3), child: ExpansionTile(
                  dense: true, tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Icon(Icons.receipt, size: 18, color: _statusColor(status)))),
                  title: Row(children: [
                    Text(item['so_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                      child: Text(soType, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontFamily: 'monospace'))),
                    const SizedBox(width: 6),
                    Flexible(child: Text(item['customer_code'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    const Spacer(),
                    Text('\$${(item['grand_total'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                  ]),
                  subtitle: Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text(status, style: TextStyle(fontSize: 9, color: _statusColor(status), fontWeight: FontWeight.w500))),
                    if (item['order_date'] != null) ...[const SizedBox(width: 8), Text(Fmt.shortS(item['order_date']), style: TextStyle(fontSize: 9, color: Colors.grey.shade400))],
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesOrderFormScreen(authService: widget.authService, salesService: widget.salesService, order: item))).then((r) { if (r == true) _load(); }),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                    IconButton(icon: Icon(Icons.delete_outline, size: 16, color: status == 'DRAFT' ? Colors.red : Colors.grey.shade300),
                      onPressed: () => _confirmDelete(item),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                  ]),
                  children: [
                    // Check statuses
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        _checkChip('Inventory', item['inventory_check_status']),
                        _checkChip('Credit', item['credit_check_status']),
                        _checkChip('Tax', item['tax_calc_status']),
                        _checkChip('Allocation', item['allocation_status']),
                      ])),
                    // Actions
                    ButtonBar(buttonHeight: 28, children: [
                      if (status == 'DRAFT')
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.blue),
                          onPressed: () => _confirmAndUpdate(rawStatus, item['id'].toString(), 'CONFIRMED', 'Confirm order #${item['so_number']}?'),
                          label: const Text('Confirm', style: TextStyle(fontSize: 10, color: Colors.blue)),
                        ),
                      if (status == 'DRAFT' || status == 'CONFIRMED' || status == 'SHIPPED' || status == 'INVOICED')
                        TextButton.icon(
                          icon: Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade400),
                          onPressed: () => _confirmAndUpdate(rawStatus, item['id'].toString(), 'CANCELLED', 
                            'Cancel ${item['so_number']}? This cannot be undone.', isCancel: true),
                          label: Text('Cancel', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
                        ),
                      if (status == 'CONFIRMED')
                        TextButton(onPressed: () => _updateStatus(item['id'].toString(), 'SHIPPED'), child: const Text('→ Shipped', style: TextStyle(fontSize: 10))),
                      if (status == 'SHIPPED')
                        TextButton(onPressed: () => _updateStatus(item['id'].toString(), 'INVOICED'), child: const Text('→ Invoiced', style: TextStyle(fontSize: 10))),
                      if (status == 'INVOICED')
                        TextButton(onPressed: () => _updateStatus(item['id'].toString(), 'COMPLETED'), child: const Text('→ Completed', style: TextStyle(fontSize: 10))),
                    ]),
                  ],
                ));
              })),
      ]),
    );
  }

  Widget _checkChip(String label, String? status) {
    final s = status ?? 'PENDING';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: _checkColor(s).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: _checkColor(s).withValues(alpha: 0.3))),
      child: Text('$label: $s', style: TextStyle(fontSize: 8, color: _checkColor(s), fontWeight: FontWeight.w500)));
  }

  Future<void> _confirmDelete(dynamic item) async {
    final ordStatus = item['status'] ?? 'DRAFT';
    if (ordStatus != 'DRAFT') {
      _msg('Cannot delete — order is $ordStatus. Cancel instead.', isError: true);
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Order'), content: Text('Delete ${item['so_number']}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok == true) {
      try { await http.delete(Uri.parse('http://localhost:8080/api/v1/sales/orders/${item['id']}'), headers: {'Authorization': 'Bearer $_token'}); _load(); _msg('Deleted'); }
      catch (e) { _msg('$e', isError: true); }
    }
  }

  Future<void> _confirmAndUpdate(String rawStatus, String id, String newStatus, String message, {bool isCancel = false}) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isCancel ? 'Cancel Order' : 'Confirm Order'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: isCancel ? Colors.red : Colors.blue),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isCancel ? 'Yes, Cancel' : 'Yes, Confirm', style: const TextStyle(fontSize: 12)),
        ),
      ],
    ));
    if (ok == true) {
      await _updateStatus(id, newStatus);
    }
  }
}


