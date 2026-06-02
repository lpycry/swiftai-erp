import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class VendorPaymentScreen extends StatefulWidget {
  final AuthService authService;
  final ApService apService;
  final String? preselectedVendorId;
  const VendorPaymentScreen({super.key, required this.authService, required this.apService, this.preselectedVendorId});
  @override State<VendorPaymentScreen> createState() => _VendorPaymentScreenState();
}

class _VendorPaymentScreenState extends State<VendorPaymentScreen> {
  bool _loading = false;
  bool _submitting = false;

  List<Map<String, dynamic>> _vendors = [];
  List<AccountModel> _bankAccounts = [];
  List<OpenItemModel> _openItems = [];

  String? _selectedVendorId;
  String? _selectedBankAccountId;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _vendorError;
  String? _amountError;
  String? _bankError;

  bool _autoApplied = false;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      if (widget.preselectedVendorId != null) {
        _onVendorChanged(widget.preselectedVendorId);
      }
    });
  }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final glService = GlService(_token);
      _bankAccounts = await glService.getAccounts();

      final vResp = await httpGet('purchase/vendors?status=ACTIVE');
      if (vResp.statusCode < 400) {
        final body = jsonDecode(vResp.body);
        _vendors = ((body['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<http.Response> httpGet(String path) async {
    final uri = Uri.parse('http://localhost:8080/api/v1/$path');
    return await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    });
  }

  Future<void> _onVendorChanged(String? id) async {
    setState(() {
      _selectedVendorId = id;
      _openItems = [];
      _autoApplied = false;
    });
    if (id == null) return;

    try {
      final items = await widget.apService.getVendorOpenItems(id);
      _applyAutoSelection(items);
      if (mounted) {
        setState(() {
          _openItems = items;
          _autoApplied = true;
        });
      }
    } catch (e) {
      if (mounted) _msg('Failed to load open items: $e', isError: true);
    }
  }

  void _applyAutoSelection(List<OpenItemModel> items) {
    // Always auto-select all down payments (they appear as negative, reducing owed amount)
    for (final item in items) {
      if (item.isDownPayment) item.selected = true;
    }
    // Then auto-select invoices until payment amount is covered
    double remaining = double.tryParse(_amountCtrl.text) ?? 0;
    for (final item in items) {
      if (!item.isDownPayment && remaining > 0.01) {
        item.selected = true;
        remaining -= item.openAmount;
      }
    }
    _recalcTotal();
  }

  void _recalcTotal() {
    // triggers setState → rebuild computes net payable inline
  }

  void _toggleItem(int index) {
    setState(() {
      _openItems[index].selected = !_openItems[index].selected;
      _recalcTotal();
    });
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _vendorError = _selectedVendorId == null ? 'Vendor is required' : null;
      if (_vendorError != null) ok = false;
      _bankError = _selectedBankAccountId == null ? 'Bank account is required' : null;
      if (_bankError != null) ok = false;

      final amt = double.tryParse(_amountCtrl.text);
      final netPayable = _openItems
          .where((o) => o.selected)
          .fold<double>(0.0, (s, o) => s + (o.isDownPayment ? -o.openAmount : o.openAmount));
      _amountError = _amountCtrl.text.isEmpty || amt == null || amt <= 0
          ? 'Enter a valid amount > 0'
          : (amt > netPayable + 0.01
                ? 'Amount exceeds net payable (${ApService.fmtAmount(netPayable)})'
                : null);
      if (_amountError != null) ok = false;
    });
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pay \$${ApService.fmtAmount(double.parse(_amountCtrl.text))}'),
          const SizedBox(height: 8),
          Text('${_openItems.where((o) => o.selected).length} items will be cleared.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Execute Payment')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      final selectedIds = _openItems.where((o) => o.selected).map((o) => o.id).toList();
      await widget.apService.createVendorPayment({
        'vendor_id': _selectedVendorId,
        'org_id': _vendors.firstWhere((v) => v['id']?.toString() == _selectedVendorId)['org_id'] ?? _selectedVendorId,
        'bank_account_id': _selectedBankAccountId,
        'payment_amount': double.parse(_amountCtrl.text),
        'selected_item_ids': selectedIds,
        'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : 'Vendor payment',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment processed successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _msg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _fmtAmount(double v) => v >= 0
      ? '\$${ApService.fmtAmount(v)}'
      : '(\$${ApService.fmtAmount(-v)})';

  @override
  Widget build(BuildContext context) {
    final selectedItems = _openItems.where((o) => o.selected).toList();
    final dpTotal = selectedItems.where((o) => o.isDownPayment).fold<double>(0, (s, o) => s + o.openAmount);
    final invTotal = selectedItems.where((o) => !o.isDownPayment).fold<double>(0, (s, o) => s + o.openAmount);
    final netTotal = invTotal - dpTotal; // DPs reduce payable

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Vendor ──
                _label('VENDOR *'),
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

                // ── Bank Account ──
                _label('PAYMENT BANK ACCOUNT *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedBankAccountId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Select bank account',
                    errorText: _bankError,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  isExpanded: true,
                  items: _bankAccounts.where((a) => a.isLeaf).map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.code} - ${a.name}', style: TextStyle(fontSize: 12, color: AccountModel.typeColor(a.type))),
                  )).toList(),
                  onChanged: (v) => setState(() { _selectedBankAccountId = v; _bankError = null; }),
                ),
                const SizedBox(height: 20),

                // ── Open Items ──
                _label('OPEN ITEMS (${_openItems.length})'),
                if (_autoApplied)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Down payments auto-selected for prepayment deduction',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade600)),
                  ),
                const SizedBox(height: 6),
                if (_openItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text('Select a vendor to load open items',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                  )
                else ...[
                  // Column headers
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      const SizedBox(width: 20),
                      const Expanded(flex: 3, child: Text('Doc #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
                      Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
                      Expanded(flex: 2, child: Text('Open', textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
                    ]),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _openItems.length,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => _toggleItem(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                          color: _openItems[i].selected ? Colors.blue.shade50 : null,
                        ),
                        child: Row(children: [
                          Icon(
                            _openItems[i].selected ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                            color: _openItems[i].selected ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(flex: 3, child: Text(_openItems[i].documentNo,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                  color: _openItems[i].isDownPayment ? Colors.purple.shade700 : null),
                              overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 2, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _openItems[i].isDownPayment
                                  ? Colors.purple.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(_openItems[i].typeLabel,
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                                    color: _openItems[i].isDownPayment ? Colors.purple : Colors.orange),
                                textAlign: TextAlign.center),
                          )),
                          Expanded(flex: 2, child: Text(
                              _openItems[i].isDownPayment
                                  ? '(\$${ApService.fmtAmount(_openItems[i].openAmount)})'
                                  : '\$${ApService.fmtAmount(_openItems[i].openAmount)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: _openItems[i].isDownPayment ? Colors.purple.shade700 : Colors.orange.shade700))),
                        ]),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Summary Card ──
                if (selectedItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Selection Summary',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
                      const Divider(height: 12),
                      _sumRow('Down Payments (prepayment)', _fmtAmount(-dpTotal), Colors.purple),
                      const SizedBox(height: 2),
                      _sumRow('Invoices', _fmtAmount(invTotal), Colors.orange),
                      const SizedBox(height: 2),
                      _sumRow('Net Payable', _fmtAmount(netTotal), Colors.blue.shade700, bold: true),
                    ]),
                  ),

                const SizedBox(height: 20),

                // ── Payment Amount ──
                _label('PAYMENT AMOUNT *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: '0.00',
                    errorText: _amountError,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    setState(() => _amountError = null);
                    // Client-side re-selection only — no API call
                    _applyAutoSelection(_openItems);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 20),

                // ── Description ──
                _label('DESCRIPTION'),
                const SizedBox(height: 6),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Payment description (optional)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Action Buttons ──
                if (_submitting)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calculate, size: 18),
                      label: const Text('Calculate Balance'),
                      onPressed: () {
                        final diff = (double.tryParse(_amountCtrl.text) ?? 0) - netTotal;
                        if (diff > 0.01) {
                          _msg('Payment amount exceeds net payable by \$${ApService.fmtAmount(diff)}.',
                              isError: true);
                        } else if (diff < -0.01) {
                          _msg('Net payable (\$${ApService.fmtAmount(netTotal)}) exceeds payment by \$${ApService.fmtAmount(-diff)}.',
                              isError: false);
                        } else {
                          _msg('Balance matches: \$${ApService.fmtAmount(netTotal)}', isError: false);
                        }
                      },
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Execute Payment'),
                      onPressed: _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.grey.shade600, letterSpacing: 0.8));
  }

  Widget _sumRow(String label, String value, Color color, {bool bold = false}) {
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    ]);
  }
}
