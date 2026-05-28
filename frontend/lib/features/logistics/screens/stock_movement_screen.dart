import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class StockMovementScreen extends StatefulWidget {
  final AuthService authService;
  final WarehouseService warehouseService;

  const StockMovementScreen({
    super.key,
    required this.authService,
    required this.warehouseService,
  });

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['Goods Receipt', 'Goods Issue', 'Transfer'];

  List<dynamic> _warehouses = [];
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRefData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRefData() async {
    try {
      final whs = await widget.warehouseService.listWarehouses();
      final prods = await widget.warehouseService.listProducts();
      if (mounted) setState(() { _warehouses = whs; _products = prods; });
    } catch (_) { /* ignore */ }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Stock Movements',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.accentBlue,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MovementForm(txType: 'goods_receipt', warehouses: _warehouses, products: _products, svc: widget.warehouseService),
                _MovementForm(txType: 'goods_issue', warehouses: _warehouses, products: _products, svc: widget.warehouseService),
                _TransferForm(warehouses: _warehouses, products: _products, svc: widget.warehouseService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementForm extends StatefulWidget {
  final String txType;
  final List<dynamic> warehouses;
  final List<dynamic> products;
  final WarehouseService svc;

  const _MovementForm({required this.txType, required this.warehouses, required this.products, required this.svc});

  @override
  State<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<_MovementForm> {
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String? _selectedProductId;
  String? _selectedWhId;
  bool _loading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.txType) {
      case 'goods_receipt': return 'Goods Receipt';
      case 'goods_issue': return 'Goods Issue';
      default: return 'Movement';
    }
  }

  Future<void> _submit() async {
    if (_selectedProductId == null || _selectedWhId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select product and warehouse'), backgroundColor: AppTheme.errorColor));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid quantity'), backgroundColor: AppTheme.errorColor));
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.svc.postMovement({
        'transaction_type': widget.txType,
        'product_id': _selectedProductId,
        'warehouse_id': _selectedWhId,
        'quantity': qty,
        'unit_cost': double.tryParse(_costCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'reference_no': _refCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_title posted successfully'), backgroundColor: Colors.green));
        _qtyCtrl.clear();
        _costCtrl.clear();
        _descCtrl.clear();
        _refCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_title failed: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.txType == 'goods_receipt' ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: widget.txType == 'goods_receipt' ? Colors.green.shade700 : Colors.orange.shade700)),
              ),
              const SizedBox(height: 16),
              // Product
              if (widget.products.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Product', isDense: true),
                  items: widget.products.map((p) => DropdownMenuItem(
                    value: p['id']?.toString(),
                    child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                ),
              const SizedBox(height: 12),
              // Warehouse
              if (widget.warehouses.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Warehouse', isDense: true),
                  items: widget.warehouses.map((w) => DropdownMenuItem(
                    value: w['id']?.toString(),
                    child: Text('${w['code']} - ${w['name']}', style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedWhId = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _costCtrl, decoration: const InputDecoration(labelText: 'Unit Cost', isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Reference No', isDense: true), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), maxLines: 2, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.post_add, size: 18),
                  label: Text(_loading ? 'Posting...' : 'Post $_title'),
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.txType == 'goods_receipt' ? Colors.green.shade700 : Colors.orange.shade700,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferForm extends StatefulWidget {
  final List<dynamic> warehouses;
  final List<dynamic> products;
  final WarehouseService svc;
  const _TransferForm({required this.warehouses, required this.products, required this.svc});

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedProductId;
  String? _fromWhId;
  String? _toWhId;
  bool _loading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedProductId == null || _fromWhId == null || _toWhId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select product, from/to warehouse'), backgroundColor: AppTheme.errorColor));
      return;
    }
    if (_fromWhId == _toWhId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and To warehouse must be different'), backgroundColor: AppTheme.errorColor));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) return;

    setState(() => _loading = true);
    try {
      await widget.svc.postMovement({
        'transaction_type': 'transfer',
        'product_id': _selectedProductId,
        'warehouse_id': _fromWhId,
        'to_warehouse_id': _toWhId,
        'quantity': qty,
        'description': _descCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer posted successfully'), backgroundColor: Colors.green));
        _qtyCtrl.clear();
        _descCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('Stock Transfer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Product', isDense: true),
                items: widget.products.map((p) => DropdownMenuItem(
                  value: p['id']?.toString(),
                  child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedProductId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'From Warehouse', isDense: true),
                    items: widget.warehouses.map((w) => DropdownMenuItem(
                      value: w['id']?.toString(),
                      child: Text('${w['code']}', style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    onChanged: (v) => setState(() => _fromWhId = v),
                  )),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 20),
                  ),
                  Expanded(child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'To Warehouse', isDense: true),
                    items: widget.warehouses.map((w) => DropdownMenuItem(
                      value: w['id']?.toString(),
                      child: Text('${w['code']}', style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    onChanged: (v) => setState(() => _toWhId = v),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.swap_horiz, size: 18),
                  label: Text(_loading ? 'Transferring...' : 'Post Transfer'),
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
