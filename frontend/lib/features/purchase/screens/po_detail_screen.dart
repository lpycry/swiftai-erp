import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class PODetailScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  final PurchaseOrderModel po;
  const PODetailScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
    required this.po,
  });

  @override
  State<PODetailScreen> createState() => _PODetailScreenState();
}

class _PODetailScreenState extends State<PODetailScreen> {
  late PurchaseOrderModel _po;
  bool _loading = false;
  List<Map<String, dynamic>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _po = widget.po;
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    try {
      _attachments = await widget.purchaseService.listPOAttachments(_po.id);
    } catch (_) {}
    if (mounted) setState(() {});
  }

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

  Future<void> _updateStatus(String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Status'),
        content: Text('Change status to $newStatus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await widget.purchaseService.updatePOStatus(_po.id, newStatus);
      final updated = await widget.purchaseService.getPO(_po.id);
      setState(() => _po = updated);
      _snack('Status updated to $newStatus', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadAttachment() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final file in result.files) {
      try {
        await widget.purchaseService.uploadPOAttachment(
          _po.id,
          file.path!,
          file.name,
        );
      } catch (e) {
        _snack('Upload failed: $e', Colors.red);
      }
    }
    _snack('${result.files.length} file(s) uploaded', Colors.green);
    _loadAttachments();
  }

  Future<void> _printPO() async {
    final po = _po;
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text('PO #: ${po.poNumber}', style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Company: ${po.orgCode.isNotEmpty ? '$po.orgCode - $po.orgName' : '-'}',
                    ),
                    pw.Text('Date: ${_formatDate(po.poDate)}'),
                    pw.Text('Status: ${po.status}'),
                    if (po.paymentTermCode.isNotEmpty)
                      pw.Text('Pay Terms: ${po.paymentTermCode}'),
                    if (po.incotermCode.isNotEmpty)
                      pw.Text('Incoterm: ${po.incotermCode}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Vendor: ${po.vendorName.isNotEmpty ? po.vendorName : po.vendorCode}',
                    ),
                    pw.Text('Currency: ${po.currency}'),
                  ],
                ),
              ],
            ),
            if (po.deliveryAddress.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Delivery: ${po.deliveryAddress}'),
            ],
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9),
              headers: ['#', 'Item', 'Qty', 'UOM', 'Price', 'Total'],
              data: po.items
                  .asMap()
                  .entries
                  .map(
                    (e) => [
                      '${e.key + 1}',
                      '${e.value.itemSku} ${e.value.itemName}'.trim(),
                      _fmtQty(e.value.quantity),
                      e.value.unitOfMeasure,
                      '\$${PurchaseService.fmtAmount(e.value.unitPrice)}',
                      '\$${PurchaseService.fmtAmount(e.value.lineTotal)}',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: ${po.currency} ${PurchaseService.fmtAmount(po.totalAmount)}',
                style: pw.TextStyle(fontSize: 14),
              ),
            ),
            if (po.notes.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Notes: ${po.notes}'),
            ],
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'PO_${po.poNumber}.pdf',
    );
  }

  List<String> _availableActions() {
    switch (_po.status) {
      case 'DRAFT':
        return ['CONFIRMED', 'CANCELLED'];
      case 'CONFIRMED':
        return ['CANCELLED'];
      default:
        return [];
    }
  }

  void _snack(String msg, Color color) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final actions = _availableActions();

    return Scaffold(
      appBar: AppBar(
        title: Text(po.poNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print/Save PDF',
            onPressed: _printPO,
          ),
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'Upload attachments',
            onPressed: _uploadAttachment,
          ),
          ...actions.map(
            (a) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: _statusColor(a)),
                onPressed: _loading ? null : () => _updateStatus(a),
                child: Text(a),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  po.status,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
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
                          'Company',
                          po.orgCode.isNotEmpty
                              ? '$po.orgCode - $po.orgName'
                              : '-',
                        ),
                        _infoRow('PO Date', _formatDate(po.poDate)),
                        _infoRow(
                          'Vendor',
                          po.vendorName.isNotEmpty
                              ? po.vendorName
                              : po.vendorCode,
                        ),
                        _infoRow('Currency', po.currency),
                        if (po.paymentTermCode.isNotEmpty)
                          _infoRow('Pay Terms', po.paymentTermCode),
                        if (po.incotermCode.isNotEmpty)
                          _infoRow('Incoterm', po.incotermCode),
                        if (po.deliveryAddress.isNotEmpty)
                          _infoRow('Delivery Address', po.deliveryAddress),
                        if (po.notes.isNotEmpty) _infoRow('Notes', po.notes),
                        _infoRow(
                          'Total',
                          '${po.currency} ${PurchaseService.fmtAmount(po.totalAmount)}',
                        ),
                        _infoRow('Created', _formatDate(po.createdAt)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Attachments
                if (_attachments.isNotEmpty) ...[
                  const Text(
                    'Attachments',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._attachments.map(
                    (att) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.attachment, size: 18),
                      title: Text(
                        att['file_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        _fmtSize((att['file_size'] as num?)?.toInt() ?? 0),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Line Items
                const Text(
                  'Line Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...po.items.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
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
                                  ),
                                ),
                              ),
                              Text(
                                '${po.currency} ${PurchaseService.fmtAmount(item.unitPrice)}/${item.unitOfMeasure}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Ordered: ${_fmtQty(item.quantity)} ${item.unitOfMeasure}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Received: ${_fmtQty(item.receivedQuantity)} ${item.unitOfMeasure}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Line Total: ${PurchaseService.fmtAmount(item.lineTotal)}',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (item.expectedDeliveryDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Expected: ${_formatDate(item.expectedDeliveryDate!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (item.deliveryAddress.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Deliver to: ${item.deliveryAddress}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  String _formatDate(String d) {
    if (d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return Fmt.dateStr(d);
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
