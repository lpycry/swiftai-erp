import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';

class VendorFormScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  final VendorModel? vendor;
  const VendorFormScreen({super.key, required this.authService, required this.purchaseService, this.vendor});

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _deleting = false;
  bool _loadingAccounts = true;

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _contactPersonCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _leadTimeCtrl;
  late final TextEditingController _paymentTermsCtrl;
  String _currency = 'USD';
  String? _reconciliationAccountId;
  List<Map<String, dynamic>> _reconAccounts = [];

  bool get isEdit => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _codeCtrl = TextEditingController(text: v?.vendorCode ?? '');
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _taxCtrl = TextEditingController(text: v?.taxNumber ?? '');
    _addressCtrl = TextEditingController(text: v?.address ?? '');
    _contactPersonCtrl = TextEditingController(text: v?.contactPerson ?? '');
    _contactEmailCtrl = TextEditingController(text: v?.contactEmail ?? '');
    _contactPhoneCtrl = TextEditingController(text: v?.contactPhone ?? '');
    _leadTimeCtrl = TextEditingController(text: v?.leadTimeDays.toString() ?? '');
    _paymentTermsCtrl = TextEditingController(text: v?.paymentTerms ?? 'Net 30');
    _currency = v?.currency ?? 'USD';
    _reconciliationAccountId = v?.reconciliationAccountId;
    _loadReconAccounts();
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose(); _taxCtrl.dispose();
    _addressCtrl.dispose(); _contactPersonCtrl.dispose();
    _contactEmailCtrl.dispose(); _contactPhoneCtrl.dispose();
    _leadTimeCtrl.dispose(); _paymentTermsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReconAccounts() async {
    try {
      _reconAccounts = await widget.purchaseService.listVendorReconciliationAccounts();
    } catch (_) {
      _reconAccounts = [];
    }
    if (mounted) setState(() => _loadingAccounts = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'vendor_code': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'tax_number': _taxCtrl.text.trim(),
        'currency': _currency,
        'payment_terms': _paymentTermsCtrl.text.trim(),
        'lead_time_days': int.tryParse(_leadTimeCtrl.text) ?? 0,
        'address': _addressCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
      };

      // Only send if a reconciliation account was actually selected
      if (_reconciliationAccountId != null && _reconciliationAccountId!.isNotEmpty) {
        data['reconciliation_account_id'] = _reconciliationAccountId;
      }

      if (isEdit) {
        await widget.purchaseService.updateVendor(widget.vendor!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vendor updated'), backgroundColor: Colors.green),
          );
        }
      } else {
        await widget.purchaseService.createVendor(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vendor created'), backgroundColor: Colors.green),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteVendor() async {
    final v = widget.vendor;
    if (v == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete "${v.name}" (${v.vendorCode})?\n\n'
            'This action cannot be undone. Vendors with existing purchase orders, receipts, or invoices cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await widget.purchaseService.deleteVendor(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor deleted'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Vendor' : 'New Vendor')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Code & Name
            Row(children: [
              Expanded(child: TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Vendor Code *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Vendor Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 16),
            // Tax & Currency
            Row(children: [
              Expanded(child: TextFormField(
                controller: _taxCtrl,
                decoration: const InputDecoration(labelText: 'Tax Number'),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: ['USD', 'EUR', 'GBP', 'CNY', 'JPY', 'HKD', 'SGD'].map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'USD'),
              )),
            ]),
            const SizedBox(height: 16),
            // Payment Terms & Lead Time
            Row(children: [
              Expanded(child: TextFormField(
                controller: _paymentTermsCtrl,
                decoration: const InputDecoration(labelText: 'Payment Terms'),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _leadTimeCtrl,
                decoration: const InputDecoration(labelText: 'Lead Time (days)'),
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 16),
            // ── Reconciliation Account (must be a dropdown, user selects only) ──
            _loadingAccounts
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ))
                : DropdownButtonFormField<String>(
                    value: _reconciliationAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Reconciliation Account',
                      hintText: 'Select vendor reconciliation account',
                      helperText: 'Used for auto GL posting during invoice verification',
                      helperMaxLines: 2,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('None (no auto GL posting)')),
                      ..._reconAccounts.map((a) {
                        final code = a['account_code']?.toString() ?? '';
                        final name = a['account_name']?.toString() ?? '';
                        return DropdownMenuItem(
                          value: a['id']?.toString(),
                          child: Text('$code - $name', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _reconciliationAccountId = v),
                  ),
            const SizedBox(height: 16),
            // Contact info
            TextFormField(
              controller: _contactPersonCtrl,
              decoration: const InputDecoration(labelText: 'Contact Person'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _contactEmailCtrl,
                decoration: const InputDecoration(labelText: 'Contact Email'),
                keyboardType: TextInputType.emailAddress,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _contactPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone'),
                keyboardType: TextInputType.phone,
              )),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              // AI recommendation hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: Colors.indigo.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Vendors with good data quality get higher AI ratings for smart recommendations',
                      style: TextStyle(fontSize: 12, color: Colors.indigo.shade700))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            // Save button
            ElevatedButton(
              onPressed: (_saving || _deleting) ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Update Vendor' : 'Create Vendor'),
            ),
            // Delete button (edit mode only)
            if (isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: (_saving || _deleting) ? null : _deleteVendor,
                icon: _deleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : const Icon(Icons.delete_outline, size: 18),
                label: Text(_deleting ? 'Deleting...' : 'Delete Vendor'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
