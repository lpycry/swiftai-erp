import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import '../services/gl_service.dart';

class OpenItemClearingScreen extends StatefulWidget {
  final GlService glService;
  const OpenItemClearingScreen({super.key, required this.glService});

  @override
  State<OpenItemClearingScreen> createState() => _OpenItemClearingScreenState();
}

class _OpenItemClearingScreenState extends State<OpenItemClearingScreen> {
  final _amountCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  List<AccountModel> _accounts = [];
  List<AccountModel> _openItemAccounts = [];
  List<dynamic> _openItems = [];
  List<dynamic> _clearedItems = [];
  final Set<String> _selected = {};
  String? _masterAccountId;
  String? _offsetAccountId;
  DateTime _clearingDate = DateTime.now();
  bool _withPosting = false;
  String _direction = 'debit';
  bool _loading = false;
  bool _posting = false;
  bool _showCleared = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final accounts = await widget.glService.getAccounts();
      final leafAccounts = accounts
          .where((a) => a.isLeaf && a.isActive)
          .toList();
      setState(() {
        _accounts = leafAccounts;
        _openItemAccounts = leafAccounts
            .where((a) => a.openItemManaged)
            .toList();
        if (_masterAccountId != null &&
            !_openItemAccounts.any((a) => a.id == _masterAccountId)) {
          _masterAccountId = null;
          _openItems = [];
          _clearedItems = [];
          _selected.clear();
        }
      });
    } catch (e) {
      _snack('Load accounts failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOpenItems() async {
    if (_masterAccountId == null) return;
    setState(() {
      _loading = true;
      _selected.clear();
      _openItems = [];
      _clearedItems = [];
    });
    try {
      if (_showCleared) {
        final items = await widget.glService.listClearedItems(
          _masterAccountId!,
        );
        setState(() => _clearedItems = items);
      } else {
        final items = await widget.glService.listOpenItems(_masterAccountId!);
        setState(() => _openItems = items);
      }
    } catch (e) {
      _snack('Load items failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _selectedSigned => _openItems
      .where((i) => _selected.contains(i['line_id']?.toString()))
      .fold(0.0, (s, i) {
        final debit = (i['debit'] as num?)?.toDouble() ?? 0;
        final credit = (i['credit'] as num?)?.toDouble() ?? 0;
        return s + debit - credit;
      });

  double get _newLineSigned {
    if (!_withPosting) return 0;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return _direction == 'debit' ? amount : -amount;
  }

  double get _difference {
    final generatedMasterSigned = _withPosting ? -_newLineSigned : 0.0;
    return ((_selectedSigned + generatedMasterSigned) * 100).round() / 100;
  }

  String _date(DateTime d) => Fmt.d(d);

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clearingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _clearingDate = picked);
  }

  Future<void> _submit() async {
    if (_masterAccountId == null) {
      _snack('Master Clearing Account is required', true);
      return;
    }
    if (_selected.isEmpty) {
      _snack('Please select open items to clear', true);
      return;
    }
    if (_withPosting &&
        (_offsetAccountId == null ||
            (double.tryParse(_amountCtrl.text.trim()) ?? 0) <= 0)) {
      _snack('Offsetting Account and Amount are required', true);
      return;
    }
    if (_difference.abs() > 0.01) {
      _snack('Difference ${_difference.toStringAsFixed(2)} is not zero', true);
      return;
    }
    setState(() => _posting = true);
    try {
      final body = <String, dynamic>{
        'master_account_id': _masterAccountId,
        'clearing_date': '${_apiDate(_clearingDate)}T00:00:00Z',
        'with_posting': _withPosting,
        'selected_line_ids': _selected.toList(),
        'description': _textCtrl.text.trim(),
      };
      if (_withPosting) {
        body['new_line'] = {
          'offsetting_account_id': _offsetAccountId,
          'direction': _direction,
          'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
          'description': _textCtrl.text.trim(),
        };
      }
      final result = await widget.glService.createClearing(body);
      _snack('Clearing posted: ${result['clearing_doc_no']}', false);
      await _loadOpenItems();
    } catch (e) {
      _snack('$e', true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _snack(String msg, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String _accountLabel(AccountModel a) => '${a.code} - ${a.name}';

  Future<void> _showOriginalDocument(dynamic item) async {
    final entryId = item['entry_id']?.toString() ?? '';
    if (entryId.isEmpty) {
      _snack('Original journal entry is missing for this item', true);
      return;
    }
    setState(() => _loading = true);
    try {
      final detail = await widget.glService.getJournalEntry(entryId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _OriginalDocumentDialog(entry: detail),
      );
    } catch (e) {
      _snack('Load original document failed: $e', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanced = _difference.abs() <= 0.01 && _selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Open Item Clearing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 980;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: compact
                                    ? constraints.maxWidth
                                    : constraints.maxWidth * 0.42,
                                child: DropdownButtonFormField<String>(
                                  value: _masterAccountId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Master Clearing Account *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _openItemAccounts
                                      .map(
                                        (a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                            _accountLabel(a),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() => _masterAccountId = v);
                                    _loadOpenItems();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: compact ? constraints.maxWidth : 230,
                                child: SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('Open Items'),
                                      icon: Icon(Icons.pending_actions),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('Cleared Items'),
                                      icon: Icon(Icons.fact_check),
                                    ),
                                  ],
                                  selected: {_showCleared},
                                  onSelectionChanged: (values) {
                                    setState(() {
                                      _showCleared = values.first;
                                      _selected.clear();
                                      _withPosting = false;
                                    });
                                    _loadOpenItems();
                                  },
                                  showSelectedIcon: false,
                                ),
                              ),
                              if (!_showCleared)
                                SizedBox(
                                  width: compact ? constraints.maxWidth : 230,
                                  child: _SwitchRow(
                                    title: 'Post + Clear',
                                    subtitle: _withPosting ? 'F-04' : 'F-03',
                                    value: _withPosting,
                                    onChanged: (v) =>
                                        setState(() => _withPosting = v),
                                  ),
                                ),
                              SizedBox(
                                width: 170,
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(_date(_clearingDate)),
                                ),
                              ),
                              IconButton(
                                onPressed: _loadOpenItems,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          );
                        },
                      ),
                      if (!_showCleared && _withPosting) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _offsetAccountId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Offsetting Account *',
                                  border: OutlineInputBorder(),
                                ),
                                items: _accounts
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          _accountLabel(a),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _offsetAccountId = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<String>(
                                value: _direction,
                                decoration: const InputDecoration(
                                  labelText: 'Direction',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'debit',
                                    child: Text('Debit'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'credit',
                                    child: Text('Credit'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _direction = v ?? 'debit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 160,
                              child: TextField(
                                controller: _amountCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Amount *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _textCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Text / Description',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _showCleared
                                ? '${_clearedItems.length} cleared item(s)'
                                : '${_openItems.length} open item(s), ${_selected.length} selected',
                          ),
                          const Spacer(),
                          if (!_showCleared) ...[
                            Text(
                              'Difference: ${_difference.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balanced ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                  : const Icon(Icons.done_all),
                              label: const Text('Submit Clearing'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: _showCleared
                              ? const [
                                  DataColumn(label: Text('Document')),
                                  DataColumn(label: Text('Posting Date')),
                                  DataColumn(label: Text('Clearing Doc')),
                                  DataColumn(label: Text('Clearing Date')),
                                  DataColumn(label: Text('Side')),
                                  DataColumn(label: Text('Debit')),
                                  DataColumn(label: Text('Credit')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Text')),
                                ]
                              : const [
                                  DataColumn(label: Text('Select')),
                                  DataColumn(label: Text('Document')),
                                  DataColumn(label: Text('Posting Date')),
                                  DataColumn(label: Text('Side')),
                                  DataColumn(label: Text('Debit')),
                                  DataColumn(label: Text('Credit')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Text')),
                                ],
                          rows: (_showCleared ? _clearedItems : _openItems).map(
                            (item) {
                              final id = item['line_id']?.toString() ?? '';
                              final selected = _selected.contains(id);
                              final amount =
                                  (item['amount_signed'] as num?)?.toDouble() ??
                                  0;
                              DataCell docCell(Widget child) => DataCell(
                                child,
                                onDoubleTap: () => _showOriginalDocument(item),
                              );
                              final commonCells = [
                                docCell(
                                  Text(item['document_no']?.toString() ?? ''),
                                ),
                                docCell(
                                  Text(Fmt.dateStr(item['posting_date'])),
                                ),
                                if (_showCleared) ...[
                                  docCell(
                                    Text(
                                      item['clearing_doc_no']?.toString() ?? '',
                                    ),
                                  ),
                                  docCell(
                                    Text(Fmt.dateStr(item['clearing_date'])),
                                  ),
                                ],
                                docCell(
                                  Text(
                                    item['original_side']
                                            ?.toString()
                                            .toUpperCase() ??
                                        '',
                                  ),
                                ),
                                docCell(
                                  Text(
                                    ((item['debit'] as num?)?.toDouble() ?? 0)
                                        .toStringAsFixed(2),
                                  ),
                                ),
                                docCell(
                                  Text(
                                    ((item['credit'] as num?)?.toDouble() ?? 0)
                                        .toStringAsFixed(2),
                                  ),
                                ),
                                docCell(
                                  Text(
                                    amount.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: amount >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                                docCell(
                                  SizedBox(
                                    width: 280,
                                    child: Text(
                                      item['description']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ];
                              return DataRow(
                                selected: !_showCleared && selected,
                                cells: _showCleared
                                    ? commonCells
                                    : [
                                        DataCell(
                                          Checkbox(
                                            value: selected,
                                            onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _selected.add(id);
                                              } else {
                                                _selected.remove(id);
                                              }
                                            }),
                                          ),
                                        ),
                                        ...commonCells,
                                      ],
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OriginalDocumentDialog extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _OriginalDocumentDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final lines = (entry['lines'] as List<dynamic>? ?? []);
    final totalDebit = lines.fold<double>(
      0,
      (sum, line) => sum + ((line['debit'] as num?)?.toDouble() ?? 0),
    );
    final totalCredit = lines.fold<double>(
      0,
      (sum, line) => sum + ((line['credit'] as num?)?.toDouble() ?? 0),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry['document_no']?.toString() ?? 'Journal Entry',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (entry['status']?.toString() ?? '').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 28,
                  runSpacing: 8,
                  children: [
                    _info('Description', entry['description']),
                    _info('Posting Date', Fmt.dateStr(entry['posting_date'])),
                    _info('Document Date', Fmt.dateStr(entry['document_date'])),
                    _info('Reference', entry['reference']),
                    _info('Type', entry['entry_type']),
                    _info('Source', entry['source']),
                    _info('Company', entry['organization_name']),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Line Items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Account')),
                          DataColumn(label: Text('Debit')),
                          DataColumn(label: Text('Credit')),
                          DataColumn(label: Text('Description')),
                        ],
                        rows: [
                          ...lines.map((line) {
                            final account =
                                '${line['account_code'] ?? ''} ${line['account_name'] ?? ''}'
                                    .trim();
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(width: 260, child: Text(account)),
                                ),
                                DataCell(Text(_money(line['debit']))),
                                DataCell(Text(_money(line['credit']))),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(
                                      line['description']?.toString() ?? '',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          DataRow(
                            cells: [
                              const DataCell(
                                Text(
                                  'TOTAL',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              DataCell(
                                Text(
                                  totalDebit.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  totalCredit.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const DataCell(Text('')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(
            value?.toString().isEmpty == false ? value.toString() : '-',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    if (amount == 0) return '';
    return amount.toStringAsFixed(2);
  }
}
