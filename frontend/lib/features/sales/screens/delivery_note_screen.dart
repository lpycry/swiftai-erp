import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class DeliveryNoteScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;

  const DeliveryNoteScreen({
    super.key,
    required this.authService,
    required this.salesService,
  });

  @override
  State<DeliveryNoteScreen> createState() => _DeliveryNoteScreenState();
}

class _DeliveryNoteScreenState extends State<DeliveryNoteScreen> {
  bool _loading = true;
  bool _saving = false;
  String _status = '';
  String? _warehouseId;
  String? _selectedSoNumber;
  Map<String, dynamic>? _selectedSODetail;
  bool _loadingSODetail = false;
  DateTime _selectionDate = DateTime.now().add(const Duration(days: 2));
  List<dynamic> _warehouses = [];
  List<dynamic> _confirmedSalesOrders = [];
  final Map<String, Map<String, dynamic>> _soDetailCache = {};
  List<dynamic> _deliveries = [];
  final Set<String> _selectedSOItemIds = {};
  final Map<String, TextEditingController> _deliveryQtyCtrls = {};
  final ScrollController _deliveryItemsScrollCtrl = ScrollController();
  final ScrollController _selectedSOItemsScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _deliveryQtyCtrls.values) {
      ctrl.dispose();
    }
    _deliveryItemsScrollCtrl.dispose();
    _selectedSOItemsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.salesService.listWarehouses(),
        widget.salesService.listSalesOrders(),
        widget.salesService.listDeliveryNotes(status: _status),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0];
        _confirmedSalesOrders = results[1].where((raw) {
          final so = Map<String, dynamic>.from(raw as Map);
          final status = so['status']?.toString().toUpperCase() ?? '';
          if (status != 'CONFIRMED' && status != 'PARTIALLY_DELIVERED') {
            return false;
          }
          if ((so['items'] as List<dynamic>? ?? []).isNotEmpty) {
            return _hasOpenDeliveryItem(so);
          }
          final soNumber = so['so_number']?.toString() ?? '';
          final cached = _soDetailCache[soNumber];
          if (cached == null) return true;
          return _hasOpenDeliveryItem(cached);
        }).toList();
        _deliveries = results[2];
        _warehouseId ??= _warehouses.isNotEmpty
            ? _warehouses.first['id']?.toString()
            : null;
        if (_selectedSoNumber != null &&
            !_confirmedSalesOrders.any(
              (so) => so['so_number']?.toString() == _selectedSoNumber,
            )) {
          _selectedSoNumber = null;
          _clearSOItemSelection();
        }
      });
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickSelectionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectionDate = picked);
  }

  Future<void> _createDelivery() async {
    if (_warehouseId == null || _selectedSoNumber == null) {
      _snack('Warehouse and confirmed sales order are required', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final items = _buildSelectedDeliveryItems();
      if (items.isEmpty) {
        _snack('Please select at least one sales order item', isError: true);
        return;
      }
      final dn = await widget.salesService.createDeliveryNote({
        'warehouse_id': _warehouseId,
        'selection_date': _apiDate(_selectionDate),
        'reference_no': _selectedSoNumber,
        'items': items,
      });
      _selectedSoNumber = null;
      _selectedSODetail = null;
      _clearSOItemSelection();
      await _load();
      _snack('Created ${dn['delivery_no'] ?? ''}');
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _buildSelectedDeliveryItems() {
    final rows = (_selectedSODetail?['items'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final selected = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (!_selectedSOItemIds.contains(id)) continue;
      final qty = double.tryParse(_deliveryQtyCtrls[id]?.text ?? '') ?? 0;
      final openQty = _num(row['open_delivery_qty']);
      if (qty <= 0) {
        _snack('Delivery qty must be greater than zero', isError: true);
        return [];
      }
      if (qty > openQty) {
        _snack(
          'Line ${row['line_no']} delivery qty exceeds open qty',
          isError: true,
        );
        return [];
      }
      selected.add({'so_item_id': id, 'delivery_qty': qty});
    }
    return selected;
  }

  Future<void> _selectSalesOrder(String? soNumber) async {
    setState(() {
      _selectedSoNumber = soNumber;
      _selectedSODetail = null;
      _loadingSODetail = soNumber != null;
      _clearSOItemSelection();
    });
    if (soNumber == null) return;
    final selected = _selectedSO;
    final soID = selected?['id']?.toString() ?? '';
    if (soID.isEmpty) {
      setState(() => _loadingSODetail = false);
      return;
    }
    try {
      final detail = await widget.salesService.getSalesOrder(soID);
      if (!mounted) return;
      _soDetailCache[soNumber] = detail;
      if (!_hasOpenDeliveryItem(detail)) {
        setState(() {
          _selectedSoNumber = null;
          _selectedSODetail = null;
          _loadingSODetail = false;
          _clearSOItemSelection();
        });
        _snack('This sales order is fully delivered', isError: true);
        await _load();
        return;
      }
      _populateSOItems(detail);
      setState(() {
        _selectedSODetail = detail;
        _loadingSODetail = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSODetail = false);
        _snack('$e', isError: true);
      }
    }
  }

  bool _hasOpenDeliveryItem(Map<String, dynamic> order) {
    for (final raw in (order['items'] as List<dynamic>? ?? [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (_num(item['open_delivery_qty']) > 0) return true;
    }
    return false;
  }

  void _populateSOItems(Map<String, dynamic> detail) {
    _clearSOItemSelection();
    for (final raw in (detail['items'] as List<dynamic>? ?? [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final openQty = _num(item['open_delivery_qty']);
      _deliveryQtyCtrls[id] = TextEditingController(text: _fmt(openQty));
    }
  }

  void _clearSOItemSelection() {
    for (final ctrl in _deliveryQtyCtrls.values) {
      ctrl.dispose();
    }
    _deliveryQtyCtrls.clear();
    _selectedSOItemIds.clear();
  }

  Future<void> _deleteDelivery(Map<String, dynamic> row) async {
    final deliveryNo = row['delivery_no']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery Note'),
        content: Text(
          'Delete $deliveryNo? This is allowed only before any picked qty is entered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.salesService.deleteDeliveryNote(row['id'].toString());
      await _load();
      _snack('Deleted $deliveryNo');
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    var dn = await widget.salesService.getDeliveryNote(row['id'].toString());
    if (!mounted) return;
    final picked = <String, TextEditingController>{};
    for (final raw in (dn['items'] as List<dynamic>? ?? [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      picked[item['id'].toString()] = TextEditingController(
        text: _fmt(item['picked_qty']),
      );
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final dialogWidth = (MediaQuery.sizeOf(ctx).width - 96).clamp(
            640.0,
            980.0,
          );
          return AlertDialog(
            title: Text('${dn['delivery_no']}  ${dn['status']}'),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _kv('SO', dn['so_number']),
                        _kv('Customer', dn['customer_name']),
                        _kv(
                          'Warehouse',
                          '${dn['warehouse_code'] ?? ''} - ${dn['warehouse_name'] ?? ''}',
                        ),
                        _kv('Ship-to', dn['ship_to_address']),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Scrollbar(
                      controller: _deliveryItemsScrollCtrl,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _deliveryItemsScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 860),
                          child: DataTable(
                            columnSpacing: 18,
                            horizontalMargin: 12,
                            headingRowHeight: 34,
                            dataRowMinHeight: 54,
                            dataRowMaxHeight: 76,
                            columns: const [
                              DataColumn(label: Text('Item')),
                              DataColumn(label: Text('Material')),
                              DataColumn(label: Text('Order Qty')),
                              DataColumn(label: Text('Delivery Qty')),
                              DataColumn(label: Text('Picked Qty')),
                              DataColumn(label: Text('UOM')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: ((dn['items'] as List<dynamic>? ?? [])).map((
                              raw,
                            ) {
                              final item = Map<String, dynamic>.from(
                                raw as Map,
                              );
                              final id = item['id'].toString();
                              final editable = dn['status'] != 'PGI_POSTED';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 48,
                                      child: Text('${item['item_no'] ?? ''}'),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 250,
                                      child: Text(
                                        '${item['sku_code'] ?? ''} - ${item['goods_name'] ?? ''}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 74,
                                      child: Text(_fmt(item['order_qty'])),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 86,
                                      child: Text(_fmt(item['delivery_qty'])),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 88,
                                      child: TextField(
                                        enabled: editable,
                                        controller: picked[id],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        item['unit_of_measure']?.toString() ??
                                            '',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        item['pgi_status']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print Packing Slip'),
                onPressed: () => _printPackingSlip(dn),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              if (dn['status'] != 'PGI_POSTED')
                TextButton.icon(
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Save Picking'),
                  onPressed: () async {
                    try {
                      dn = await widget.salesService.updateDeliveryPicking(
                        dn['id'].toString(),
                        picked.entries
                            .map(
                              (e) => {
                                'id': e.key,
                                'picked_qty':
                                    double.tryParse(e.value.text) ?? 0,
                              },
                            )
                            .toList(),
                      );
                      setD(() {});
                      await _load();
                    } catch (e) {
                      _snack('$e', isError: true);
                    }
                  },
                ),
              if (dn['status'] != 'PGI_POSTED')
                FilledButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Post PGI'),
                  onPressed: () async {
                    try {
                      await widget.salesService.postDeliveryPGI(
                        dn['id'].toString(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                      _snack('PGI posted');
                    } catch (e) {
                      _snack('$e', isError: true);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
    for (final c in picked.values) {
      c.dispose();
    }
  }

  Future<void> _viewJournalEntry(Map<String, dynamic> row) async {
    final deliveryNo = row['delivery_no']?.toString() ?? '';
    if (deliveryNo.isEmpty) return;
    try {
      final matches = await widget.salesService.listJournalEntries(
        status: 'posted',
        query: deliveryNo,
        pageSize: 10,
      );
      final header = matches.cast<dynamic>().firstWhere(
        (e) => e is Map && e['reference']?.toString() == deliveryNo,
        orElse: () => matches.isNotEmpty ? matches.first : null,
      );
      if (header == null) {
        _snack('No posted journal entry found for $deliveryNo', isError: true);
        return;
      }
      final detail = await widget.salesService.getJournalEntry(
        (header as Map)['id'].toString(),
      );
      if (!mounted) return;
      await _showJournalDialog(Map<String, dynamic>.from(detail));
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _showJournalDialog(Map<String, dynamic> entry) async {
    final lines = (entry['lines'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final status = entry['status']?.toString() ?? '';
    final totalDebit = lines.fold<double>(
      0,
      (sum, line) => sum + ((line['debit'] as num?)?.toDouble() ?? 0),
    );
    final totalCredit = lines.fold<double>(
      0,
      (sum, line) => sum + ((line['credit'] as num?)?.toDouble() ?? 0),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'posted' ? Icons.check_circle : Icons.edit_note,
              color: status == 'posted' ? Colors.green : Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry['document_no']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (status == 'posted' ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: status == 'posted' ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _journalRow('Description', entry['description']),
                _journalRow('Posting Date', _fmtDate(entry['posting_date'])),
                _journalRow('Document Date', _fmtDate(entry['document_date'])),
                _journalRow('Reference', entry['reference']),
                _journalRow('Type', entry['entry_type'] ?? 'normal'),
                if ((entry['organization_name']?.toString() ?? '').isNotEmpty)
                  _journalRow('Company', entry['organization_name']),
                const Divider(height: 16),
                const Text(
                  'Line Items',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Debit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Credit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Description',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...lines.map(
                        (line) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${line['account_code'] ?? ''} ${line['account_name'] ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _moneyOrBlank(line['debit']),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _moneyOrBlank(line['credit']),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  line['description']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _money(totalDebit),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _money(totalCredit),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Expanded(flex: 2, child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _printPackingSlip(Map<String, dynamic> row) async {
    try {
      final dn = row.containsKey('items')
          ? row
          : await widget.salesService.getDeliveryNote(row['id'].toString());
      final doc = _buildPackingSlipPdf(Map<String, dynamic>.from(dn));
      await Printing.layoutPdf(
        name: 'Packing_Slip_${dn['delivery_no'] ?? ''}.pdf',
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  pw.Document _buildPackingSlipPdf(Map<String, dynamic> dn) {
    final doc = pw.Document();
    final items = (dn['items'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final deliveryNo = dn['delivery_no']?.toString() ?? '';
    final soNo = dn['so_number']?.toString() ?? '';
    final customerPoNo = dn['customer_po_no']?.toString() ?? '';
    final companyName = dn['company_name']?.toString() ?? 'SwiftAI ERP';
    final shipTo = [
      dn['ship_to_name']?.toString() ?? dn['customer_name']?.toString() ?? '',
      dn['ship_to_phone']?.toString() ?? '',
      dn['ship_to_address']?.toString() ?? '',
    ].where((v) => v.trim().isNotEmpty).join('\n');
    final warehouseAddress = dn['warehouse_address']?.toString() ?? '';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Packing Slips',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Ship with goods',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfKv('Delivery No.', deliveryNo),
                    _pdfKv('Sales Order', soNo),
                    _pdfKv('Customer PO', customerPoNo),
                    _pdfKv('Date', _fmtDate(dn['selection_date'])),
                    _pdfKv('Status', dn['status']?.toString() ?? ''),
                  ],
                ),
              ),
            ],
          ),
          if (customerPoNo.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer PO Barcode',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: customerPoNo,
                      width: 200,
                      height: 46,
                      drawText: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _pdfBox(
                  'Ship To',
                  shipTo.isEmpty
                      ? dn['customer_name']?.toString() ?? ''
                      : shipTo,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _pdfBox(
                  'Ship From',
                  warehouseAddress.isEmpty ? '-' : warehouseAddress,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _pdfBox(
                  'Shipping Method',
                  dn['shipping_method']?.toString() ?? '-',
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _pdfBox('Route', dn['route']?.toString() ?? '-'),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Items',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(34),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(58),
              4: const pw.FixedColumnWidth(42),
              5: const pw.FixedColumnWidth(74),
            },
            headers: const [
              'Item',
              'Material',
              'Description',
              'Ship Qty',
              'UOM',
              'Bin/Loc Name',
            ],
            data: items
                .map(
                  (item) => [
                    item['item_no']?.toString() ?? '',
                    item['sku_code']?.toString() ?? '',
                    item['goods_name']?.toString() ?? '',
                    _fmt(item['delivery_qty']),
                    item['unit_of_measure']?.toString() ?? '',
                    item['stock_loc']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _signatureBox('Packed By')),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _signatureBox('Checked By')),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _signatureBox('Carrier / Receiver')),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'Print Date and Time: ${_dateTimeText(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Please verify item count and carton condition before shipment. This packing slip contains no pricing information.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _pdfKv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 74,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBox(String title, String value) {
    return pw.Container(
      width: double.infinity,
      constraints: const pw.BoxConstraints(minHeight: 70),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value.isEmpty ? '-' : value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(String label) {
    return pw.Container(
      height: 58,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Container(height: 0.5, color: PdfColors.grey700),
          pw.SizedBox(height: 3),
          pw.Text(
            'Signature / Date',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, dynamic value) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            value?.toString().isEmpty == false ? value.toString() : '-',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _journalRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true ? value.toString() : '-',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) => Fmt.d(d);

  String _dateTimeText(DateTime d) =>
      '${Fmt.d(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDate(dynamic v) {
    final raw = v?.toString() ?? '';
    if (raw.isEmpty) return '';
    return Fmt.dateStr(raw);
  }

  String _fmt(dynamic v) {
    final n = _num(v);
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _money(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  String _moneyOrBlank(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    return n == 0 ? '' : _money(n);
  }

  Map<String, dynamic>? get _selectedSO {
    for (final raw in _confirmedSalesOrders) {
      final so = Map<String, dynamic>.from(raw as Map);
      if (so['so_number']?.toString() == _selectedSoNumber) return so;
    }
    return null;
  }

  String _soLabel(Map<String, dynamic> so) {
    final soNo = so['so_number']?.toString() ?? '';
    final customer = so['customer_name']?.toString() ?? '';
    final date = Fmt.dateStr(so['delivery_date']?.toString());
    final amount = _fmt(so['total_amount']);
    return '$soNo  $customer  $date  USD $amount';
  }

  Widget _buildSelectedSOItemsTable() {
    if (_loadingSODetail) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final items = (_selectedSODetail?['items'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No sales order items found',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        controller: _selectedSOItemsScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: DataTable(
            headingRowHeight: 32,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 60,
            columnSpacing: 18,
            horizontalMargin: 8,
            columns: const [
              DataColumn(label: Text('Select')),
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Material')),
              DataColumn(label: Text('Order Qty')),
              DataColumn(label: Text('Delivered')),
              DataColumn(label: Text('Open')),
              DataColumn(label: Text('Delivery Qty')),
              DataColumn(label: Text('UOM')),
            ],
            rows: items.map((item) {
              final id = item['id']?.toString() ?? '';
              final openQty = _num(item['open_delivery_qty']);
              final selected = _selectedSOItemIds.contains(id);
              return DataRow(
                selected: selected,
                cells: [
                  DataCell(
                    Checkbox(
                      value: selected,
                      onChanged: openQty <= 0
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                _selectedSOItemIds.add(id);
                              } else {
                                _selectedSOItemIds.remove(id);
                              }
                            }),
                    ),
                  ),
                  DataCell(Text('${item['line_no'] ?? ''}')),
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Text(
                        '${item['product_sku'] ?? ''} - ${item['product_name'] ?? item['description'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(_fmt(item['quantity']))),
                  DataCell(Text(_fmt(item['delivered_qty']))),
                  DataCell(Text(_fmt(openQty))),
                  DataCell(
                    SizedBox(
                      width: 96,
                      child: TextField(
                        enabled: selected && openQty > 0,
                        controller: _deliveryQtyCtrls[id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                  ),
                  DataCell(Text(item['unit_of_measure']?.toString() ?? '')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Notes'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        initialValue: _warehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Shipping Point / Warehouse',
                        ),
                        items: _warehouses
                            .map(
                              (w) => DropdownMenuItem<String>(
                                value: w['id']?.toString(),
                                child: Text(
                                  '${w['code'] ?? ''} - ${w['name'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _warehouseId = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 170,
                      child: InkWell(
                        onTap: _pickSelectionDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Selection Date',
                          ),
                          child: Text(_displayDate(_selectionDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSoNumber,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Reference SO Number',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        items: _confirmedSalesOrders
                            .map((raw) {
                              final so = Map<String, dynamic>.from(raw as Map);
                              final soNo = so['so_number']?.toString();
                              if (soNo == null || soNo.isEmpty) return null;
                              return DropdownMenuItem<String>(
                                value: soNo,
                                child: Text(
                                  _soLabel(so),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            })
                            .whereType<DropdownMenuItem<String>>()
                            .toList(),
                        onChanged: _selectSalesOrder,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _createDelivery,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Create'),
                    ),
                  ],
                ),
                if (_selectedSO != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _kv('Selected SO', _selectedSO!['so_number']),
                        _kv('Customer', _selectedSO!['customer_name']),
                        _kv('Status', _selectedSO!['status']),
                        _kv(
                          'Delivery Date',
                          Fmt.dateStr(
                            _selectedSO!['delivery_date']?.toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSelectedSOItemsTable(),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(
                        value: 'CREATED',
                        child: Text('Created'),
                      ),
                      DropdownMenuItem(
                        value: 'PICKING',
                        child: Text('Picking'),
                      ),
                      DropdownMenuItem(value: 'PICKED', child: Text('Picked')),
                      DropdownMenuItem(
                        value: 'PGI_POSTED',
                        child: Text('PGI Posted'),
                      ),
                    ],
                    onChanged: (v) {
                      _status = v ?? '';
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _deliveries.isEmpty
                ? const Center(child: Text('No delivery notes'))
                : ListView.separated(
                    itemCount: _deliveries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final row = Map<String, dynamic>.from(
                        _deliveries[i] as Map,
                      );
                      return ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text('${row['delivery_no']}  ${row['status']}'),
                        subtitle: Text(
                          '${row['so_number']}  ${row['customer_name']}  ${row['warehouse_code']}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () => _open(row),
                            ),
                            IconButton(
                              tooltip: 'View Journal Entry',
                              icon: Icon(
                                Icons.account_balance_outlined,
                                color: row['status'] == 'PGI_POSTED'
                                    ? null
                                    : Colors.grey.shade400,
                              ),
                              onPressed: row['status'] == 'PGI_POSTED'
                                  ? () => _viewJournalEntry(row)
                                  : () => _snack(
                                      'Journal entry is available after PGI is posted',
                                      isError: true,
                                    ),
                            ),
                            IconButton(
                              tooltip: 'Print Packing Slip',
                              icon: const Icon(Icons.print_outlined),
                              onPressed: () => _printPackingSlip(row),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: Icon(
                                Icons.delete_outline,
                                color: row['status'] == 'PGI_POSTED'
                                    ? Colors.grey.shade400
                                    : Colors.red.shade400,
                              ),
                              onPressed: row['status'] == 'PGI_POSTED'
                                  ? () => _snack(
                                      'PGI posted delivery notes cannot be deleted',
                                      isError: true,
                                    )
                                  : () => _deleteDelivery(row),
                            ),
                          ],
                        ),
                        onTap: () => _open(row),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
