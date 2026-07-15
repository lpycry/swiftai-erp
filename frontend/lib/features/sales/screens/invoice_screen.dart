import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:intl/intl.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class SalesInvoiceScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;

  const SalesInvoiceScreen({
    super.key,
    required this.authService,
    required this.salesService,
  });

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  late Future<void> _loadFuture;
  List<dynamic> _pending = [];
  List<dynamic> _invoices = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.salesService.listPendingInvoiceDeliveries(),
      widget.salesService.listSalesInvoices(),
    ]);
    if (!mounted) return;
    setState(() {
      _pending = results[0];
      _invoices = results[1];
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openCreateInvoiceDialog(Map<String, dynamic> delivery) async {
    final items = ((delivery['items'] as List<dynamic>?) ?? [])
        .where(
          (item) =>
              _toDouble(item['open_billing_qty'] ?? item['delivery_qty']) > 0,
        )
        .toList();
    if (items.isEmpty) {
      _snack('This delivery is fully billed');
      return;
    }
    var invoiceDate = DateTime.now();
    final selected = <String, bool>{};
    final qtyCtrls = <String, TextEditingController>{};
    for (final item in items) {
      final id = item['id'].toString();
      selected[id] = true;
      qtyCtrls[id] = TextEditingController(
        text: _num(item['open_billing_qty'] ?? item['delivery_qty']),
      );
    }
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dateText = Fmt.d(invoiceDate);
          return AlertDialog(
            title: Text('Create Invoice - ${delivery['delivery_no']}'),
            content: SizedBox(
              width: 860,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _kv('Customer', delivery['customer_name']),
                        ),
                        Expanded(
                          child: _kv('Sales Order', delivery['so_number']),
                        ),
                        Expanded(
                          child: _kv('Currency', delivery['currency'] ?? 'USD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text('Billing Date  $dateText'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: invoiceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => invoiceDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Bill')),
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Material')),
                          DataColumn(label: Text('PGI Qty')),
                          DataColumn(label: Text('Billed')),
                          DataColumn(label: Text('Open')),
                          DataColumn(label: Text('Billing Qty')),
                          DataColumn(label: Text('UOM')),
                        ],
                        rows: items.map((item) {
                          final id = item['id'].toString();
                          final openQty = _toDouble(
                            item['open_billing_qty'] ?? item['delivery_qty'],
                          );
                          return DataRow(
                            selected: selected[id] ?? false,
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: selected[id] ?? false,
                                  onChanged: (value) => setDialogState(
                                    () => selected[id] = value ?? false,
                                  ),
                                ),
                              ),
                              DataCell(Text(item['item_no'].toString())),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    '${item['sku_code'] ?? ''} ${item['goods_name'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(_num(item['delivery_qty']))),
                              DataCell(Text(_num(item['billed_qty']))),
                              DataCell(Text(_num(openQty))),
                              DataCell(
                                SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: qtyCtrls[id],
                                    enabled: selected[id] ?? false,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item['unit_of_measure']?.toString() ?? 'EA',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Save & Post'),
                onPressed: _busy
                    ? null
                    : () async {
                        final reqItems = <Map<String, dynamic>>[];
                        for (final item in items) {
                          final id = item['id'].toString();
                          if (selected[id] != true) continue;
                          final qty = _toDouble(qtyCtrls[id]?.text);
                          final openQty = _toDouble(
                            item['open_billing_qty'] ?? item['delivery_qty'],
                          );
                          if (qty <= 0 || qty > openQty) {
                            _snack(
                              'Billing qty for item ${item['item_no']} must be > 0 and <= open qty',
                            );
                            return;
                          }
                          reqItems.add({
                            'delivery_item_id': id,
                            'billing_qty': qty,
                          });
                        }
                        if (reqItems.isEmpty) {
                          _snack('Please select at least one item');
                          return;
                        }
                        Navigator.pop(dialogContext);
                        await _createInvoice(
                          delivery,
                          DateFormat('yyyy-MM-dd').format(invoiceDate),
                          reqItems,
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
    for (final ctrl in qtyCtrls.values) {
      ctrl.dispose();
    }
  }

  Future<void> _createInvoice(
    Map<String, dynamic> delivery,
    String invoiceDate,
    List<Map<String, dynamic>> items,
  ) async {
    setState(() => _busy = true);
    try {
      final inv = await widget.salesService.createSalesInvoice({
        'delivery_id': delivery['id'],
        'invoice_date': invoiceDate,
        'post_immediately': true,
        'items': items,
      });
      _snack('Invoice ${inv['invoice_no']} posted');
      await _load();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewInvoice(Map<String, dynamic> row) async {
    final inv = await widget.salesService.getSalesInvoice(row['id'].toString());
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(inv['invoice_no']?.toString() ?? 'Invoice'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Customer', inv['customer_name']),
                _kv('Sales Order', inv['so_number']),
                _kv('Delivery', inv['delivery_no']),
                _kv('Status', inv['status']),
                _kv('Journal Entry', _journalEntryText(inv)),
                const SizedBox(height: 16),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Material')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Net')),
                    DataColumn(label: Text('Tax')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: ((inv['items'] as List<dynamic>?) ?? []).map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item['item_no'].toString())),
                        DataCell(Text(item['sku_code']?.toString() ?? '')),
                        DataCell(Text(_num(item['quantity']))),
                        DataCell(Text(_money(item['net_amount']))),
                        DataCell(Text(_money(item['tax_amount']))),
                        DataCell(Text(_money(item['line_total']))),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _viewInvoiceJournal(inv);
            },
            icon: const Icon(Icons.article_outlined, size: 18),
            label: const Text('View Journal Entry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewInvoiceJournal(Map<String, dynamic> invoice) async {
    try {
      var journalId = invoice['journal_entry_id']?.toString() ?? '';
      if (journalId.isEmpty && invoice['id'] != null) {
        final fresh = await widget.salesService.getSalesInvoice(
          invoice['id'].toString(),
        );
        journalId = fresh['journal_entry_id']?.toString() ?? '';
        invoice = fresh;
      }

      Map<String, dynamic>? detail;
      if (journalId.isNotEmpty) {
        detail = await widget.salesService.getJournalEntry(journalId);
      } else {
        final invoiceNo = invoice['invoice_no']?.toString() ?? '';
        final matches = await widget.salesService.listJournalEntries(
          status: 'posted',
          query: invoiceNo,
          pageSize: 10,
        );
        final header = matches.cast<dynamic>().firstWhere(
          (e) => e is Map && e['reference']?.toString() == invoiceNo,
          orElse: () => matches.isNotEmpty ? matches.first : null,
        );
        if (header != null) {
          detail = await widget.salesService.getJournalEntry(
            (header as Map)['id'].toString(),
          );
        }
      }

      if (detail == null || detail.isEmpty) {
        _snack('No posted journal entry found for this invoice');
        return;
      }
      if (!mounted) return;
      await _showJournalDialog(Map<String, dynamic>.from(detail));
    } catch (e) {
      _snack(e.toString());
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
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _journalRow('Description', entry['description']),
                _journalRow(
                  'Posting Date',
                  Fmt.dateStr(entry['posting_date']?.toString()),
                ),
                _journalRow(
                  'Document Date',
                  Fmt.dateStr(entry['document_date']?.toString()),
                ),
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
                        color: Colors.grey.shade100,
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

  Widget _journalRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
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
              value?.toString() ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _num(dynamic value) =>
      ((num.tryParse(value?.toString() ?? '') ?? 0).toDouble()).toStringAsFixed(
        2,
      );
  double _toDouble(dynamic value) =>
      (num.tryParse(value?.toString() ?? '') ?? 0).toDouble();
  String _money(dynamic value) => '\$${_num(value)}';
  String _moneyOrBlank(dynamic value) {
    final amount = (num.tryParse(value?.toString() ?? '') ?? 0).toDouble();
    return amount == 0 ? '' : _money(amount);
  }

  String _journalEntryText(Map<String, dynamic> inv) {
    final documentNo = inv['journal_entry_no']?.toString() ?? '';
    final description = inv['journal_entry_description']?.toString() ?? '';
    if (documentNo.isNotEmpty && description.isNotEmpty) {
      return '$documentNo - $description';
    }
    if (description.isNotEmpty) return description;
    if (documentNo.isNotEmpty) return documentNo;
    return inv['journal_entry_id']?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 4,
      onIndexChanged: (_) {},
      title: 'Sales Invoices',
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Invoices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _loadFuture = _load()),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _section('Pending Billing Deliveries'),
                const SizedBox(height: 8),
                if (_pending.isEmpty)
                  const ListTile(
                    title: Text(
                      'No PGI deliveries waiting for invoice. Already invoiced deliveries are shown in Invoice History.',
                    ),
                  ),
                ..._pending.map(
                  (dn) => ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(
                      '${dn['delivery_no']}  ${dn['customer_name'] ?? ''}',
                    ),
                    subtitle: Text('SO ${dn['so_number']}  ${dn['status']}'),
                    trailing: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _openCreateInvoiceDialog(dn),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Create VF01'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _section('Invoice History'),
                const SizedBox(height: 8),
                ..._invoices.map(
                  (inv) => ListTile(
                    leading: Icon(
                      inv['status'] == 'POSTED'
                          ? Icons.check_circle
                          : Icons.receipt_long,
                      color: inv['status'] == 'POSTED'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      '${inv['invoice_no']}  ${inv['customer_name'] ?? ''}',
                    ),
                    subtitle: Text(
                      'Delivery ${inv['delivery_no'] ?? '-'}  SO ${inv['so_number'] ?? '-'}  ${inv['currency'] ?? 'USD'} ${_num(inv['total_amount'])}  ${inv['status']}  JE ${_journalEntryText(inv)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'View Invoice',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _viewInvoice(inv),
                        ),
                        IconButton(
                          tooltip: 'View Journal Entry',
                          icon: const Icon(Icons.article_outlined),
                          onPressed: () => _viewInvoiceJournal(
                            Map<String, dynamic>.from(inv as Map),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
      ),
    );
  }
}
