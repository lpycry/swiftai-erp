import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/invoice_form_screen.dart';

class InvoiceOverviewScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const InvoiceOverviewScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });

  @override
  State<InvoiceOverviewScreen> createState() => _InvoiceOverviewScreenState();
}

class _InvoiceOverviewScreenState extends State<InvoiceOverviewScreen> {
  List<PurchaseOrderModel> _pos = [];
  bool _loading = true;
  String? _error;
  String? _vendorFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _pos = await widget.purchaseService.listPendingInvoicePOs();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Set<String> get _vendors => _pos
      .map((p) => p.vendorName.isNotEmpty ? p.vendorName : p.vendorCode)
      .toSet();

  List<PurchaseOrderModel> get _filtered {
    var list = _pos;
    if (_vendorFilter != null && _vendorFilter!.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.vendorName.contains(_vendorFilter!) ||
                p.vendorCode.contains(_vendorFilter!),
          )
          .toList();
    }
    return list;
  }

  double _openAmount(PurchaseOrderModel po) {
    double open = 0;
    for (final item in po.items) {
      final openQty = item.receivedQuantity - item.invoicedQuantity;
      if (openQty > 0) {
        open += openQty * item.unitPrice;
      }
    }
    return open;
  }

  double _receivedAmount(PurchaseOrderModel po) {
    double recv = 0;
    for (final item in po.items) {
      recv += item.receivedQuantity * item.unitPrice;
    }
    return recv;
  }

  double _totalPercentage(double receivedAmount, double openAmount) {
    if (receivedAmount <= 0) return 0;
    final invoicedAmount = receivedAmount - openAmount;
    return (invoicedAmount / receivedAmount) * 100;
  }

  String _fmtDate(String d) {
    if (d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return Fmt.dateStr(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uninvoiced Goods Receipt'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          if (!_loading && _error == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${filtered.length} PO(s) pending invoice',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Open: \$${PurchaseService.fmtAmount(filtered.fold<double>(0.0, (s, p) => s + _openAmount(p)))}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Vendor filter
          if (!_loading && _vendors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All', style: TextStyle(fontSize: 11)),
                      selected: _vendorFilter == null,
                      onSelected: (_) {
                        setState(() => _vendorFilter = null);
                      },
                      visualDensity: VisualDensity.compact,
                      selectedColor: Colors.blue.withValues(alpha: 0.15),
                    ),
                  ),
                  ..._vendors.map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          v,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _vendorFilter == v,
                        onSelected: (_) {
                          setState(() => _vendorFilter = v);
                        },
                        visualDensity: VisualDensity.compact,
                        selectedColor: Colors.blue.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Column headers
          if (filtered.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'PO #',
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
                    flex: 1,
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Open',
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
                      'Progress',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'All POs invoiced!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No POs pending invoice',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _buildRow(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(PurchaseOrderModel po) {
    final openAmt = _openAmount(po);
    final recvAmt = _receivedAmount(po);
    final pct = _totalPercentage(recvAmt, openAmt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: InkWell(
        onTap: () async {
          // Navigate to PO detail
          final fullPO = await widget.purchaseService.getPO(po.id);
          if (mounted) {
            final created = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PODetailQuickView(
                  po: fullPO,
                  openAmount: openAmt,
                  purchaseService: widget.purchaseService,
                  authService: widget.authService,
                ),
              ),
            );
            if (created == true) _load();
          }
        },
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                po.poNumber,
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
                po.vendorName.isNotEmpty ? po.vendorName : po.vendorCode,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _fmtDate(po.poDate),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '\$${PurchaseService.fmtAmount(openAmt)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: openAmt > 0
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: SizedBox(
                  width: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 100
                            ? Colors.green
                            : pct > 50
                            ? Colors.orange
                            : Colors.red,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick PO detail view with invoice creation link
class _PODetailQuickView extends StatelessWidget {
  final PurchaseOrderModel po;
  final double openAmount;
  final PurchaseService purchaseService;
  final AuthService authService;

  const _PODetailQuickView({
    required this.po,
    required this.openAmount,
    required this.purchaseService,
    required this.authService,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.blue;
      case 'CONFIRMED':
        return Colors.indigo;
      case 'RECEIVED':
        return Colors.teal;
      case 'INVOICED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  String _fmtDate(String d) {
    if (d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return Fmt.dateStr(d);
    }
  }

  double _itemOpenAmt(dynamic item) {
    final openQty = item.receivedQuantity - item.invoicedQuantity;
    return openQty > 0 ? openQty * item.unitPrice : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(po.poNumber),
        actions: [
          if (openAmount > 0)
            TextButton.icon(
              icon: const Icon(Icons.post_add, size: 18),
              label: const Text('Create Invoice'),
              onPressed: () async {
                // Build prefill data from this PO
                final prefillItems = po.items
                    .where(
                      (item) => item.receivedQuantity > item.invoicedQuantity,
                    )
                    .map(
                      (item) => {
                        'item_id': item.itemId,
                        'po_item_id': item.id,
                        'item_sku': item.itemSku,
                        'item_name': item.itemName,
                        'unit_price': item.unitPrice,
                        'open_qty':
                            item.receivedQuantity - item.invoicedQuantity,
                        'received_quantity': item.receivedQuantity,
                        'invoiced_quantity': item.invoicedQuantity,
                        'po_quantity': item.quantity,
                        'unit_of_measure': item.unitOfMeasure,
                      },
                    )
                    .toList();
                final prefillData = {
                  'po_id': po.id,
                  'po_number': po.poNumber,
                  'vendor_id': po.vendorId,
                  'vendor_name': po.vendorName,
                  'vendor_code': po.vendorCode,
                  'items': prefillItems,
                  'total_amount': openAmount,
                };
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceFormScreen(
                      authService: authService,
                      purchaseService: purchaseService,
                      prefillData: prefillData,
                    ),
                  ),
                );
                if (result != null && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          po.poNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            po.status,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          po.status,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _statusColor(po.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _infoRow(
                    'Vendor',
                    po.vendorName.isNotEmpty ? po.vendorName : po.vendorCode,
                  ),
                  _infoRow('Date', _fmtDate(po.poDate)),
                  _infoRow('Currency', po.currency),
                  _infoRow(
                    'Total PO',
                    '\$${PurchaseService.fmtAmount(po.totalAmount)}',
                  ),
                  _infoRow(
                    'Open to Invoice',
                    '\$${PurchaseService.fmtAmount(openAmount)}',
                    valueColor: Colors.orange.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Items Pending Invoice',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...po.items
              .where((item) => item.receivedQuantity > item.invoicedQuantity)
              .map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.itemSku} - ${item.itemName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '\$${PurchaseService.fmtAmount(item.unitPrice)}/${item.unitOfMeasure}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Received: ${_fmtQty(item.receivedQuantity)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Invoiced: ${_fmtQty(item.invoicedQuantity)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Open: ${_fmtQty(item.receivedQuantity - item.invoicedQuantity)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open Amount: \$${PurchaseService.fmtAmount(_itemOpenAmt(item))}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
