import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import '../../services/gl_service.dart';

class CreditMemoScreen extends StatefulWidget {
  final GlService glService;
  const CreditMemoScreen({super.key, required this.glService});

  @override
  State<CreditMemoScreen> createState() => _CreditMemoScreenState();
}

class _CreditMemoScreenState extends State<CreditMemoScreen> {
  final _descriptionCtrl = TextEditingController();
  final List<_CreditDraftLine> _newCredits = [];
  final Set<String> _selectedCredits = {};
  final Set<String> _selectedInvoices = {};
  final Map<String, TextEditingController> _invoiceCtrls = {};

  List<dynamic> _customers = [];
  List<dynamic> _creditMemos = [];
  List<dynamic> _openInvoices = [];
  String? _customerId;
  String _currency = 'USD';
  String _controlType = 'offset';
  DateTime _postingDate = DateTime.now();
  DateTime _documentDate = DateTime.now();
  bool _allowPartial = true;
  bool _loading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _newCredits.add(_CreditDraftLine());
    _loadCustomers();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    for (final line in _newCredits) {
      line.dispose();
    }
    for (final ctrl in _invoiceCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final customers = await widget.glService.listARCustomers();
      setState(() => _customers = customers);
    } catch (e) {
      _snack('Load customers failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCustomerData() async {
    if (_customerId == null) return;
    setState(() {
      _loading = true;
      _selectedCredits.clear();
      _selectedInvoices.clear();
      for (final ctrl in _invoiceCtrls.values) {
        ctrl.dispose();
      }
      _invoiceCtrls.clear();
    });
    try {
      final results = await Future.wait([
        widget.glService.listAROpenCreditMemos(_customerId!),
        widget.glService.listAROpenInvoices(_customerId!),
      ]);
      setState(() {
        _creditMemos = results[0];
        _openInvoices = results[1];
        for (final inv in _openInvoices) {
          final id = inv['id']?.toString() ?? '';
          _invoiceCtrls[id] = TextEditingController();
        }
      });
    } catch (e) {
      _snack('Load credit memo data failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCustomerChanged(String? id) {
    if (id == null) return;
    dynamic customer;
    for (final c in _customers) {
      if (c['id']?.toString() == id) {
        customer = c;
        break;
      }
    }
    setState(() {
      _customerId = id;
      _currency = customer?['currency']?.toString() ?? 'USD';
    });
    _loadCustomerData();
  }

  double get _newCreditTotal => _round2(
    _newCredits.fold(
      0.0,
      (sum, line) => sum + (double.tryParse(line.amountCtrl.text.trim()) ?? 0),
    ),
  );

  double get _selectedCreditTotal => _round2(
    _creditMemos
        .where((cm) => _selectedCredits.contains(cm['id']?.toString()))
        .fold(0.0, (sum, cm) {
          return sum + ((cm['remaining_amount'] as num?)?.toDouble() ?? 0);
        }),
  );

  double get _creditTotal => _round2(_newCreditTotal + _selectedCreditTotal);

  double get _invoiceApplyTotal => _round2(
    _selectedInvoices.fold(
      0.0,
      (sum, id) =>
          sum + (double.tryParse(_invoiceCtrls[id]?.text.trim() ?? '') ?? 0),
    ),
  );

  double get _netBalance => _round2(_invoiceApplyTotal - _creditTotal);

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool posting) async {
    final initial = posting ? _postingDate : _documentDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (posting) {
        _postingDate = picked;
      } else {
        _documentDate = picked;
      }
    });
  }

  void _addCreditLine() {
    setState(() => _newCredits.add(_CreditDraftLine()));
  }

  void _removeCreditLine(int index) {
    if (_newCredits.length == 1) {
      _newCredits.first.clear();
      setState(() {});
      return;
    }
    final line = _newCredits.removeAt(index);
    line.dispose();
    setState(() {});
  }

  void _autoFillInvoices() {
    var remaining = _creditTotal;
    _selectedInvoices.clear();
    for (final ctrl in _invoiceCtrls.values) {
      ctrl.text = '';
    }
    final sorted = [..._openInvoices.cast<Map<String, dynamic>>()];
    sorted.sort((a, b) {
      final ad =
          DateTime.tryParse(a['invoice_date']?.toString() ?? '') ??
          DateTime(2100);
      final bd =
          DateTime.tryParse(b['invoice_date']?.toString() ?? '') ??
          DateTime(2100);
      return ad.compareTo(bd);
    });
    for (final inv in sorted) {
      if (remaining <= 0.01) break;
      final id = inv['id']?.toString() ?? '';
      final open = (inv['remaining_amount'] as num?)?.toDouble() ?? 0;
      final apply = open < remaining ? open : remaining;
      if (apply > 0) {
        _selectedInvoices.add(id);
        _invoiceCtrls[id]?.text = apply.toStringAsFixed(2);
        remaining = _round2(remaining - apply);
      }
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_customerId == null) {
      _snack('Customer is required', true);
      return;
    }
    final newCredits = _newCredits
        .map((line) {
          final amount = double.tryParse(line.amountCtrl.text.trim()) ?? 0;
          return {
            'reason_code': line.reasonCtrl.text.trim(),
            'amount': amount,
            'description': line.noteCtrl.text.trim(),
          };
        })
        .where((line) => (line['amount'] as double) > 0)
        .toList();
    for (final line in newCredits) {
      if ((line['reason_code'] as String).isEmpty) {
        _snack('Reason code is required for each new credit line', true);
        return;
      }
    }
    if (newCredits.isEmpty && _selectedCredits.isEmpty) {
      _snack('Add or select at least one credit memo', true);
      return;
    }
    final invoices = <Map<String, dynamic>>[];
    for (final id in _selectedInvoices) {
      final amount = double.tryParse(_invoiceCtrls[id]?.text.trim() ?? '') ?? 0;
      if (amount > 0) {
        invoices.add({'invoice_id': id, 'apply_amount': amount});
      }
    }
    if (_controlType == 'offset' && invoices.isEmpty && _creditTotal > 0) {
      final ok = await _confirmDirectOpen();
      if (!ok) return;
    }
    if (!_allowPartial && _netBalance.abs() > 0.01) {
      _snack(
        'Net balance must be zero when partial clearing is disabled',
        true,
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final result = await widget.glService.createCreditMemoClearing({
        'customer_id': _customerId,
        'posting_date': '${_apiDate(_postingDate)}T00:00:00Z',
        'document_date': '${_apiDate(_documentDate)}T00:00:00Z',
        'currency': _currency,
        'control_type': _controlType,
        'allow_partial': _allowPartial,
        'description': _descriptionCtrl.text.trim(),
        'new_credits': newCredits,
        'existing_credit_memo_ids': _selectedCredits.toList(),
        'invoices': invoices,
      });
      _snack(
        'Posted ${result['clearing_no']} ${result['journal_doc_no'] ?? ''}',
        false,
      );
      for (final line in _newCredits) {
        line.clear();
      }
      _descriptionCtrl.clear();
      await _loadCustomerData();
    } catch (e) {
      _snack('Post credit memo failed: $e', true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<bool> _confirmDirectOpen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post as Open Credit?'),
        content: const Text(
          'No invoices are selected. The credit memo will remain open for future matching.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String message, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  double _round2(double v) => (v * 100).round() / 100;

  String _customerLabel(dynamic c) {
    final code = c['customer_code']?.toString() ?? '';
    final name = c['name']?.toString() ?? '';
    return code.isEmpty ? name : '$code - $name';
  }

  @override
  Widget build(BuildContext context) {
    final netColor = _netBalance.abs() <= 0.01
        ? Colors.green
        : _netBalance > 0
        ? Colors.orange
        : Colors.red;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Memo'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadCustomerData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  title: 'Header',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 430,
                        height: 48,
                        child: DropdownButtonFormField<String>(
                          value: _customerId,
                          isDense: true,
                          isExpanded: true,
                          menuMaxHeight: 360,
                          decoration: _fieldDecoration(
                            'Customer *',
                            Icons.person_search_outlined,
                          ),
                          items: _customers
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id']?.toString(),
                                  child: SizedBox(
                                    width: 370,
                                    child: Text(
                                      _customerLabel(c),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) => _customers
                              .map(
                                (c) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _customerLabel(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _onCustomerChanged,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        height: 48,
                        child: DropdownButtonFormField<String>(
                          value: _controlType,
                          isDense: true,
                          isExpanded: true,
                          decoration: _fieldDecoration('Control Type', null),
                          items: const [
                            DropdownMenuItem(
                              value: 'offset',
                              child: Text('Offset & Clear'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('Direct Open Credit'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _controlType = v ?? 'offset'),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        height: 48,
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          child: InputDecorator(
                            decoration: _fieldDecoration('Posting Date', null),
                            child: Text(Fmt.d(_postingDate)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        height: 48,
                        child: InkWell(
                          onTap: () => _pickDate(false),
                          child: InputDecorator(
                            decoration: _fieldDecoration('Document Date', null),
                            child: Text(Fmt.d(_documentDate)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                          ),
                          onChanged: (v) => _currency = v.trim().isEmpty
                              ? 'USD'
                              : v.trim().toUpperCase(),
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        child: TextFormField(
                          controller: _descriptionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Text / Description',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final left = _creditPanel();
                    final right = _invoicePanel();
                    if (constraints.maxWidth >= 980) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 12),
                          Expanded(child: right),
                        ],
                      );
                    }
                    return Column(
                      children: [left, const SizedBox(height: 12), right],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Summary',
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _metric(
                        'Credit Total',
                        '-${_creditTotal.toStringAsFixed(2)}',
                        Colors.red,
                      ),
                      _metric(
                        'Invoice Applied',
                        _invoiceApplyTotal.toStringAsFixed(2),
                        Colors.green,
                      ),
                      _metric(
                        'Net Balance',
                        _netBalance.toStringAsFixed(2),
                        netColor,
                      ),
                      FilterChip(
                        selected: _allowPartial,
                        label: const Text('Allow partial clearing'),
                        onSelected: (v) => setState(() => _allowPartial = v),
                      ),
                      SizedBox(
                        width: 150,
                        child: OutlinedButton.icon(
                          onPressed: _autoFillInvoices,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Auto Match'),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: FilledButton.icon(
                          onPressed: _posting ? null : _submit,
                          icon: _posting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _creditPanel() {
    return _section(
      title: 'Credit Entries',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: OutlinedButton.icon(
                  onPressed: _addCreditLine,
                  icon: const Icon(Icons.add),
                  label: const Text('New Credit Line'),
                ),
              ),
              Text('Existing open credits: ${_creditMemos.length}'),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(_newCredits.length, (i) => _newCreditRow(i)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Use')),
                DataColumn(label: Text('Memo')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Reason')),
                DataColumn(label: Text('Remaining')),
              ],
              rows: _creditMemos.map((cm) {
                final id = cm['id']?.toString() ?? '';
                final selected = _selectedCredits.contains(id);
                return DataRow(
                  selected: selected,
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedCredits.add(id);
                          } else {
                            _selectedCredits.remove(id);
                          }
                        }),
                      ),
                    ),
                    DataCell(Text(cm['memo_no']?.toString() ?? '')),
                    DataCell(Text(Fmt.dateStr(cm['memo_date']?.toString()))),
                    DataCell(Text(cm['reason_code']?.toString() ?? '')),
                    DataCell(
                      Text(
                        ((cm['remaining_amount'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newCreditRow(int index) {
    final line = _newCredits[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: TextFormField(
              controller: line.reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason *'),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: line.amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount *'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextFormField(
              controller: line.noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeCreditLine(index),
          ),
        ],
      ),
    );
  }

  Widget _invoicePanel() {
    return _section(
      title: 'Invoices',
      child: _openInvoices.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _customerId == null
                    ? 'Select a customer to load invoices.'
                    : 'No open invoices.',
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Use')),
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Remaining')),
                  DataColumn(label: Text('Apply')),
                ],
                rows: _openInvoices.map((inv) {
                  final id = inv['id']?.toString() ?? '';
                  final selected = _selectedInvoices.contains(id);
                  final remaining =
                      (inv['remaining_amount'] as num?)?.toDouble() ?? 0;
                  return DataRow(
                    selected: selected,
                    cells: [
                      DataCell(
                        Checkbox(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedInvoices.add(id);
                              _invoiceCtrls[id]?.text = remaining
                                  .toStringAsFixed(2);
                            } else {
                              _selectedInvoices.remove(id);
                            }
                          }),
                        ),
                      ),
                      DataCell(Text(inv['invoice_no']?.toString() ?? '')),
                      DataCell(
                        Text(Fmt.dateStr(inv['invoice_date']?.toString())),
                      ),
                      DataCell(Text(remaining.toStringAsFixed(2))),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _invoiceCtrls[id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (_) => setState(() {
                              if ((_invoiceCtrls[id]?.text.trim().isNotEmpty ??
                                  false)) {
                                _selectedInvoices.add(id);
                              }
                            }),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixIconConstraints: icon == null
          ? null
          : const BoxConstraints(minWidth: 40, minHeight: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

class _CreditDraftLine {
  final reasonCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  void clear() {
    reasonCtrl.clear();
    amountCtrl.clear();
    noteCtrl.clear();
  }

  void dispose() {
    reasonCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
  }
}
