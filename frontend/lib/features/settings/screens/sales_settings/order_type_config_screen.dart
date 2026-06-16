import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';

class OrderTypeConfigScreen extends StatefulWidget {
  final AuthService authService;
  const OrderTypeConfigScreen({super.key, required this.authService});
  @override State<OrderTypeConfigScreen> createState() => OrderTypeConfigScreenState();
}

class OrderTypeConfigScreenState extends State<OrderTypeConfigScreen> {
  static const String _baseUrl = 'http://localhost:8080/api/v1';
  List<dynamic> _configs = [];
  bool _loading = true;
  String get _token => widget.authService.accessToken ?? '';

  @override void initState() { super.initState(); _load(); }

  void triggerCreate() => _showCreateDialog();
  void triggerRefresh() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/sales/order-types'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        if (mounted) setState(() => _configs = jsonDecode(resp.body)['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  // ── Create Dialog ──
  Future<void> _showCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _OrderTypeFormDialog(authService: widget.authService, isEdit: false),
    );
    if (result != null) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl/sales/order-types'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
        if (resp.statusCode < 400) { _msg('Order type created'); _load(); }
        else { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Create failed'); }
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  // ── Edit Dialog ──
  Future<void> _showEditDialog(dynamic cfg) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _OrderTypeFormDialog(authService: widget.authService, isEdit: true, config: cfg),
    );
    if (result != null) {
      try {
        final resp = await http.put(
          Uri.parse('$_baseUrl/sales/order-types/${cfg['id']}'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
        if (resp.statusCode < 400) { _msg('Order type updated'); _load(); }
        else { final b = jsonDecode(resp.body); throw Exception(b['message'] ?? 'Update failed'); }
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  // ── Delete ──
  Future<void> _confirmDelete(dynamic cfg) async {
    if (cfg['is_system'] == true) { _msg('Cannot delete system order type', isError: true); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Order Type'), content: Text('Delete "${cfg['description']}" (${cfg['order_type']})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      try {
        await http.delete(Uri.parse('$_baseUrl/sales/order-types/${cfg['id']}'), headers: {'Authorization': 'Bearer $_token'});
        _msg('Deleted'); _load();
      } catch (e) { _msg('$e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No order types', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _configs.length,
                  itemBuilder: (_, i) {
                    final cfg = _configs[i];
                    final isSystem = cfg['is_system'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: (cfg['is_active'] == true ? Colors.teal : Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(cfg['order_type'] ?? '', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold,
                              color: cfg['is_active'] == true ? Colors.teal : Colors.grey,
                              fontFamily: 'monospace',
                            )),
                          ),
                        ),
                        title: Row(children: [
                          Text(cfg['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                            child: Text(cfg['order_type'] ?? '', style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontFamily: 'monospace')),
                          ),
                          if (isSystem) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(3)),
                              child: Text('SYSTEM', style: TextStyle(fontSize: 8, color: Colors.blue.shade600)),
                            ),
                          ],
                        ]),
                        subtitle: Row(children: [
                          Icon(Icons.circle, size: 6, color: cfg['is_active'] == true ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text(cfg['is_active'] == true ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Text('Sort: ${cfg['sort_order'] ?? 0}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showEditDialog(cfg), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                          if (!isSystem)
                            IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _confirmDelete(cfg), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(children: [
                              _sectionHeader('Logistics & Stock Control'),
                              _fieldRow('Requires Shipping', _boolIcon(cfg['requires_shipping'])),
                              _fieldRow('Direction', Text(cfg['shipping_direction'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('Auto Delivery', _boolIcon(cfg['auto_create_delivery'])),
                              _fieldRow('Auto PGI/PGR', _boolIcon(cfg['auto_pgi_pgr'])),
                              _fieldRow('Stock Type', Text(cfg['target_stock_type'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('Auto Confirm SO', _boolIcon(cfg['auto_confirm_so'])),
                              _fieldRow('Packing Slip', _boolIcon(cfg['packing_slip'])),
                              const Divider(height: 12),
                              _sectionHeader('Risk & Validation'),
                              _fieldRow('Credit Check', _boolIcon(cfg['credit_check_required'])),
                              _fieldRow('ATP Logic', Text(cfg['atp_check_logic'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('Requires Reference', _boolIcon(cfg['reference_required'])),
                              const Divider(height: 12),
                              _sectionHeader('Pricing & Finance'),
                              _fieldRow('Pricing', Text(cfg['pricing_procedure'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('Billing Trigger', Text(cfg['billing_trigger'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('Billing Type', Text(cfg['billing_type'] ?? '-', style: const TextStyle(fontSize: 11))),
                              _fieldRow('GL Strategy', Text(cfg['gl_account_strategy'] ?? '-', style: const TextStyle(fontSize: 11))),
                              const Divider(height: 12),
                              _sectionHeader('Block Control'),
                              _fieldRow('Default Billing Block', _boolIcon(cfg['billing_block_default'])),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.teal.shade600, letterSpacing: 0.5)),
        const Spacer(),
      ]),
    );
  }

  Widget _fieldRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 150, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        Expanded(child: value),
      ]),
    );
  }

  Widget _boolIcon(bool? v) {
    return v == true
        ? Icon(Icons.check_circle, size: 14, color: Colors.green.shade400)
        : Icon(Icons.remove_circle_outline, size: 14, color: Colors.grey.shade400);
  }
}

// ═══════════════════════════════════════════════
//  Create / Edit Form Dialog
// ═══════════════════════════════════════════════

class _OrderTypeFormDialog extends StatefulWidget {
  final AuthService authService;
  final bool isEdit;
  final dynamic config;
  const _OrderTypeFormDialog({required this.authService, required this.isEdit, this.config});

  @override State<_OrderTypeFormDialog> createState() => _OrderTypeFormDialogState();
}

class _OrderTypeFormDialogState extends State<_OrderTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _orderTypeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();

  bool _requiresShipping = true;
  String _shippingDirection = 'outbound';
  bool _autoCreateDelivery = false;
  bool _autoPgiPgr = false;
  String _targetStockType = 'unrestricted';

  bool _creditCheckRequired = false;
  String _atpCheckLogic = 'hard';
  bool _referenceRequired = false;

  String _pricingProcedure = 'standard';
  String _billingTrigger = 'post_delivery';
  String _billingType = 'invoice';
  String _glAccountStrategy = 'standard_sales';

  bool _billingBlockDefault = false;
  bool _autoConfirmSO = false;
  bool _packingSlip = false;

  @override void initState() {
    super.initState();
    if (widget.isEdit && widget.config != null) {
      final c = widget.config;
      _descCtrl.text = c['description'] ?? '';
      _sortCtrl.text = (c['sort_order'] ?? 0).toString();
      _requiresShipping = c['requires_shipping'] ?? true;
      _shippingDirection = c['shipping_direction'] ?? 'outbound';
      _autoCreateDelivery = c['auto_create_delivery'] ?? false;
      _autoPgiPgr = c['auto_pgi_pgr'] ?? false;
      _targetStockType = c['target_stock_type'] ?? 'unrestricted';
      _creditCheckRequired = c['credit_check_required'] ?? false;
      _atpCheckLogic = c['atp_check_logic'] ?? 'hard';
      _referenceRequired = c['reference_required'] ?? false;
      _pricingProcedure = c['pricing_procedure'] ?? 'standard';
      _billingTrigger = c['billing_trigger'] ?? 'post_delivery';
      _billingType = c['billing_type'] ?? 'invoice';
      _glAccountStrategy = c['gl_account_strategy'] ?? 'standard_sales';
      _billingBlockDefault = c['billing_block_default'] ?? false;
      _autoConfirmSO = c['auto_confirm_so'] ?? false;
      _packingSlip = c['packing_slip'] ?? false;
    }
  }

  @override void dispose() {
    _orderTypeCtrl.dispose(); _descCtrl.dispose(); _sortCtrl.dispose();
    super.dispose();
  }

  static const _shipDirOpts = ['outbound', 'inbound', 'none'];
  static const _stockTypeOpts = ['unrestricted', 'quality_inspection', 'consignment', 'in_transit'];
  static const _atpOpts = ['hard', 'soft', 'none'];
  static const _priceOpts = ['standard', 'zero_price', 'intercompany'];
  static const _billTrigOpts = ['order_save', 'post_delivery', 'none'];
  static const _billTypeOpts = ['invoice', 'credit_memo', 'none'];
  static const _glOpts = ['standard_sales', 'sales_expense', 'intercompany_trade', 'none'];

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true, decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        SizedBox(width: 36, height: 28, child: Switch(value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
      ]),
    );
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'order_type': widget.isEdit ? widget.config['order_type'] : _orderTypeCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim(),
      'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
      'requires_shipping': _requiresShipping,
      'shipping_direction': _shippingDirection,
      'auto_create_delivery': _autoCreateDelivery,
      'auto_pgi_pgr': _autoPgiPgr,
      'target_stock_type': _targetStockType,
      'credit_check_required': _creditCheckRequired,
      'atp_check_logic': _atpCheckLogic,
      'reference_required': _referenceRequired,
      'pricing_procedure': _pricingProcedure,
      'billing_trigger': _billingTrigger,
      'billing_type': _billingType,
      'gl_account_strategy': _glAccountStrategy,
      'billing_block_default': _billingBlockDefault,
      'auto_confirm_so': _autoConfirmSO,
      'packing_slip': _packingSlip,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
        child: Row(children: [
          Icon(Icons.category_outlined, size: 20, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Text(widget.isEdit ? 'Edit Order Type' : 'New Order Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
        ]),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isEdit)
                  TextFormField(controller: _orderTypeCtrl, decoration: const InputDecoration(labelText: 'Order Type Code', isDense: true, hintText: 'e.g. CP', helperText: '2-4 characters'), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null, onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), style: const TextStyle(fontSize: 12), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                TextFormField(controller: _sortCtrl, decoration: const InputDecoration(labelText: 'Sort Order', isDense: true), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                Text('Logistics & Stock Control', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade600)),
                _switchRow('Requires Shipping', _requiresShipping, (v) => setState(() => _requiresShipping = v)),
                if (_requiresShipping) _dropdown('Shipping Direction', _shippingDirection, _shipDirOpts, (v) => setState(() => _shippingDirection = v ?? 'outbound')),
                _switchRow('Auto Create Delivery', _autoCreateDelivery, (v) => setState(() => _autoCreateDelivery = v)),
                _switchRow('Auto PGI/PGR', _autoPgiPgr, (v) => setState(() => _autoPgiPgr = v)),
                _dropdown('Target Stock Type', _targetStockType, _stockTypeOpts, (v) => setState(() => _targetStockType = v ?? 'unrestricted')),
                _switchRow('Auto Confirm SO', _autoConfirmSO, (v) => setState(() => _autoConfirmSO = v)),
                _switchRow('Packing Slip', _packingSlip, (v) => setState(() => _packingSlip = v)),
                const SizedBox(height: 8),
                Text('Risk & Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade600)),
                _switchRow('Credit Check Required', _creditCheckRequired, (v) => setState(() => _creditCheckRequired = v)),
                _dropdown('ATP Check Logic', _atpCheckLogic, _atpOpts, (v) => setState(() => _atpCheckLogic = v ?? 'hard')),
                _switchRow('Requires Reference Document', _referenceRequired, (v) => setState(() => _referenceRequired = v)),
                const SizedBox(height: 8),
                Text('Pricing & Finance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade600)),
                _dropdown('Pricing Procedure', _pricingProcedure, _priceOpts, (v) => setState(() => _pricingProcedure = v ?? 'standard')),
                _dropdown('Billing Trigger', _billingTrigger, _billTrigOpts, (v) => setState(() => _billingTrigger = v ?? 'post_delivery')),
                _dropdown('Billing Type', _billingType, _billTypeOpts, (v) => setState(() => _billingType = v ?? 'invoice')),
                _dropdown('GL Account Strategy', _glAccountStrategy, _glOpts, (v) => setState(() => _glAccountStrategy = v ?? 'standard_sales')),
                const SizedBox(height: 8),
                Text('Block Control', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade600)),
                _switchRow('Default Billing Block', _billingBlockDefault, (v) => setState(() => _billingBlockDefault = v)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) Navigator.pop(context, _buildPayload()); }, child: Text(widget.isEdit ? 'Update' : 'Create', style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
