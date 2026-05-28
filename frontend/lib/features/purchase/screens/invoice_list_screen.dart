import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_form_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const InvoiceListScreen({super.key, required this.authService, required this.purchaseService});
  @override State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<PurchaseInvoiceModel> _invoices = [];
  bool _loading = false;
  String? _statusFilter;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _invoices = await widget.purchaseService.listInvoices();
      if (_statusFilter != null) {
        _invoices = _invoices.where((i) => i.status == _statusFilter).toList();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT': return Colors.grey;
      case 'MATCHED': return Colors.teal;
      case 'PARTIALLY_POSTED': return Colors.blue;
      case 'POSTED': return Colors.green;
      case 'BLOCKED': return Colors.red;
      case 'REJECTED': return Colors.red.shade800;
      default: return Colors.grey;
    }
  }

  Color _matchColor(String m) {
    switch (m) {
      case 'FULL_MATCH': return Colors.green;
      case 'PARTIAL_MATCH': return Colors.blue;
      case 'PRICE_MISMATCH': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService, currentIndex: 1, onIndexChanged: (_) {},
      title: 'Purchase Invoices',
      body: Column(children: [
        // Status filter + create
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  labelText: 'Status Filter', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'DRAFT', child: Text('Draft', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'MATCHED', child: Text('Matched', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'PARTIALLY_POSTED', child: Text('Partially Posted', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'POSTED', child: Text('Posted', style: TextStyle(fontSize: 12))),
                  const DropdownMenuItem(value: 'BLOCKED', child: Text('Blocked', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) { _statusFilter = v; _load(); },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InvoiceFormScreen(authService: widget.authService, purchaseService: widget.purchaseService)));
                _load();
              }, tooltip: 'New Invoice'),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ]),
        ),
        const Divider(height: 1),
        // Column headers
        if (_invoices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey.shade100,
            child: Row(children: [
              const Expanded(flex: 2, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Vendor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('PO', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Amount', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Match', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Status', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _invoices.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No invoices', style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        itemCount: _invoices.length,
                        itemBuilder: (context, i) => _buildRow(_invoices[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildRow(PurchaseInvoiceModel inv) {
    final mColor = _matchColor(inv.matchStatus);
    final sColor = _statusColor(inv.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(inv.invoiceDate.length >= 10 ? inv.invoiceDate.substring(0, 10) : '',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
        Expanded(flex: 2, child: Text(inv.vendorName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(inv.poNumber, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade600))),
        Expanded(flex: 1, child: Text('\$${inv.totalAmount.toStringAsFixed(2)}', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700))),
        Expanded(flex: 1, child: _badge(inv.matchStatus, mColor)),
        Expanded(flex: 1, child: _badge(inv.status, sColor)),
      ]),
    );
  }

  Widget _badge(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
      child: Text(label.replaceAll('_', ' '), textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
