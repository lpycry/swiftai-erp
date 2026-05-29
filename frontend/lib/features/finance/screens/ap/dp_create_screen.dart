import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_voucher_screen.dart';

class DPCreateScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  const DPCreateScreen({super.key, required this.authService, required this.apService});
  @override State<DPCreateScreen> createState() => _DPCreateScreenState();
}

class _DPCreateScreenState extends State<DPCreateScreen> {
  bool _loading = false;
  bool _submitting = false;

  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _pos = [];
  List<AccountModel> _creditAccounts = [];

  String? _selectedVendorId;
  String? _selectedPoId;
  String? _selectedCreditAccountId;
  String? _selectedVendorName;

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _currency = 'USD';

  String? _vendorError;
  String? _poError;
  String? _amountError;
  String? _creditAccountError;

  Map<String, dynamic>? _selectedPoData;
  double _poRemainingAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _token => widget.authService.accessToken ?? '';
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final vResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/purchase/vendors'), headers: _headers);
      if (vResp.statusCode < 400) {
        _vendors = ((jsonDecode(vResp.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      }

      final poResp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/purchase/pending-invoice-pos'), headers: _headers);
      if (poResp.statusCode < 400) {
        _pos = ((jsonDecode(poResp.body)['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      }

      final glService = GlService(_token);
      _creditAccounts = await glService.getAccounts();

      setState(() {});
      if (mounted && _vendors.isEmpty) {
        _msg('No vendors found. Create a vendor first.', isError: true);
      }
    } catch (e) {
      if (mounted) _msg('Failed to load data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredPOs() {
    if (_selectedVendorId == null) return [];
    return _pos.where((p) => p['vendor_id']?.toString() == _selectedVendorId).toList();
  }

  double _calcPoRemaining(Map<String, dynamic> po) {
    final items = po['items'] as List<dynamic>? ?? [];
    double remaining = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final openQty = (item['open_invoice_qty'] as num?)?.toDouble() ?? 0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
      remaining += openQty * unitPrice;
    }
    return remaining;
  }

  void _onVendorChanged(String? vendorId) {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedPoId = null;
      _selectedPoData = null;
      _vendorError = null;
      _poError = null;
      _amountError = null;
      _poRemainingAmount = 0;

      if (vendorId != null) {
        final vendor = _vendors.firstWhere(
          (v) => v['id']?.toString() == vendorId,
          orElse: () => <String, dynamic>{},
        );
        _selectedVendorName = vendor['name']?.toString() ?? vendor['vendor_code']?.toString() ?? '';
      }
    });
  }

  void _onPoChanged(String? poId) {
    setState(() {
      _selectedPoId = poId;
      _poError = null;
      _amountError = null;
      if (poId != null) {
        final po = _filteredPOs().firstWhere(
          (p) => p['id']?.toString() == poId,
          orElse: () => <String, dynamic>{},
        );
        if (po.isNotEmpty) {
          _selectedPoData = po;
          _poRemainingAmount = _calcPoRemaining(po);
        }
      } else {
        _selectedPoData = null;
        _poRemainingAmount = 0;
      }
    });
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _vendorError = _selectedVendorId == null ? 'Vendor is required' : null;
      if (_vendorError != null) ok = false;
      _poError = _selectedPoId == null ? 'PO is required' : null;
      if (_poError != null) ok = false;

      final amt = double.tryParse(_amountCtrl.text);
      _amountError = _amountCtrl.text.isEmpty || amt == null || amt <= 0
          ? 'Enter a valid amount > 0'
          : (amt > _poRemainingAmount
              ? 'Amount exceeds PO remaining (${ApService.fmtAmount(_poRemainingAmount)})'
              : null);
      if (_amountError != null) ok = false;

      _creditAccountError = _selectedCreditAccountId == null ? 'Credit account is required' : null;
      if (_creditAccountError != null) ok = false;
    });
    return ok;
  }

  Future<void> _submit({required bool postImmediately}) async {
    if (!_validate()) {
      _msg('Please fill all required fields', isError: true);
      return;
    }

    final amount = double.parse(_amountCtrl.text);
    final modeLabel = postImmediately ? 'Create & Post' : 'Save as Draft';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$modeLabel'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _confirmRow('Amount', '\$${ApService.fmtAmount(amount)}'),
          _confirmRow('Vendor', _selectedVendorName ?? ''),
          _confirmRow('PO', _selectedPoData?['po_number']?.toString() ?? ''),
          _confirmRow('PO Remaining', '\$${ApService.fmtAmount(_poRemainingAmount)}'),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Journal Entry:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Dr  AP Down Payment  \$${ApService.fmtAmount(amount)}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
          Text('Cr  Selected Account  \$${ApService.fmtAmount(amount)}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm & Post')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      final data = {
        'vendor_id': _selectedVendorId,
        'po_id': _selectedPoId,
        'amount': amount,
        'currency': _currency,
        'credit_account_id': _selectedCreditAccountId,
        'post_immediately': postImmediately,
        'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : 'Vendor down payment',
        'reference_no': _refCtrl.text,
      };
      final dp = await widget.apService.createDownPayment(data);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => DPVoucherScreen(
            authService: widget.authService,
            apService: widget.apService,
            downPayment: dp,
          ),
        ));
      }
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Down Payment')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Info Banner ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dr: AP Down Payment (Special GL Indicator A)\nCr: Selected Account\n'
                        'AP_DP is a reconciliation account allowing special GL posting.',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Vendor Selection Card ──
                _sectionLabel('VENDOR *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedVendorId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Select vendor',
                    errorText: _vendorError,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  isExpanded: true,
                  items: _vendors.map((v) => DropdownMenuItem(
                    value: v['id']?.toString(),
                    child: Text('${v['vendor_code']} - ${v['name']}', style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: _onVendorChanged,
                ),
                const SizedBox(height: 20),

                // ── PO Selection Card ──
                _sectionLabel('PURCHASE ORDER *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedPoId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: _selectedVendorId == null ? 'Select vendor first' : 'Select PO',
                    errorText: _poError,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  isExpanded: true,
                  items: _filteredPOs().map((po) {
                    final remaining = _calcPoRemaining(po);
                    final total = (po['total_amount'] as num?)?.toDouble() ?? 0;
                    return DropdownMenuItem(
                      value: po['id']?.toString(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(po['po_number'] ?? '', style: const TextStyle(fontSize: 13)),
                        Text('Total: \$${ApService.fmtAmount(total)}  |  Open: \$${ApService.fmtAmount(remaining)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ]),
                    );
                  }).toList(),
                  onChanged: _onPoChanged,
                ),

                // ── PO Summary Card ──
                if (_selectedPoData != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PO Summary',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                      const SizedBox(height: 8),
                      _summaryRow('Total Amount', '\$${ApService.fmtAmount((_selectedPoData!['total_amount'] as num?)?.toDouble() ?? 0)}'),
                      _summaryRow('Open for Invoice', '\$${ApService.fmtAmount(_poRemainingAmount)}',
                          valueColor: Colors.orange.shade700),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(children: [
                          Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 6),
                          Text('Max DP amount: \$${ApService.fmtAmount(_poRemainingAmount)}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.amber.shade800)),
                        ]),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Amount ──
                _sectionLabel('AMOUNT *'),
                const SizedBox(height: 6),
                Row(children: [
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      items: ['USD', 'EUR', 'CNY', 'JPY', 'GBP'].map((c) => DropdownMenuItem(
                        value: c, child: Text(c, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: '0.00',
                        errorText: _amountError,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => _amountError = null),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Credit Account ──
                _sectionLabel('CREDIT ACCOUNT (Cr) *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedCreditAccountId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Select account to credit',
                    errorText: _creditAccountError,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  isExpanded: true,
                  items: _creditAccounts.where((a) => a.isLeaf).map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.code} - ${a.name}',
                        style: TextStyle(fontSize: 12, color: AccountModel.typeColor(a.type))),
                  )).toList(),
                  onChanged: (v) {
                    setState(() { _selectedCreditAccountId = v; _creditAccountError = null; });
                  },
                ),
                const SizedBox(height: 20),

                // ── Optional Fields ──
                _sectionLabel('DESCRIPTION'),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Vendor down payment (optional)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _sectionLabel('REFERENCE NO.'),
                const SizedBox(height: 6),
                TextField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'External reference (optional)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Journal Entry Preview ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.account_balance, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text('Journal Entry Preview',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                    ]),
                    const Divider(height: 16),
                    _jeLine('Dr  AP Down Payment (Special GL: A)', amount, isDebit: true),
                    const SizedBox(height: 4),
                    _jeLine('Cr  Selected Account', amount, isDebit: false),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Action Buttons ──
                if (_submitting)
                  const Center(child: CircularProgressIndicator())
                else ...[                   
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save as Draft'),
                        onPressed: () => _submit(postImmediately: false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Post & Create'),
                        onPressed: () => _submit(postImmediately: true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 20),
              ]),
            ),
        ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.grey.shade600, letterSpacing: 0.8));
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.blue.shade800))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor)),
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
