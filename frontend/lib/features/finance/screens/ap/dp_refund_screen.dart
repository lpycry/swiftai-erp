import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class DPRefundScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  final DownPaymentModel downPayment;
  const DPRefundScreen({
    super.key,
    required this.authService,
    required this.apService,
    required this.downPayment,
  });
  @override State<DPRefundScreen> createState() => _DPRefundScreenState();
}

class _DPRefundScreenState extends State<DPRefundScreen> {
  bool _submitting = false;

  final _refundAmtCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime _refundDate = DateTime.now();
  String _refundMethod = 'BANK_TRANSFER';
  String? _selectedSourceAccountId;
  List<AccountModel> _bankAccounts = [];

  String? _amountError;
  String? _accountError;
  String? _reasonError;

  @override
  void initState() {
    super.initState();
    _refundAmtCtrl.text = widget.downPayment.remainingAmount.toStringAsFixed(2);
    _loadBankAccounts();
  }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _loadBankAccounts() async {
    try {
      final glService = GlService(_token);
      final all = await glService.getAccounts();
      setState(() {
        _bankAccounts = all.where((a) => a.isLeaf).toList();
      });
    } catch (_) {}
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      final amt = double.tryParse(_refundAmtCtrl.text);
      final maxAmt = widget.downPayment.remainingAmount;
      _amountError = amt == null || amt <= 0
          ? 'Enter a valid amount > 0'
          : amt > maxAmt
              ? 'Cannot exceed remaining amount (${ApService.fmtAmount(maxAmt)})'
              : null;
      if (_amountError != null) ok = false;

      _accountError = _selectedSourceAccountId == null ? 'Source account is required' : null;
      if (_accountError != null) ok = false;

      _reasonError = _reasonCtrl.text.trim().isEmpty ? 'Refund reason is required' : null;
      if (_reasonError != null) ok = false;
    });
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Refund \$${ApService.fmtAmount(double.parse(_refundAmtCtrl.text))} from down payment ${widget.downPayment.dpNumber}?'),
          const SizedBox(height: 8),
          Text('This will post a refund journal entry.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Refund')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await widget.apService.refundDownPayment(widget.downPayment.id, {
        'refund_amount': double.parse(_refundAmtCtrl.text),
        'refund_date': '${_refundDate.year}-${_refundDate.month.toString().padLeft(2, '0')}-${_refundDate.day.toString().padLeft(2, '0')}',
        'refund_method': _refundMethod,
        'source_account_id': _selectedSourceAccountId,
        'reason': _reasonCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refund processed successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _refundAmtCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = widget.downPayment;
    final refundAmt = double.tryParse(_refundAmtCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Down Payment Refund')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Original DP Info Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Original Down Payment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
              const Divider(),
              _origRow('DP #', dp.dpNumber),
              _origRow('Vendor', dp.vendorName.isNotEmpty ? '${dp.vendorCode} - ${dp.vendorName}' : dp.vendorCode),
              _origRow('PO', dp.poNumber),
              _origRow('Original Amount', '\$${ApService.fmtAmount(dp.totalAmount)}'),
              _origRow('Cleared', '\$${ApService.fmtAmount(dp.clearedAmount)}'),
              _origRow('Already Refunded', '\$${ApService.fmtAmount(dp.refundedAmount)}'),
              const Divider(),
              _origRow('Available for Refund', '\$${ApService.fmtAmount(dp.remainingAmount)}',
                  valueColor: Colors.orange.shade700, bold: true),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Refund Amount ──
          _label('REFUND AMOUNT *'),
          const SizedBox(height: 6),
          TextField(
            controller: _refundAmtCtrl,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: '0.00',
              errorText: _amountError,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // ── Refund Date ──
          _label('REFUND DATE'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _refundDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _refundDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text('${_refundDate.year}-${_refundDate.month.toString().padLeft(2, '0')}-${_refundDate.day.toString().padLeft(2, '0')}'),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Refund Method ──
          _label('REFUND METHOD *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _refundMethod,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              'BANK_TRANSFER', 'CASH', 'CHECK', 'OTHER'
            ].map((m) => DropdownMenuItem(
              value: m,
              child: Text(m.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _refundMethod = v ?? 'BANK_TRANSFER'),
          ),
          const SizedBox(height: 16),

          // ── Source Account ──
          _label('SOURCE ACCOUNT (Cr) *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedSourceAccountId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Select refund source account',
              errorText: _accountError,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            isExpanded: true,
            items: _bankAccounts.map((a) => DropdownMenuItem(
              value: a.id,
              child: Text('${a.code} - ${a.name}',
                  style: TextStyle(fontSize: 12, color: AccountModel.typeColor(a.type))),
            )).toList(),
            onChanged: (v) => setState(() { _selectedSourceAccountId = v; _accountError = null; }),
          ),
          const SizedBox(height: 16),

          // ── Reason ──
          _label('REFUND REASON *'),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: 'Required - explain the reason for refund',
              errorText: _reasonError,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // ── JE Preview ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Refund Journal Entry Preview',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Divider(height: 16),
              _jeLine('Dr  Source Account', refundAmt, isDebit: true),
              const SizedBox(height: 4),
              _jeLine('Cr  AP Down Payment (Special GL: A)', refundAmt, isDebit: false),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Submit ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.money_off),
              label: Text(_submitting ? 'Processing...' : 'Process Refund'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _submitting ? null : _submit,
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.grey.shade600, letterSpacing: 0.8));
  }

  Widget _origRow(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: valueColor)),
      ]),
    );
  }

  Widget _jeLine(String label, double amount, {required bool isDebit}) {
    return Row(children: [
      Icon(isDebit ? Icons.arrow_downward : Icons.arrow_upward,
          size: 14, color: isDebit ? Colors.green.shade700 : Colors.red.shade400),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
      Text('\$${ApService.fmtAmount(amount)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDebit ? Colors.green.shade700 : Colors.red.shade700)),
    ]);
  }
}
