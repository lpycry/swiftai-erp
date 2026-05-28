import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class ReceiptListScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const ReceiptListScreen({super.key, required this.authService, required this.purchaseService});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  List<PurchaseReceiptModel> _receipts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _receipts = await widget.purchaseService.listReceipts();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goods Receipts')),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _load, child: const Text('Retry')),
    ]));
    if (_receipts.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_outlined, size: 48, color: Colors.grey.shade400),
      const SizedBox(height: 12),
      Text('No goods receipts yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('Receipts are created when goods are received against POs via the GR screen in Logistics',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
    ]));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _receipts.length,
        itemBuilder: (_, i) {
          final r = _receipts[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory, color: Colors.teal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.poNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                    Text(r.itemName.isNotEmpty ? r.itemName : r.itemSku, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ])),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${r.quantity} @ ${PurchaseService.fmtAmount(r.unitCost)}', style: const TextStyle(fontSize: 12)),
                    Text('Total: ${PurchaseService.fmtAmount(r.totalCost)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  if (r.batchNo.isNotEmpty) _chip('Batch: ${r.batchNo}', Colors.blue),
                  if (r.batchNo.isNotEmpty) const SizedBox(width: 6),
                  _chip(r.siteName.isNotEmpty ? r.siteName : r.siteCode, Colors.grey),
                  const Spacer(),
                  Text(_formatDate(r.receiptDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
  }

  String _formatDate(String d) {
    if (d.isEmpty) return '';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) { return d.length > 10 ? d.substring(0, 10) : d; }
  }
}
