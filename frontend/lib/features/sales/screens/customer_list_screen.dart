import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';
import 'package:swiftai_erp/features/sales/screens/customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  const CustomerListScreen({super.key, required this.authService, required this.salesService});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<dynamic> _customers = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String? _statusFilter;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _load({String? query}) async {
    setState(() { _loading = true; _error = null; });
    try { _customers = await widget.salesService.listCustomers(query: query, status: _statusFilter); }
    catch (e) { _error = e.toString(); }
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Customer'),
      content: Text('Delete "${c['name']}" (${c['customer_code']})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try { await widget.salesService.deleteCustomer(c['id'].toString()); _load(query: _searchController.text); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red)); }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.orange;
      case 'blocked': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Master'),
        actions: [
          DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _statusFilter,
            hint: const Text('Status', style: TextStyle(fontSize: 12)),
            isDense: true, padding: const EdgeInsets.symmetric(horizontal: 8),
            items: const [
              DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'Blocked', child: Text('Blocked', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) { setState(() => _statusFilter = v); _load(query: _searchController.text); },
          )),
          IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'New Customer', onPressed: () { WidgetsBinding.instance.addPostFrameCallback((_) { Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerFormScreen(authService: widget.authService, salesService: widget.salesService))).then((_) { _load(query: _searchController.text); }); }); }),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
          controller: _searchController,
          decoration: InputDecoration(hintText: 'Search by code, name or tax number...', prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _load(); }) : null),
          onSubmitted: (v) => _load(query: v),
        )),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      const SizedBox(height: 12), ElevatedButton(onPressed: () => _load(), child: const Text('Retry')),
    ]));
    if (_customers.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
      const SizedBox(height: 12), Text('No customers found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 4), Text('Create a new customer to get started', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]));
    return RefreshIndicator(
      onRefresh: () => _load(query: _searchController.text),
      child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _customers.length,
        itemBuilder: (_, i) {
          final c = _customers[i];
          final status = c['status']?.toString() ?? 'Active';
          final isTaxExempt = c['is_tax_exempt'] == true;
          return Card(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () { WidgetsBinding.instance.addPostFrameCallback((_) { Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomerFormScreen(authService: widget.authService, salesService: widget.salesService, customer: c),
              )).then((_) => _load(query: _searchController.text)); }); },
              child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: isTaxExempt ? Colors.green.withValues(alpha: 0.12) : Colors.indigo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text((c['name']?.toString() ?? 'C')[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isTaxExempt ? Colors.green : Colors.indigo)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(c['customer_code']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(status)))),
                    if (isTaxExempt) ...[const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('TAX EXEMPT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green))),
                    ],
                  ]),
                  const SizedBox(height: 2), Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if ((c['contact_email']?.toString() ?? '').isNotEmpty) Text(c['contact_email'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if ((c['contact_email']?.toString() ?? '').isNotEmpty && (c['contact_phone']?.toString() ?? '').isNotEmpty) Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                    if ((c['contact_phone']?.toString() ?? '').isNotEmpty) Text(c['contact_phone'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ]),
                  Row(children: [
                    if ((c['billing_city']?.toString() ?? '').isNotEmpty)
                      Text('${c['billing_city']}, ${c['billing_state'] ?? ''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ]),
                ])),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
              ])),
          ));
        },
      ),
    );
  }
}
