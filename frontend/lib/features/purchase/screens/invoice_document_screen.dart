import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class InvoiceDocumentScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  final String? invoiceId;
  final PurchaseInvoiceModel? invoice;

  const InvoiceDocumentScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
    this.invoiceId,
    this.invoice,
  });

  @override
  State<InvoiceDocumentScreen> createState() => _InvoiceDocumentScreenState();
}

class _InvoiceDocumentScreenState extends State<InvoiceDocumentScreen> {
  PurchaseInvoiceModel? _invoice;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  bool _searchMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _invoice = widget.invoice;
      _loading = false;
    } else if (widget.invoiceId != null) {
      _loadInvoice(widget.invoiceId!);
    } else {
      _searchMode = true;
      _loading = false;
    }
  }

  Future<void> _loadInvoice(String id) async {
    setState(() { _loading = true; _error = null; });
    try {
      _invoice = await widget.purchaseService.getInvoice(id);
    } catch (e) {
      _error = '$e';
      _searchMode = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchInvoice() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final invoices = await widget.purchaseService.listInvoices();
      final found = invoices.where((inv) =>
        inv.invoiceNumber.toLowerCase().contains(term.toLowerCase()) ||
        inv.poNumber.toLowerCase().contains(term.toLowerCase()) ||
        inv.vendorName.toLowerCase().contains(term.toLowerCase())
      ).toList();
      if (found.isEmpty) {
        _error = 'No invoice found matching "$term"';
      } else if (found.length == 1) {
        _invoice = await widget.purchaseService.getInvoice(found.first.id);
        _searchMode = false;
      } else {
        // Show selection dialog for multiple matches
        if (mounted) _showMultiMatchDialog(found);
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showMultiMatchDialog(List<PurchaseInvoiceModel> matches) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Invoice'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length,
            itemBuilder: (_, i) {
              final inv = matches[i];
              return ListTile(
                dense: true,
                title: Text(inv.invoiceNumber),
                subtitle: Text('${inv.vendorName} - \$${inv.totalAmount.toStringAsFixed(2)}'),
                trailing: _statusBadge(inv.status),
                onTap: () async {
                  Navigator.pop(ctx);
                  final full = await widget.purchaseService.getInvoice(inv.id);
                  if (mounted) {
                    setState(() {
                      _invoice = full;
                      _searchMode = false;
                    });
                  }
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT': return Colors.grey;
      case 'MATCHED': return Colors.teal;
      case 'PARTIALLY_POSTED': return Colors.blue;
      case 'POSTED': return Colors.green;
      case 'BLOCKED': return Colors.red;
      case 'REJECTED': return Colors.red.shade800;
      case 'CANCELLED': return Colors.red.shade300;
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

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(label).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.replaceAll('_', ' '),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(label))),
    );
  }

  String _fmtDate(String d) {
    if (d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.length > 10 ? d.substring(0, 10) : d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_searchMode ? 'Search Invoice' : 'Invoice Document'),
        actions: [
          if (!_searchMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search another invoice',
              onPressed: () => setState(() { _searchMode = true; _invoice = null; _error = null; }),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_searchMode) return _buildSearchPanel();
    if (_error != null) return _buildError();

    final inv = _invoice!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Invoice header card
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(inv.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                _statusBadge(inv.status),
                if (inv.matchStatus.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _matchColor(inv.matchStatus).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(inv.matchStatus.replaceAll('_', ' '),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _matchColor(inv.matchStatus))),
                  ),
                ],
              ]),
              const Divider(height: 20),
              _infoRow('Invoice Date', _fmtDate(inv.invoiceDate)),
              _infoRow('Vendor', inv.vendorName),
              if (inv.poNumber.isNotEmpty) _infoRow('PO Reference', inv.poNumber),
              _infoRow('Currency', inv.currency),
              _infoRow('Total Amount', '\$${PurchaseService.fmtAmount(inv.totalAmount)}'),
              _infoRow('Tax Amount', '\$${PurchaseService.fmtAmount(inv.taxAmount)}'),
              _infoRow('Net Amount', '\$${PurchaseService.fmtAmount(inv.totalAmount - inv.taxAmount)}'),
              if (inv.notes.isNotEmpty) _infoRow('Notes', inv.notes),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Invoice line items
        const Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (inv.items.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No line items', style: TextStyle(color: Colors.grey.shade500))),
            ),
          )
        else
          ...inv.items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${item.itemSku} - ${item.itemName}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                  Text('${PurchaseService.fmtAmount(item.unitPrice)}/${item.quantity > 0 ? 'ea' : ''}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text('Qty: ${_fmtQty(item.quantity)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  Text('GR Qty: ${_fmtQty(item.grQuantity)}',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade600)),
                  const Spacer(),
                  Text('Total: \$${PurchaseService.fmtAmount(item.lineTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                ]),
                if (item.poUnitPrice > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('PO Price: \$${PurchaseService.fmtAmount(item.poUnitPrice)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 12),
                    if (item.priceDiff != 0)
                      Text('Price Diff: \$${PurchaseService.fmtAmount(item.priceDiff)}',
                          style: TextStyle(fontSize: 11,
                              color: item.priceDiff > 0 ? Colors.red.shade600 : Colors.green.shade600)),
                  ]),
                ],
              ]),
            ),
          )),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Icon(Icons.search_rounded, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Invoice #, PO #, or Vendor name...',
            prefixIcon: const Icon(Icons.receipt_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (_) => _searchInvoice(),
          autofocus: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Search Invoice'),
            onPressed: _searchInvoice,
          ),
        ),
        if (widget.invoiceId != null && _error != null) ...[
          const SizedBox(height: 20),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error: $_error', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Or enter invoice number, PO number, or vendor name above',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Search Invoice'),
            onPressed: () => setState(() => _searchMode = true),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}
