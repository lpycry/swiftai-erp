import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class OutboundScreen extends StatefulWidget {
  final AuthService authService; final WarehouseService warehouseService;
  const OutboundScreen({super.key, required this.authService, required this.warehouseService});
  @override State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  List<dynamic> _orders = [], _products = [], _warehouses = [];

  @override void initState() { super.initState(); _tc = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tc.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final o = await widget.warehouseService.listOutbound();
      final p = await widget.warehouseService.listProducts();
      final w = await widget.warehouseService.listWarehouses();
      if (mounted) setState(() { _orders = o; _products = p; _warehouses = w; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {}, title: 'Outbound',
      body: Column(children: [
        TabBar(controller: _tc, labelColor: AppTheme.primaryColor, unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.accentBlue, tabs: const [Tab(text: 'New Order'), Tab(text: 'Orders')]),
        const Divider(height: 1),
        Expanded(child: TabBarView(controller: _tc, children: [
          _OBForm(products: _products, warehouses: _warehouses, svc: widget.warehouseService, onDone: _load),
          _OBList(orders: _orders, svc: widget.warehouseService, onChanged: _load),
        ])),
      ]),
    );
  }
}

class _OBForm extends StatefulWidget {
  final List<dynamic> products, warehouses; final WarehouseService svc; final VoidCallback onDone;
  const _OBForm({required this.products, required this.warehouses, required this.svc, required this.onDone});
  @override State<_OBForm> createState() => _OBFormState();
}

class _OBFormState extends State<_OBForm> {
  final _refCtrl = TextEditingController(), _custCtrl = TextEditingController(), _qtyCtrl = TextEditingController();
  String? _whId, _prodId; bool _loading = false;
  String _orderType = 'sales_order';

  @override void dispose() { _refCtrl.dispose(); _custCtrl.dispose(); _qtyCtrl.dispose(); super.dispose(); }

  void _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppTheme.errorColor));
  }

  Future<void> _submit() async {
    if (_whId == null || _prodId == null) { _err('Select product and warehouse'); return; }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) { _err('Enter valid quantity'); return; }
    setState(() => _loading = true);
    try {
      await widget.svc.createOutbound({'order_type': _orderType, 'reference_no': _refCtrl.text.trim(),
        'warehouse_id': _whId, 'customer_name': _custCtrl.text.trim(), 'lines': [
          {'product_id': _prodId, 'ordered_qty': qty},
        ]});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order created'), backgroundColor: Colors.green));
        widget.onDone();
        setState(() { _qtyCtrl.clear(); _refCtrl.clear(); _custCtrl.clear(); });
      }
    } catch (e) { if (mounted) _err('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16),
      child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
          child: Text('New Outbound Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700))),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Order Type', isDense: true),
          initialValue: _orderType,
          items: ['sales_order','production','transfer','return'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _orderType = v!),
        ),
        const SizedBox(height: 12),
        if (widget.warehouses.isNotEmpty) DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Warehouse *', isDense: true),
          items: widget.warehouses.map((w) => DropdownMenuItem(value: w['id']?.toString(), child: Text('${w['code']}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _whId = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Reference (SO#)', isDense: true), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: _custCtrl, decoration: const InputDecoration(labelText: 'Customer', isDense: true), style: const TextStyle(fontSize: 13)),
        const Divider(height: 20),
        const Text('Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        if (widget.products.isNotEmpty) DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Product', isDense: true),
          items: widget.products.map((p) => DropdownMenuItem(value: p['id']?.toString(), child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: (v) => setState(() => _prodId = v),
        ),
        const SizedBox(height: 8),
        TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: FilledButton.icon(
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.shopping_cart, size: 18),
            label: Text(_loading ? 'Creating...' : 'Create Order'), onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: Colors.orange.shade700))),
      ]))),
    );
  }
}

class _OBList extends StatelessWidget {
  final List<dynamic> orders; final WarehouseService svc; final VoidCallback onChanged;
  const _OBList({required this.orders, required this.svc, required this.onChanged});

  Color _stColor(String s) {
    switch (s) {
      case 'draft': return Colors.grey;
      case 'picking': return Colors.blue;
      case 'packed': return Colors.purple;
      case 'shipped': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('No orders', style: TextStyle(color: Colors.grey.shade500)),
      ]));
    }
    return ListView.builder(padding: const EdgeInsets.all(8), itemCount: orders.length,
      itemBuilder: (_, i) => _buildCard(context, orders[i]));
  }

  Widget _buildCard(BuildContext context, dynamic o) {
    final orderNo = o['order_no'] ?? o['id']?.toString().substring(0, 8) ?? '';
    final ref = o['reference_no'] ?? ''; final cust = o['customer_name'] ?? '';
    final status = o['status'] ?? 'draft';
    final lines = (o['lines'] as List<dynamic>?) ?? [];
    final qty = lines.fold<double>(0, (s, l) => s + ((l['ordered_qty'] as num?)?.toDouble() ?? 0));
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.arrow_upward, color: Colors.orange.shade700, size: 20)),
      title: Text('OB-$orderNo', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('$cust • $ref • Qty: ${qty.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _stColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _stColor(status)))),
    ));
  }
}
