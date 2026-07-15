import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import '../../services/gl_service.dart';

class IncomingPaymentsScreen extends StatefulWidget {
  final GlService glService;
  const IncomingPaymentsScreen({super.key, required this.glService});

  @override
  State<IncomingPaymentsScreen> createState() => _IncomingPaymentsScreenState();
}

class _IncomingPaymentsScreenState extends State<IncomingPaymentsScreen> {
  final _netCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1');
  final _diffCtrl = TextEditingController(text: '0');
  final _textCtrl = TextEditingController();
  final Map<String, TextEditingController> _applyCtrls = {};
  final Set<String> _selectedInvoices = {};

  List<dynamic> _customers = [];
  List<dynamic> _openInvoices = [];
  List<AccountModel> _accounts = [];
  List<AccountModel> _bankAccounts = [];
  String? _customerId;
  String? _bankAccountId;
  String _currency = 'USD';
  String _diffType = '';
  DateTime _receiptDate = DateTime.now();
  bool _loading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _netCtrl.dispose();
    _rateCtrl.dispose();
    _diffCtrl.dispose();
    _textCtrl.dispose();
    for (final ctrl in _applyCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.glService.listARCustomers(),
        widget.glService.getAccounts(),
      ]);
      final accounts = results[1] as List<AccountModel>;
      setState(() {
        _customers = results[0] as List<dynamic>;
        _accounts = accounts.where((a) => a.isLeaf && a.isActive).toList();
        _bankAccounts = _accounts
            .where((a) => a.type.toUpperCase() == 'ASSET')
            .toList();
        if (_bankAccounts.isNotEmpty) _bankAccountId = _bankAccounts.first.id;
      });
    } catch (e) {
      _snack('Load incoming payment data failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInvoices() async {
    if (_customerId == null) return;
    setState(() {
      _loading = true;
      _selectedInvoices.clear();
      for (final ctrl in _applyCtrls.values) {
        ctrl.dispose();
      }
      _applyCtrls.clear();
      _openInvoices = [];
    });
    try {
      final invoices = await widget.glService.listAROpenInvoices(_customerId!);
      setState(() {
        _openInvoices = invoices;
        for (final inv in invoices) {
          final id = inv['id']?.toString() ?? '';
          _applyCtrls[id] = TextEditingController();
        }
      });
    } catch (e) {
      _snack('Load open invoices failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _netAmount => double.tryParse(_netCtrl.text.trim()) ?? 0;
  double get _diffAmount => double.tryParse(_diffCtrl.text.trim()) ?? 0;

  double get _appliedAmount {
    var total = 0.0;
    for (final id in _selectedInvoices) {
      total += double.tryParse(_applyCtrls[id]?.text.trim() ?? '') ?? 0;
    }
    return _round2(total);
  }

  double get _balanceDifference =>
      _round2(_netAmount + _diffAmount - _appliedAmount);

  String _date(DateTime d) => Fmt.d(d);

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _receiptDate = picked);
  }

  void _onCustomerChanged(String? id) {
    if (id == null) return;
    final c = _customers.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e?['id']?.toString() == id,
      orElse: () => null,
    );
    setState(() {
      _customerId = id;
      _currency = c?['currency']?.toString() ?? 'USD';
    });
    _loadInvoices();
  }

  void _smartMatch() {
    final target = _round2(_netAmount + _diffAmount);
    if (target <= 0) {
      _snack('Enter net amount first', true);
      return;
    }
    _selectedInvoices.clear();
    for (final ctrl in _applyCtrls.values) {
      ctrl.text = '';
    }

    final exact = _openInvoices.cast<Map<String, dynamic>>().where((inv) {
      final rem = (inv['remaining_amount'] as num?)?.toDouble() ?? 0;
      return (_round2(rem) - target).abs() <= 0.01;
    }).toList();
    if (exact.isNotEmpty) {
      final inv = exact.first;
      final id = inv['id']?.toString() ?? '';
      _selectedInvoices.add(id);
      _applyCtrls[id]?.text = target.toStringAsFixed(2);
      setState(() {});
      return;
    }

    var remaining = target;
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
      final rem = (inv['remaining_amount'] as num?)?.toDouble() ?? 0;
      final apply = rem < remaining ? rem : remaining;
      if (apply > 0) {
        _selectedInvoices.add(id);
        _applyCtrls[id]?.text = apply.toStringAsFixed(2);
        remaining = _round2(remaining - apply);
      }
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_customerId == null || _bankAccountId == null) {
      _snack('Customer and bank account are required', true);
      return;
    }
    if (_selectedInvoices.isEmpty) {
      _snack('Select at least one open invoice', true);
      return;
    }
    if (_balanceDifference.abs() > 0.01) {
      _snack(
        'Payment is not balanced. Difference ${_balanceDifference.toStringAsFixed(2)}',
        true,
      );
      return;
    }
    final apps = <Map<String, dynamic>>[];
    for (final id in _selectedInvoices) {
      final amount = double.tryParse(_applyCtrls[id]?.text.trim() ?? '') ?? 0;
      if (amount <= 0) {
        _snack('Apply amount must be greater than zero', true);
        return;
      }
      apps.add({'invoice_id': id, 'apply_amount': amount});
    }

    setState(() => _posting = true);
    try {
      final result = await widget.glService.createIncomingPayment({
        'customer_id': _customerId,
        'bank_account_id': _bankAccountId,
        'receipt_date': '${_apiDate(_receiptDate)}T00:00:00Z',
        'net_amount': _netAmount,
        'currency': _currency,
        'exchange_rate': double.tryParse(_rateCtrl.text.trim()) ?? 1,
        'diff_type': _diffType,
        'diff_amount': _diffAmount,
        'description': _textCtrl.text.trim(),
        'applications': apps,
      });
      _snack(
        'Posted ${result['voucher_no']} / ${result['journal_doc_no']}',
        false,
      );
      _netCtrl.clear();
      _diffCtrl.text = '0';
      _textCtrl.clear();
      await _loadInvoices();
    } catch (e) {
      _snack('Post incoming payment failed: $e', true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
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
    final balanced = _balanceDifference.abs() <= 0.01;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Payments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadInitial,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  title: 'Receipt Header',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 420,
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
                                    width: 360,
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
                        width: 360,
                        height: 48,
                        child: DropdownButtonFormField<String>(
                          value: _bankAccountId,
                          isDense: true,
                          isExpanded: true,
                          menuMaxHeight: 360,
                          decoration: _fieldDecoration(
                            'Bank Account *',
                            Icons.account_balance_outlined,
                          ),
                          items: _bankAccounts
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: a.id,
                                  child: SizedBox(
                                    width: 300,
                                    child: Text(
                                      '${a.code} - ${a.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) => _bankAccounts
                              .map(
                                (a) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${a.code} - ${a.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _bankAccountId = v),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _netCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Net Amount *',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 130,
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
                        width: 130,
                        child: TextFormField(
                          controller: _rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Rate'),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: _fieldDecoration(
                              'Receipt Date',
                              Icons.calendar_today_outlined,
                            ),
                            child: Text(_date(_receiptDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Deductions / Differences',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: _diffType,
                          decoration: const InputDecoration(
                            labelText: 'Diff Type',
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('None')),
                            DropdownMenuItem(
                              value: 'Bank Fee',
                              child: Text('Bank Fee'),
                            ),
                            DropdownMenuItem(
                              value: 'Short Pay',
                              child: Text('Short Pay'),
                            ),
                            DropdownMenuItem(
                              value: 'Exchange Loss',
                              child: Text('Exchange Loss'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _diffType = v ?? ''),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _diffCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Diff Amount',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 420,
                        child: TextFormField(
                          controller: _textCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Text / Description',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Open Invoices',
                  trailing: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Applied ${_appliedAmount.toStringAsFixed(2)}  Difference ${_balanceDifference.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: balanced ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _smartMatch,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Smart Match'),
                      ),
                      FilledButton.icon(
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
                        label: const Text('Post Receipt'),
                      ),
                    ],
                  ),
                  child: _openInvoices.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _customerId == null
                                ? 'Select a customer to load open invoices.'
                                : 'No open invoices for this customer.',
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Select')),
                              DataColumn(label: Text('Invoice')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Original')),
                              DataColumn(label: Text('Remaining')),
                              DataColumn(label: Text('Apply Amount')),
                              DataColumn(label: Text('Age')),
                              DataColumn(label: Text('Reference')),
                            ],
                            rows: _openInvoices.map((inv) {
                              final id = inv['id']?.toString() ?? '';
                              final selected = _selectedInvoices.contains(id);
                              return DataRow(
                                selected: selected,
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      value: selected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedInvoices.add(id);
                                            _applyCtrls[id]?.text =
                                                ((inv['remaining_amount']
                                                                as num?)
                                                            ?.toDouble() ??
                                                        0)
                                                    .toStringAsFixed(2);
                                          } else {
                                            _selectedInvoices.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Text(inv['invoice_no']?.toString() ?? ''),
                                  ),
                                  DataCell(
                                    Text(
                                      Fmt.dateStr(
                                        inv['invoice_date']?.toString(),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      ((inv['total_amount'] as num?)
                                                  ?.toDouble() ??
                                              0)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      ((inv['remaining_amount'] as num?)
                                                  ?.toDouble() ??
                                              0)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: _applyCtrls[id],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {
                                          if ((_applyCtrls[id]?.text
                                                  .trim()
                                                  .isNotEmpty ??
                                              false)) {
                                            _selectedInvoices.add(id);
                                          }
                                        }),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${inv['age_days'] ?? 0}')),
                                  DataCell(
                                    SizedBox(
                                      width: 260,
                                      child: Text(
                                        inv['reference']?.toString() ?? '',
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
              ],
            ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: trailing,
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}
