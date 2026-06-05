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

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT': return Colors.grey;
      case 'OPEN': case 'CONFIRMED': return Colors.blue;
      case 'SHIPPED': return Colors.orange; case 'INVOICED': return Colors.teal;
      case 'COMPLETED': return Colors.green; case 'REJECTED': case 'CANCELLED': return Colors.red;
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
            ['', 'All'], ['DRAFT', 'Draft'], ['OPEN', 'Open'], ['CONFIRMED', 'Confirmed'], ['SHIPPED', 'Shipped'],
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
                final status = item['status'] ?? 'DRAFT';
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
                      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesOrderFormScreen(authService: widget.authService, salesService: widget.salesService, order: item))).then((r) { if (r == true) _load(); }),
                        child: const Text('View', style: TextStyle(fontSize: 10))),
                      if (status == 'DRAFT')
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'delete') _confirmDelete(item);
                            else _updateStatus(item['id'].toString(), v);
                          },
                          child: const Text('Actions ▾', style: TextStyle(fontSize: 10)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'CONFIRMED', child: Text('→ CONFIRMED', style: TextStyle(fontSize: 11))),
                            const PopupMenuItem(value: 'CANCELLED', child: Text('→ CANCELLED', style: TextStyle(fontSize: 11, color: Colors.red))),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red))),
                          ],
                        ),
                      if (status == 'CONFIRMED')
                        PopupMenuButton<String>(
                          onSelected: (v) => _updateStatus(item['id'].toString(), v),
                          child: const Text('Actions ▾', style: TextStyle(fontSize: 10)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'SHIPPED', child: Text('→ SHIPPED', style: TextStyle(fontSize: 11))),
                            const PopupMenuItem(value: 'CANCELLED', child: Text('→ CANCELLED', style: TextStyle(fontSize: 11, color: Colors.red))),
                          ],
                        ),
                      if (status == 'SHIPPED')
                        TextButton(onPressed: () => _updateStatus(item['id'].toString(), 'INVOICED'), child: const Text('→ INVOICED', style: TextStyle(fontSize: 10))),
                      if (status == 'INVOICED')
                        TextButton(onPressed: () => _updateStatus(item['id'].toString(), 'COMPLETED'), child: const Text('→ COMPLETED', style: TextStyle(fontSize: 10))),
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
}


