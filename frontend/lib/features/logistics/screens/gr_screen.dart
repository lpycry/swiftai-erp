import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

/// ── Goods Receipt Screen ──
/// Tab 0: PO Receiving — link PO → select site/wh/bin → confirm qty → submit → auto GL post
/// Tab 1: Receipt History — list receipts with "View Journal Entry" button

class GoodReceiptScreen extends StatefulWidget {
  final AuthService authService;
  final dynamic warehouseService; // kept for external compatibility, unused
  const GoodReceiptScreen({super.key, required this.authService, this.warehouseService});
  @override State<GoodReceiptScreen> createState() => _GoodReceiptScreenState();
}

class _GoodReceiptScreenState extends State<GoodReceiptScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _ps = PurchaseService('');

  @override void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _ps.updateToken(widget.authService.accessToken ?? '');
  }
  @override void dispose() { _tc.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 2,
      onIndexChanged: (_) {},
      title: 'Goods Receipt',
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: TabBar(
              controller: _tc,
              labelColor: Colors.green.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.green,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'PO Receiving', icon: Icon(Icons.arrow_circle_down_outlined, size: 20)),
                Tab(text: 'Receipt History', icon: Icon(Icons.receipt_long_outlined, size: 20)),
              ],
            ),
          ),
          Expanded(child: TabBarView(controller: _tc, children: [
            _POReceiveTab(authService: widget.authService, ps: _ps),
            _ReceiptHistoryTab(authService: widget.authService, ps: _ps),
          ])),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 0 — PO RECEIVING
// ═══════════════════════════════════════════════════════════════

class _POReceiveTab extends StatefulWidget {
  final AuthService authService;
  final PurchaseService ps;
  const _POReceiveTab({required this.authService, required this.ps});
  @override State<_POReceiveTab> createState() => _POReceiveTabState();
}

class _POReceiveTabState extends State<_POReceiveTab> {
  bool _loading = true;
  bool _posting = false;

  List<PurchaseOrderModel> _availablePOs = [];
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _bins = [];

  PurchaseOrderModel? _selectedPO;
  final List<_RecvItem> _items = [];

  String? _token;

  @override void initState() { super.initState(); _token = widget.authService.accessToken; _load(); }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await widget.ps.listPOs(status: 'CONFIRMED');
      final r = await widget.ps.listPOs(status: 'RECEIVED');
      // Filter out fully-received POs: fetch full details and check remaining qty
      final allPOs = [...c, ...r];
      final partialPOs = <PurchaseOrderModel>[];
      for (final po in allPOs) {
        try {
          final full = await widget.ps.getPO(po.id);
          final hasRemaining = full.items.any((item) => item.quantity - item.receivedQuantity > 0);
          if (hasRemaining) partialPOs.add(po);
        } catch (_) {}
      }
      _availablePOs = partialPOs..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final sr = await http.get(Uri.parse('http://localhost:8080/api/v1/sites'), headers: _headers);
      if (sr.statusCode < 400) _sites = ((jsonDecode(sr.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

      final wr = await http.get(Uri.parse('http://localhost:8080/api/v1/warehouse/warehouses'), headers: _headers);
      if (wr.statusCode < 400) _warehouses = ((jsonDecode(wr.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

      // Fetch bins
      final br = await http.get(Uri.parse('http://localhost:8080/api/v1/warehouse/bins'), headers: _headers);
      if (br.statusCode < 400) _bins = ((jsonDecode(br.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _onPOSelected(PurchaseOrderModel? po) async {
    if (po == null) { setState(() { _selectedPO = null; _items.clear(); }); return; }

    // Use GetPO to load line items; keep _selectedPO as the original reference from _availablePOs
    setState(() { _selectedPO = po; _loading = true; });
    try {
      final fullPO = await widget.ps.getPO(po.id);
      setState(() {
        _items.clear();
        for (final item in fullPO.items) {
          final rem = item.quantity - item.receivedQuantity;
          if (rem > 0) {
            _items.add(_RecvItem(
              itemId: item.itemId,
              sku: item.itemSku,
              name: item.itemName,
              uom: item.unitOfMeasure,
              ordered: item.quantity,
              received: item.receivedQuantity,
              remaining: rem,
              unitPrice: item.unitPrice,
            ));
          }
        }
      });
    } catch (e) {
      _err('Failed to load PO details: $e');
      setState(() { _items.clear(); });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedPO == null) { _err('Please select a Purchase Order first.'); return; }
    if (_items.every((it) => it.qtyToReceive <= 0)) { _err('Enter at least one receiving quantity (> 0).'); return; }

    setState(() => _posting = true);
    int ok = 0, fail = 0;

    for (final it in _items) {
      if (it.qtyToReceive <= 0) continue;
      if (it.selectedSiteId == null) { fail++; _err('${it.sku}: Site is required.'); continue; }

      try {
        final body = <String, dynamic>{
          'po_id': _selectedPO!.id,
          'item_id': it.itemId,
          'site_id': it.selectedSiteId,
          'quantity': it.qtyToReceive,
          'unit_cost': it.unitPrice, // use PO unit price — user cannot change
        };
        if (it.selectedWhId != null) body['warehouse_id'] = it.selectedWhId;
        if (it.selectedBinId != null) body['bin_id'] = it.selectedBinId;
        if (it.batchNo.trim().isNotEmpty) body['batch_no'] = it.batchNo.trim();

        await widget.ps.executeGoodsReceipt(body);
        ok++;
      } catch (e) {
        fail++;
        _err('${it.sku}: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }

    if (mounted) {
      _snack(ok > 0 ? '$ok item(s) received successfully${fail > 0 ? ', $fail failed' : ''}.'
          : 'All items failed.', fail > 0 ? Colors.orange : Colors.green);
      // After submit, find the matching PO in _availablePOs (same reference) to avoid dropdown assertion
      try {
        final reloadedItems = await widget.ps.getPO(_selectedPO!.id);
        final originalPO = _availablePOs.cast<PurchaseOrderModel?>().firstWhere((p) => p!.id == _selectedPO!.id, orElse: () => null);
        if (originalPO != null) {
          // Update the available POs list: remove fully-received PO, keep partial
          final stillRemaining = reloadedItems.items.any((item) => item.quantity - item.receivedQuantity > 0);
          if (stillRemaining) {
            _onPOSelected(originalPO); // reload with original reference
          } else {
            // PO fully received — remove from list and clear selection
            _availablePOs.removeWhere((p) => p.id == _selectedPO!.id);
            _onPOSelected(null);
          }
        } else {
          _onPOSelected(null);
        }
      } catch (_) {
        _onPOSelected(null);
      }
    }
    setState(() => _posting = false);
  }

  void _err(String msg) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red)); }
  void _snack(String msg, Color c) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c)); }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  String _d(String d) {
    if (d.isEmpty) return '-';
    try { final dt = DateTime.parse(d); return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'; }
    catch (_) { return d.length > 10 ? d.substring(0, 10) : d; }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── PO Selector ──
            _section('PURCHASE ORDER', Colors.green, children: [
              // Use string ID as value to avoid Flutter dropdown reference identity assertion
            DropdownButtonFormField<String>(
                value: _selectedPO?.id,
                decoration: const InputDecoration(
                  labelText: 'Select Purchase Order *',
                  hintText: 'Choose a PO to receive against...',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                isExpanded: true,
                items: _availablePOs.map((po) => DropdownMenuItem(
                  value: po.id,
                  child: Text('${po.poNumber}  |  ${po.vendorName}  |  ${po.currency} ${PurchaseService.fmtAmount(po.totalAmount)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                )).toList(),
                onChanged: (id) {
                  final po = _availablePOs.cast<PurchaseOrderModel?>().firstWhere((p) => p!.id == id, orElse: () => null);
                  _onPOSelected(po);
                },
              ),
            ]),

            // ── PO Summary ──
            if (_selectedPO != null) ...[
              const SizedBox(height: 12),
              _section('PO HEADER', Colors.indigo, children: [
                _row('PO Number', _selectedPO!.poNumber, true),
                _row('Vendor', _selectedPO!.vendorName.isNotEmpty ? _selectedPO!.vendorName : _selectedPO!.vendorCode),
                _row('PO Date', _d(_selectedPO!.poDate)),
                if (_selectedPO!.paymentTermCode.isNotEmpty) _row('Pay Terms', _selectedPO!.paymentTermCode),
                _row('Delivery', _selectedPO!.deliveryAddress.isNotEmpty ? _selectedPO!.deliveryAddress : '-'),
                const Divider(height: 12),
                _row('Total Amount', '${_selectedPO!.currency} ${PurchaseService.fmtAmount(_selectedPO!.totalAmount)}', true),
              ]),
            ],

            // ── Items to receive ──
            if (_selectedPO != null && _items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade300),
                  const SizedBox(height: 12),
                  Text('All items have been fully received.',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                ]),
              ),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Text('ITEMS TO RECEIVE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal)),
                const Spacer(),
                Text('${_items.length} remaining', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 8),
              for (int i = 0; i < _items.length; i++) _buildItemCard(i),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  icon: _posting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.post_add_rounded, size: 22),
                  label: Text(_posting ? 'Posting...' : 'Post Goods Receipt',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onPressed: _posting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int i) {
    final it = _items[i];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.inventory_2_outlined, size: 20, color: Colors.teal),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${it.sku}  ${it.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text('Ordered: ${_fmt(it.ordered)}  |  Received: ${_fmt(it.received)}  |  Remaining: ${_fmt(it.remaining)} ${it.uom}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ])),
          ]),
          const SizedBox(height: 14),

          // Row 1: Receive Qty (unit cost shown as read-only)
          Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Receive Qty * (max ${_fmt(it.remaining)})',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                onChanged: (v) {
                  final q = double.tryParse(v) ?? 0;
                  it.qtyToReceive = q.clamp(0, it.remaining);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Text('Unit Cost: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text('\$${PurchaseService.fmtAmount(it.unitPrice)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Row 2: Site + Warehouse
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: it.selectedSiteId,
                decoration: InputDecoration(
                  labelText: 'Site *',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                isExpanded: true,
                items: _sites.map((s) => DropdownMenuItem(
                  value: s['id']?.toString(),
                  child: Text('${s['site_code'] ?? ''}  ${s['site_name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    it.selectedSiteId = v;
                    it.selectedWhId = null;
                    it.selectedBinId = null;
                    // Auto-select if only one warehouse for this site
                    if (v != null) {
                      final whs = _warehouses.where((w) => (w['site_id']?.toString() ?? '') == v).toList();
                      if (whs.length == 1) it.selectedWhId = whs.first['id']?.toString();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: it.selectedWhId,
                decoration: InputDecoration(
                  labelText: 'Warehouse',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                isExpanded: true,
                items: (_warehouses.where((w) => it.selectedSiteId == null || (w['site_id']?.toString() ?? '') == it.selectedSiteId)).map((w) => DropdownMenuItem(
                  value: w['id']?.toString(),
                  child: Text('${w['code'] ?? w['warehouse_code'] ?? ''}', style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    it.selectedWhId = v;
                    it.selectedBinId = null;
                    // Auto-select if only one bin for this warehouse
                    if (v != null) {
                      final bins = _bins.where((b) => (b['warehouse_id']?.toString() ?? '') == v).toList();
                      if (bins.length == 1) it.selectedBinId = bins.first['id']?.toString();
                    }
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Row 3: Bin Location (filtered by selected warehouse)
          DropdownButtonFormField<String>(
            value: it.selectedBinId,
            decoration: InputDecoration(
              labelText: 'Bin Location',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            isExpanded: true,
            items: (_bins.where((b) => it.selectedWhId == null || (b['warehouse_id']?.toString() ?? '') == it.selectedWhId)).map((b) => DropdownMenuItem(
              value: b['id']?.toString(),
              child: Text('${b['code'] ?? b['bin_code'] ?? ''}  ${b['name'] ?? b['bin_name'] ?? ''}', style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (v) => setState(() => it.selectedBinId = v),
          ),
          const SizedBox(height: 10),

          // Row 4: Batch No
          TextField(
            decoration: InputDecoration(
              labelText: 'Batch / Lot Number',
              hintText: 'Optional',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => it.batchNo = v,
          ),

          // Line total preview
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Line total: ${PurchaseService.fmtAmount(it.qtyToReceive * it.unitPrice)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ──

  Widget _section(String title, Color color, {required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _row(String label, String value, [bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
      ]),
    );
  }
}

/// Internal model for one receiving line
class _RecvItem {
  final String itemId, sku, name, uom;
  final double ordered, received, remaining, unitPrice;
  double qtyToReceive = 0;
  String? selectedSiteId;
  String? selectedWhId;
  String? selectedBinId;
  String batchNo = '';

  _RecvItem({
    required this.itemId, required this.sku, required this.name, required this.uom,
    required this.ordered, required this.received, required this.remaining, required this.unitPrice,
  });
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1 — RECEIPT HISTORY + JOURNAL ENTRY VIEWER
// ═══════════════════════════════════════════════════════════════

class _ReceiptHistoryTab extends StatefulWidget {
  final AuthService authService;
  final PurchaseService ps;
  const _ReceiptHistoryTab({required this.authService, required this.ps});
  @override State<_ReceiptHistoryTab> createState() => _ReceiptHistoryTabState();
}

class _ReceiptHistoryTabState extends State<_ReceiptHistoryTab> {
  List<PurchaseReceiptModel> _receipts = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _receipts = await widget.ps.listReceipts(); } catch (_) {}
    setState(() => _loading = false);
  }

  String _q(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _reverseReceipt(PurchaseReceiptModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Goods Receipt'),
        content: Text('This will reverse the following receipt and revert PO/stock/accounting:\n\n'
            '${r.poNumber} — ${r.itemName.isNotEmpty ? r.itemName : r.itemSku} × ${_q(r.quantity)}\n'
            'Amount: ${PurchaseService.fmtAmount(r.totalCost)}\n\n'
            'Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Reverse')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.ps.reverseReceipt(r.id);
      _load();
      _snack('Receipt reversed successfully', Colors.orange);
    } catch (e) {
      _snack('Reverse failed: $e', Colors.red);
    }
  }

  /// Fetch and display journal entry for a given receipt
  Future<void> _viewJournalEntry(String receiptId) async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)))) ;

    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/purchase/receipts/$receiptId/journal'),
        headers: {'Authorization': 'Bearer ${widget.authService.accessToken}'},
      );

      if (mounted) Navigator.pop(context); // dismiss loader

      if (resp.statusCode == 404 || resp.statusCode >= 400) {
        _snack('No journal entry found for this receipt', Colors.orange);
        return;
      }

      final je = jsonDecode(resp.body)['data'] as Map<String, dynamic>?;
      if (je == null) { _snack('No journal entry data', Colors.orange); return; }

      if (mounted) _showJournalEntryDialog(je);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('${e.toString().replaceFirst('Exception: ', '')}', Colors.red);
    }
  }

  void _showJournalEntryDialog(Map<String, dynamic> je) {
    final lines = (je['lines'] as List<dynamic>?) ?? <dynamic>[];
    final totalDr = lines.fold<double>(0, (s, l) => s + ((l['debit'] as num?)?.toDouble() ?? 0));
    final totalCr = lines.fold<double>(0, (s, l) => s + ((l['credit'] as num?)?.toDouble() ?? 0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long, size: 18, color: Colors.indigo),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(je['document_no']?.toString() ?? 'JE', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(je['description']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (je['status'] == 'posted' ? Colors.green : Colors.orange).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              (je['status']?.toString() ?? '').toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: je['status'] == 'posted' ? Colors.green : Colors.orange),
            ),
          ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(),
            const SizedBox(height: 4),
            // Column headers
            Row(children: [
              const SizedBox(width: 30),
              const Expanded(child: Text('Account', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
              SizedBox(width: 80, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
              SizedBox(width: 80, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey))),
            ]),
            const SizedBox(height: 4),
            // Lines
            ...lines.map((l) {
              final m = l as Map<String, dynamic>;
              final dr = (m['debit'] as num?)?.toDouble() ?? 0;
              final cr = (m['credit'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  // Dr/Cr badge
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: (dr > 0 ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text(dr > 0 ? 'Dr' : 'Cr',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: dr > 0 ? Colors.green.shade700 : Colors.orange.shade700))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['account_code']}  ${m['account_name']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    if ((m['partner_type']?.toString() ?? '').isNotEmpty)
                      Text('[${m['partner_type']}]', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                  ])),
                  SizedBox(width: 80, child: Text(dr > 0 ? PurchaseService.fmtAmount(dr) : '',
                      textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dr > 0 ? Colors.green.shade700 : Colors.grey.shade400))),
                  SizedBox(width: 80, child: Text(cr > 0 ? PurchaseService.fmtAmount(cr) : '',
                      textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cr > 0 ? Colors.orange.shade700 : Colors.grey.shade400))),
                ]),
              );
            }),
            const Divider(height: 20),
            // Totals
            Row(children: [
              const Spacer(),
              SizedBox(width: 80, child: Text(PurchaseService.fmtAmount(totalDr),
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              SizedBox(width: 80, child: Text(PurchaseService.fmtAmount(totalCr),
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_receipts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.receipt_long_outlined, size: 32, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text('No Goods Receipts Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text('Receive goods against a PO to create receipts.\nThey will appear here with linked journal entries.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _receipts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final r = _receipts[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(children: [
                // Icon
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: r.isReversed ? Colors.orange.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(r.isReversed ? Icons.undo_rounded : Icons.arrow_downward_rounded,
                      color: r.isReversed ? Colors.orange : Colors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (r.isReversed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('CANCELLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                      ),
                    Text(r.poNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
                  ]),
                  const SizedBox(height: 2),
                  Text('${r.itemName.isNotEmpty ? r.itemName : r.itemSku} × ${_q(r.quantity)} @ ${PurchaseService.fmtAmount(r.unitCost)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (r.batchNo.isNotEmpty)
                      Text('Batch: ${r.batchNo}', style: TextStyle(fontSize: 10, color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
                    if (r.batchNo.isNotEmpty) const SizedBox(width: 8),
                    Text('${r.siteCode.isNotEmpty ? r.siteCode : ''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ]),
                ])),
                // Total + actions
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(PurchaseService.fmtAmount(r.totalCost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    // Cancel button
                    if (!r.isReversed)
                      SizedBox(
                        width: 32, height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.undo_rounded, size: 18, color: Colors.red),
                          tooltip: 'Cancel Receipt',
                          onPressed: () => _reverseReceipt(r),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // View JE button
                    SizedBox(
                      width: 32, height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.receipt_rounded, size: 18, color: Colors.indigo),
                        tooltip: 'View Journal Entry',
                        onPressed: () => _viewJournalEntry(r.id),
                      ),
                    ),
                  ]),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
