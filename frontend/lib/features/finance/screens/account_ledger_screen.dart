import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class AccountLedgerScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;

  const AccountLedgerScreen({
    super.key,
    required this.authService,
    required this.glService,
  });

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<dynamic> _ledger = [];
  bool _loadingAccounts = true;
  bool _loadingLedger = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.glService.getAccounts();
      setState(() {
        _accounts = accounts.where((a) => a.isLeaf).toList();
        _loadingAccounts = false;
      });
    } catch (e) {
      setState(() => _loadingAccounts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load accounts: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadLedger({bool append = false}) async {
    if (_selectedAccount == null) return;
    setState(() => _loadingLedger = true);
    try {
      final page = append ? _page + 1 : 1;
      final data = await widget.glService.getAccountLedger(
        _selectedAccount!.id,
        from: _dateFrom?.toUtc().toIso8601String(),
        to: _dateTo?.toUtc().toIso8601String(),
        page: page,
        pageSize: 50,
      );
      setState(() {
        if (append) {
          _ledger.addAll(data);
          _page = page;
        } else {
          _ledger = data;
          _page = 1;
        }
        _hasMore = data.length >= 50;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ledger: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _loadingLedger = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Account Ledger',
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccount?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: Text(
                    'Select account',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                  items: _loadingAccounts
                      ? [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Loading...'),
                          ),
                        ]
                      : _accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.code} - ${a.name}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedAccount = v != null
                          ? _accounts.firstWhere((a) => a.id == v)
                          : null;
                    });
                    _loadLedger();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _dateFrom = picked);
                            _loadLedger();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'From',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _dateFrom != null
                                ? '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}'
                                : 'Select date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _dateTo = picked);
                            _loadLedger();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'To',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _dateTo != null
                                ? '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}'
                                : 'Select date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    if (_selectedAccount != null)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadLedger,
                        tooltip: 'Refresh',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Column headers
          if (_ledger.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _headerText('Date')),
                  Expanded(flex: 2, child: _headerText('Document')),
                  Expanded(flex: 3, child: _headerText('Description')),
                  Expanded(
                    flex: 2,
                    child: _headerText('Debit', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 2,
                    child: _headerText('Credit', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 2,
                    child: _headerText('Balance', align: TextAlign.right),
                  ),
                ],
              ),
            ),

          // Ledger data
          Expanded(
            child: _selectedAccount == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select an account to view ledger',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : _loadingLedger
                ? const Center(child: CircularProgressIndicator())
                : _ledger.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No ledger entries found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification && _hasMore) {
                        _loadLedger(append: true);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _ledger.length,
                      itemBuilder: (context, i) =>
                          _LedgerRow(entry: _ledger[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: Colors.grey.shade700,
      ),
      textAlign: align,
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final dynamic entry;
  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(entry['posting_date'] ?? entry['date']);
    final debit = (entry['debit'] as num?)?.toDouble() ?? 0;
    final credit = (entry['credit'] as num?)?.toDouble() ?? 0;
    final balance = (entry['balance'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(dateStr, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry['document_no'] ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              entry['description'] ?? '',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              debit != 0 ? '\$${GlService.fmtAmount(debit)}' : '',
              style: TextStyle(
                fontSize: 12,
                color: debit < 0 ? AppTheme.errorColor : Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              credit != 0 ? '\$${GlService.fmtAmount(credit)}' : '',
              style: TextStyle(
                fontSize: 12,
                color: credit < 0
                    ? AppTheme.errorColor
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '\$${GlService.fmtAmount(balance)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: balance >= 0
                    ? Colors.green.shade800
                    : AppTheme.errorColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }
}
