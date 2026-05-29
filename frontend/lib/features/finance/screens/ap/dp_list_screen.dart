import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_refund_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_voucher_screen.dart';

class DPListScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  const DPListScreen({super.key, required this.authService, required this.apService});
  @override State<DPListScreen> createState() => _DPListScreenState();
}

class _DPListScreenState extends State<DPListScreen> {
  List<DownPaymentModel> _dps = [];
  bool _loading = true;
  String? _error;

  // Filters
  String? _statusFilter;

  static const _statuses = {
    '': 'All',
    'DRAFT': 'Draft',
    'POSTED': 'Posted',
    'PARTIALLY_CLEARED': 'Partially Cleared',
    'FULLY_CLEARED': 'Fully Cleared',
    'PARTIALLY_REFUNDED': 'Partially Refunded',
    'FULLY_REFUNDED': 'Fully Refunded',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _dps = await widget.apService.listDownPayments(status: _statusFilter);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT': return Colors.grey;
      case 'POSTED': return Colors.blue;
      case 'PARTIALLY_CLEARED': return Colors.orange;
      case 'FULLY_CLEARED': return Colors.green;
      case 'PARTIALLY_REFUNDED': return Colors.pink;
      case 'FULLY_REFUNDED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Down Payments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Status filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _statuses.entries.map((e) {
              final selected = _statusFilter == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter = e.key.isEmpty ? null : e.key);
                    _load();
                  },
                  visualDensity: VisualDensity.compact,
                  selectedColor: _statusColor(e.key.isEmpty ? '' : e.key).withValues(alpha: 0.15),
                ),
              );
            }).toList(),
          ),
        ),

        // Summary bar
        if (!_loading && _error == null && _dps.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.shade50,
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text('${_dps.length} records  •  '
                  'Total: \$${ApService.fmtAmount(_dps.fold<double>(0.0, (s, d) => s + d.totalAmount))}  •  '
                  'Open: \$${ApService.fmtAmount(_dps.fold<double>(0.0, (s, d) => s + d.remainingAmount))}',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
            ]),
          ),

        // Column headers
        if (_dps.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.grey.shade100,
            child: Row(children: [
              const Expanded(flex: 2, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Vendor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Remaining', textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Status', textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const SizedBox(width: 60),
            ]),
          ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    ))
                  : _dps.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No down payments', style: TextStyle(color: Colors.grey.shade500)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            itemCount: _dps.length,
                            itemBuilder: (_, i) => _buildRow(_dps[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _buildRow(DownPaymentModel dp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(dp.dpNumber,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(dp.vendorName.isNotEmpty ? dp.vendorName : dp.vendorCode,
            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text('\$${ApService.fmtAmount(dp.totalAmount)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700))),
        Expanded(flex: 1, child: Text('\$${ApService.fmtAmount(dp.remainingAmount)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: dp.remainingAmount > 0 ? Colors.orange.shade700 : Colors.green.shade700))),
        Expanded(flex: 1, child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(dp.status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(dp.statusLabel, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: _statusColor(dp.status))),
          ),
        )),
        SizedBox(
          width: 60,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DPVoucherScreen(
                  authService: widget.authService,
                  apService: widget.apService,
                  downPayment: dp,
                ),
              )),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'View Detail',
            ),
            if (dp.canRefund)
              IconButton(
                icon: Icon(Icons.money_off, size: 16, color: Colors.red.shade400),
                onPressed: () async {
                  final fullDp = await widget.apService.getDownPayment(dp.id);
                  if (mounted) {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DPRefundScreen(
                        authService: widget.authService,
                        apService: widget.apService,
                        downPayment: fullDp,
                      ),
                    ));
                    if (result == true) _load();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Refund',
              ),
          ]),
        ),
      ]),
    );
  }
}
