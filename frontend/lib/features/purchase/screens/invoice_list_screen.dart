import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_form_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const InvoiceListScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });
  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<PurchaseInvoiceModel> _invoices = [];
  bool _loading = false;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _invoices = await widget.purchaseService.listInvoices();
      if (_statusFilter != null) {
        _invoices = _invoices.where((i) => i.status == _statusFilter).toList();
      }
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.grey;
      case 'MATCHED':
        return Colors.teal;
      case 'PARTIALLY_POSTED':
        return Colors.blue;
      case 'POSTED':
        return Colors.green;
      case 'BLOCKED':
        return Colors.red;
      case 'REJECTED':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  Color _matchColor(String m) {
    switch (m) {
      case 'FULL_MATCH':
        return Colors.green;
      case 'PARTIAL_MATCH':
        return Colors.blue;
      case 'PRICE_MISMATCH':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool _canPost(PurchaseInvoiceModel inv) {
    return inv.status != 'POSTED' &&
        inv.status != 'CLEARED' &&
        inv.matchStatus != 'PRICE_MISMATCH' &&
        inv.matchStatus != '';
  }

  Future<void> _postInvoice(PurchaseInvoiceModel inv) async {
    try {
      await widget.purchaseService.postInvoice(inv.id);
      _msg('Invoice ${inv.invoiceNumber} posted to GL');
      _load();
    } catch (e) {
      _msg('$e', isError: true);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Purchase Invoices',
      body: Column(
        children: [
          // Status filter + create
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Status Filter',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All', style: TextStyle(fontSize: 12)),
                      ),
                      const DropdownMenuItem(
                        value: 'DRAFT',
                        child: Text('Draft', style: TextStyle(fontSize: 12)),
                      ),
                      const DropdownMenuItem(
                        value: 'MATCHED',
                        child: Text('Matched', style: TextStyle(fontSize: 12)),
                      ),
                      const DropdownMenuItem(
                        value: 'PARTIALLY_POSTED',
                        child: Text(
                          'Partially Posted',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'POSTED',
                        child: Text('Posted', style: TextStyle(fontSize: 12)),
                      ),
                      const DropdownMenuItem(
                        value: 'BLOCKED',
                        child: Text('Blocked', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (v) {
                      _statusFilter = v;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceFormScreen(
                          authService: widget.authService,
                          purchaseService: widget.purchaseService,
                        ),
                      ),
                    );
                    _load();
                  },
                  tooltip: 'New Invoice',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
          ),
          const Divider(height: 1),
          // Column headers
          if (_invoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Vendor',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'PO',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Amount',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Match',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Status',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      'Post',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No invoices',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: _invoices.length,
                      itemBuilder: (context, i) => _buildRow(_invoices[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _canCancel(PurchaseInvoiceModel inv) {
    return inv.status != 'CANCELLED' && inv.status != 'REJECTED';
  }

  Future<void> _cancelInvoice(PurchaseInvoiceModel inv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Text(
          'Cancel invoice "${inv.invoiceNumber}" for \$${inv.totalAmount.toStringAsFixed(2)}?\n\nThis will reverse the GL entry and restore PO invoiced quantities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.purchaseService.cancelInvoice(inv.id);
      _msg('Invoice ${inv.invoiceNumber} cancelled and GL reversed');
      _load();
    } catch (e) {
      _msg('$e', isError: true);
    }
  }

  Widget _buildRow(PurchaseInvoiceModel inv) {
    final mColor = _matchColor(inv.matchStatus);
    final sColor = _statusColor(inv.status);
    final canPost = _canPost(inv);
    final canCancel = _canCancel(inv);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              inv.invoiceNumber,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Fmt.dateStr(inv.invoiceDate),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              inv.vendorName,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              inv.poNumber,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '\$${inv.totalAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(flex: 1, child: _badge(inv.matchStatus, mColor)),
          Expanded(flex: 1, child: _badge(inv.status, sColor)),
          SizedBox(
            width: 52,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPost)
                  IconButton(
                    icon: Icon(
                      Icons.post_add,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    onPressed: () => _postInvoice(inv),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    tooltip: 'Post to GL',
                  ),
                if (canCancel)
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _cancelInvoice(inv),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    tooltip: 'Cancel Invoice',
                  ),
                if (!canPost && !canCancel && inv.status == 'POSTED')
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade400,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
