import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class AccountBalanceScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;

  const AccountBalanceScreen({
    super.key,
    required this.authService,
    required this.glService,
  });

  @override
  State<AccountBalanceScreen> createState() => _AccountBalanceScreenState();
}

class _AccountBalanceScreenState extends State<AccountBalanceScreen> {
  List<dynamic> _balances = [];
  bool _loading = false;
  int _year = DateTime.now().year;
  int? _month;
  final List<int> _years = List.generate(10, (i) => DateTime.now().year - 5 + i);

  static const _months = [
    'All', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() => _loading = true);
    try {
      final data = await widget.glService.getAccountBalances(year: _year, month: _month);
      setState(() => _balances = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load balances: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Account Balances',
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Year selector
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) {
                      setState(() => _year = v!);
                      _loadBalances();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Month selector
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('All', style: TextStyle(fontSize: 13)),
                    items: List.generate(_months.length, (i) => DropdownMenuItem(
                      value: i == 0 ? null : i,
                      child: Text(i == 0 ? 'All' : _months[i]),
                    )),
                    onChanged: (v) {
                      setState(() => _month = v);
                      _loadBalances();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadBalances,
                  tooltip: 'Refresh',
                ),
                const Spacer(),
                Text(
                  '$_year${_month != null ? ' ${_months[_month!]}' : ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Column headers
          if (_balances.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _headerText('Code')),
                  Expanded(flex: 3, child: _headerText('Account Name')),
                  Expanded(flex: 2, child: _headerText('Type')),
                  Expanded(flex: 2, child: _headerText('Total Debit', align: TextAlign.right)),
                  Expanded(flex: 2, child: _headerText('Total Credit', align: TextAlign.right)),
                  Expanded(flex: 2, child: _headerText('Balance', align: TextAlign.right)),
                ],
              ),
            ),

          // Balance data
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _balances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.balance_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No balance data found', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _balances.length,
                        itemBuilder: (context, i) => _BalanceRow(entry: _balances[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(text,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey.shade700),
      textAlign: align,
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final dynamic entry;
  const _BalanceRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final code = entry['account_code'] ?? entry['code'] ?? '';
    final name = entry['account_name'] ?? entry['name'] ?? '';
    final type = entry['account_type'] ?? entry['type'] ?? '';
    final debit = (entry['total_debit'] as num?)?.toDouble() ?? 0;
    final credit = (entry['total_credit'] as num?)?.toDouble() ?? 0;
    final balance = (entry['balance'] as num?)?.toDouble() ?? (debit - credit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(
            code,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500),
          )),
          Expanded(flex: 3, child: Text(
            name,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          Expanded(flex: 2, child: Text(
            type,
            style: TextStyle(fontSize: 11, color: AccountModel.typeColor(type)),
          )),
          Expanded(flex: 2, child: Text(
            '\$${GlService.fmtAmount(debit)}',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            textAlign: TextAlign.right,
          )),
          Expanded(flex: 2, child: Text(
            '\$${GlService.fmtAmount(credit)}',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            textAlign: TextAlign.right,
          )),
          Expanded(flex: 2, child: Text(
            '\$${GlService.fmtAmount(balance.abs())}${balance < 0 ? ' CR' : ' DR'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: balance >= 0 ? Colors.green.shade800 : AppTheme.errorColor,
            ),
            textAlign: TextAlign.right,
          )),
        ],
      ),
    );
  }
}
