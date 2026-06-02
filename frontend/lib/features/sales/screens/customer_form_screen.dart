import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/sales/services/sales_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final AuthService authService;
  final SalesService salesService;
  final Map<String, dynamic>? customer;
  const CustomerFormScreen({super.key, required this.authService, required this.salesService, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _deleting = false;

  late final TextEditingController _codeCtrl, _nameCtrl, _taxNumberCtrl;
  late final TextEditingController _contactPersonCtrl, _emailCtrl, _phoneCtrl;
  late final TextEditingController _paymentTermsCtrl;
  late final TextEditingController _exemptionCertCtrl, _exemptReasonCtrl;
  late final TextEditingController _billStreetCtrl, _billCityCtrl, _billStateCtrl, _billZipCtrl, _billCountryCtrl;
  late final TextEditingController _shipStreetCtrl, _shipCityCtrl, _shipStateCtrl, _shipZipCtrl, _shipCountryCtrl;

  String _customerType = 'Corporate', _currency = 'USD', _status = 'Active';
  bool _isTaxExempt = false;
  DateTime _exemptStartDate = DateTime.now();
  DateTime? _exemptEndDate;
  String _defaultTaxJurisdictionId = '';
  List<dynamic> _taxJurisdictions = [];
  bool _loadingJurisdictions = true;
  List<dynamic> _certificates = [];

  bool get isEdit => widget.customer != null;
  String get _customerId => widget.customer?['id']?.toString() ?? '';
  String get _token => widget.authService.accessToken ?? '';

  @override void initState() {
    super.initState();
    final c = widget.customer;
    _codeCtrl = TextEditingController(text: c?['customer_code']?.toString() ?? '');
    _nameCtrl = TextEditingController(text: c?['name']?.toString() ?? '');
    _taxNumberCtrl = TextEditingController(text: c?['tax_number']?.toString() ?? '');
    _contactPersonCtrl = TextEditingController(text: c?['contact_person']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: c?['contact_email']?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: c?['contact_phone']?.toString() ?? '');
    _paymentTermsCtrl = TextEditingController(text: c?['payment_terms']?.toString() ?? 'Net 30');
    _exemptionCertCtrl = TextEditingController(text: c?['tax_exemption_cert']?.toString() ?? '');
    _exemptReasonCtrl = TextEditingController(text: c?['tax_exempt_reason']?.toString() ?? '');
    _billStreetCtrl = TextEditingController(text: c?['billing_street']?.toString() ?? '');
    _billCityCtrl   = TextEditingController(text: c?['billing_city']?.toString() ?? '');
    _billStateCtrl  = TextEditingController(text: c?['billing_state']?.toString() ?? '');
    _billZipCtrl    = TextEditingController(text: c?['billing_zip']?.toString() ?? '');
    _billCountryCtrl= TextEditingController(text: c?['billing_country']?.toString() ?? 'US');
    _shipStreetCtrl = TextEditingController(text: c?['shipping_street']?.toString() ?? '');
    _shipCityCtrl   = TextEditingController(text: c?['shipping_city']?.toString() ?? '');
    _shipStateCtrl  = TextEditingController(text: c?['shipping_state']?.toString() ?? '');
    _shipZipCtrl    = TextEditingController(text: c?['shipping_zip']?.toString() ?? '');
    _shipCountryCtrl= TextEditingController(text: c?['shipping_country']?.toString() ?? 'US');
    _customerType = c?['customer_type']?.toString() ?? 'Corporate';
    _currency = c?['currency']?.toString() ?? 'USD';
    _status = c?['status']?.toString() ?? 'Active';
    _isTaxExempt = c?['is_tax_exempt'] == true;
    final startStr = c?['tax_exempt_start_date']?.toString();
    if (startStr != null && startStr.isNotEmpty) { _exemptStartDate = DateTime.tryParse(startStr) ?? DateTime.now(); }
    final endStr = c?['tax_exempt_end_date']?.toString();
    if (endStr != null && endStr.isNotEmpty) { _exemptEndDate = DateTime.tryParse(endStr); }
    _defaultTaxJurisdictionId = c?['default_tax_jurisdiction_id']?.toString() ?? '';
    if (c != null && c['certificates'] != null) { _certificates = c['certificates'] as List<dynamic>; }
    _loadTaxJurisdictions();
  }

  @override void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose(); _taxNumberCtrl.dispose();
    _contactPersonCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _paymentTermsCtrl.dispose(); _exemptionCertCtrl.dispose(); _exemptReasonCtrl.dispose();
    _billStreetCtrl.dispose(); _billCityCtrl.dispose(); _billStateCtrl.dispose();
    _billZipCtrl.dispose(); _billCountryCtrl.dispose();
    _shipStreetCtrl.dispose(); _shipCityCtrl.dispose(); _shipStateCtrl.dispose();
    _shipZipCtrl.dispose(); _shipCountryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTaxJurisdictions() async {
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) { _taxJurisdictions = ((jsonDecode(resp.body)['data'] as List?) ?? []); }
    } catch (_) {}
    if (mounted) setState(() => _loadingJurisdictions = false);
  }

  Future<void> _uploadCertificate(String certType) async {
    if (_customerId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the customer first, then upload certificates.'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final uri = Uri.parse('http://localhost:8080/api/v1/sales/customers/$_customerId/certificates');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['cert_type'] = certType;
      // Try file path first (desktop), fallback to bytes (web)
      String? filePath;
      try { filePath = file.path; } catch (_) {}
      if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: file.name));
      } else if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File data not available'), backgroundColor: Colors.red));
        return;
      }
      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        throw Exception(body['message'] ?? 'Upload failed');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certificate uploaded'), backgroundColor: Colors.green));
      _loadCertificates();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadCertificates() async {
    if (_customerId.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:8080/api/v1/sales/customers/$_customerId/certificates'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) { setState(() => _certificates = ((jsonDecode(resp.body)['data'] as List?) ?? [])); }
    } catch (_) {}
  }

  Future<void> _deleteCertificate(String certId) async {
    try {
      final resp = await http.delete(Uri.parse('http://localhost:8080/api/v1/sales/customers/$_customerId/certificates/$certId'), headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        throw Exception(body['message'] ?? 'Delete failed');
      }
      _loadCertificates();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'customer_code': _codeCtrl.text.trim(), 'name': _nameCtrl.text.trim(),
        'tax_number': _taxNumberCtrl.text.trim(), 'customer_type': _customerType,
        'currency': _currency, 'payment_terms': _paymentTermsCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim(), 'contact_email': _emailCtrl.text.trim(), 'contact_phone': _phoneCtrl.text.trim(),
        'billing_street': _billStreetCtrl.text.trim(), 'billing_city': _billCityCtrl.text.trim(), 'billing_state': _billStateCtrl.text.trim(),
        'billing_zip': _billZipCtrl.text.trim(), 'billing_country': _billCountryCtrl.text.trim(),
        'shipping_street': _shipStreetCtrl.text.trim(), 'shipping_city': _shipCityCtrl.text.trim(), 'shipping_state': _shipStateCtrl.text.trim(),
        'shipping_zip': _shipZipCtrl.text.trim(), 'shipping_country': _shipCountryCtrl.text.trim(),
        'status': _status, 'is_tax_exempt': _isTaxExempt,
        'default_tax_jurisdiction_id': _defaultTaxJurisdictionId.isEmpty ? null : _defaultTaxJurisdictionId,
      };
      // Always send tax exemption fields
      if (_isTaxExempt) {
        data['tax_exemption_cert'] = _exemptionCertCtrl.text.trim();
        data['tax_exempt_reason'] = _exemptReasonCtrl.text.trim();
        data['tax_exempt_start_date'] = '${_exemptStartDate.year}-${_exemptStartDate.month.toString().padLeft(2,'0')}-${_exemptStartDate.day.toString().padLeft(2,'0')}';
        data['tax_exempt_end_date'] = _exemptEndDate != null
          ? '${_exemptEndDate!.year}-${_exemptEndDate!.month.toString().padLeft(2,'0')}-${_exemptEndDate!.day.toString().padLeft(2,'0')}'
          : null;
      } else {
        // Clear all tax exemption fields when toggled off
        data['tax_exemption_cert'] = '';
        data['tax_exempt_reason'] = '';
        data['tax_exempt_start_date'] = null;
        data['tax_exempt_end_date'] = null;
      }

      if (isEdit) {
        await widget.salesService.updateCustomer(_customerId, data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer updated'), backgroundColor: Colors.green));
        if (mounted) Navigator.pop(context, true);
      } else {
        final result = await widget.salesService.createCustomer(data);
        if (mounted) {
          // Replace with edit screen so user can upload certificates
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
            CustomerFormScreen(authService: widget.authService, salesService: widget.salesService, customer: result)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCustomer() async {
    if (_customerId.isEmpty) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Customer'), content: Text('Delete "${widget.customer!['name']}" (${widget.customer!['customer_code']})?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'))],
    ));
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await widget.salesService.deleteCustomer(_customerId);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted'), backgroundColor: Colors.green)); Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _deleting = false); }
  }

  Widget _sectionHeader(String t) => Row(children: [Container(width: 3, height: 16, color: Colors.indigo, margin: const EdgeInsets.only(right: 8)), Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.indigo))]);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Customer' : 'New Customer'),
          bottom: const TabBar(isScrollable: false, tabs: [
            Tab(icon: Icon(Icons.info_outline, size: 16), child: Text('General', style: TextStyle(fontSize: 12))),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 16), child: Text('Tax Exemption', style: TextStyle(fontSize: 12))),
          ]),
        ),
        body: Form(
          key: _formKey,
          child: Column(children: [
            Expanded(child: TabBarView(
              children: [
                // Tab 0: General (Basic + Address + Certificates + buttons)
                ListView(padding: const EdgeInsets.all(20), children: [
                  _buildBasicFields(), const SizedBox(height: 24),
                  _buildAddressFields(), const SizedBox(height: 24),
                  _buildCertFields(), const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_saving || _deleting) ? null : _save,
                    child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update Customer' : 'Create Customer'),
                  ),
                  if (isEdit) ...[const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: (_saving || _deleting) ? null : _deleteCustomer,
                      icon: _deleting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.delete_outline, size: 18),
                      label: Text(_deleting ? 'Deleting...' : 'Delete'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade300)),
                    ),
                  ],
                ]),
                // Tab 1: Tax Exemption (full page)
                ListView(padding: const EdgeInsets.all(20), children: [_buildTaxFields()]),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildBasicFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionHeader('Basic Data'), const SizedBox(height: 12),
    Row(children: [Expanded(child: TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Customer Code *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, style: const TextStyle(fontFamily: 'monospace'))), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null))]),
    const SizedBox(height: 16),
    _sectionHeader('Tax & Classification'), const SizedBox(height: 12),
    Row(children: [Expanded(child: TextFormField(controller: _taxNumberCtrl, decoration: const InputDecoration(labelText: 'Tax Number / EIN'))), const SizedBox(width: 12), Expanded(child: DropdownButtonFormField<String>(value: _customerType, decoration: const InputDecoration(labelText: 'Customer Type'), items: const [DropdownMenuItem(value: 'Individual', child: Text('Individual')), DropdownMenuItem(value: 'Corporate', child: Text('Corporate')), DropdownMenuItem(value: 'Government', child: Text('Government')), DropdownMenuItem(value: 'Non-Profit', child: Text('Non-Profit'))], onChanged: (v) => setState(() => _customerType = v ?? 'Corporate')))]),
    const SizedBox(height: 16),
    _sectionHeader('Payment & Currency'), const SizedBox(height: 12),
    Row(children: [Expanded(child: DropdownButtonFormField<String>(value: _currency, decoration: const InputDecoration(labelText: 'Currency'), items: ['USD','EUR','GBP','CNY','JPY','HKD','SGD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _currency = v ?? 'USD'))), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _paymentTermsCtrl, decoration: const InputDecoration(labelText: 'Payment Terms')))]),
    const SizedBox(height: 16),
    _sectionHeader('Account Status'), const SizedBox(height: 12),
    DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'Active', child: Text('Active')), DropdownMenuItem(value: 'Inactive', child: Text('Inactive')), DropdownMenuItem(value: 'Blocked', child: Text('Blocked'))], onChanged: (v) => setState(() => _status = v ?? 'Active')),
    const SizedBox(height: 16),
    _sectionHeader('Contact'), const SizedBox(height: 12),
    TextFormField(controller: _contactPersonCtrl, decoration: const InputDecoration(labelText: 'Contact Person')), const SizedBox(height: 12),
    Row(children: [
      Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress,
        validator: (v) { if (v != null && v.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Invalid email'; return null; })),
      const SizedBox(width: 12),
      Expanded(child: TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone)),
    ]),
    const SizedBox(height: 40),
  ]);

  Widget _buildAddressFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionHeader('Billing Address'), const SizedBox(height: 12),
    TextFormField(controller: _billStreetCtrl, decoration: const InputDecoration(labelText: 'Address', hintText: 'Street address')), const SizedBox(height: 12),
    Row(children: [Expanded(flex: 3, child: TextFormField(controller: _billCityCtrl, decoration: const InputDecoration(labelText: 'City'))), const SizedBox(width: 12), Expanded(flex: 2, child: TextFormField(controller: _billStateCtrl, decoration: const InputDecoration(labelText: 'State')))]),
    const SizedBox(height: 12),
    Row(children: [Expanded(flex: 2, child: TextFormField(controller: _billZipCtrl, decoration: const InputDecoration(labelText: 'ZIP Code'))), const SizedBox(width: 12), Expanded(flex: 3, child: TextFormField(controller: _billCountryCtrl, decoration: const InputDecoration(labelText: 'Country')))]),
    const SizedBox(height: 24),
    _sectionHeader('Shipping Address'), const SizedBox(height: 12),
    TextFormField(controller: _shipStreetCtrl, decoration: const InputDecoration(labelText: 'Address', hintText: 'Street address')), const SizedBox(height: 12),
    Row(children: [Expanded(flex: 3, child: TextFormField(controller: _shipCityCtrl, decoration: const InputDecoration(labelText: 'City'))), const SizedBox(width: 12), Expanded(flex: 2, child: TextFormField(controller: _shipStateCtrl, decoration: const InputDecoration(labelText: 'State')))]),
    const SizedBox(height: 12),
    Row(children: [Expanded(flex: 2, child: TextFormField(controller: _shipZipCtrl, decoration: const InputDecoration(labelText: 'ZIP Code'))), const SizedBox(width: 12), Expanded(flex: 3, child: TextFormField(controller: _shipCountryCtrl, decoration: const InputDecoration(labelText: 'Country')))]),
    const SizedBox(height: 40),
  ]);

  Widget _buildTaxFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionHeader('Tax Exemption'), const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _isTaxExempt ? Colors.green.withValues(alpha: 0.04) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: _isTaxExempt ? Colors.green.withValues(alpha: 0.2) : Colors.grey.shade200)),
      child: Column(children: [
        Row(children: [const Text('Tax Exempt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const Spacer(), Switch(
          value: _isTaxExempt,
          onChanged: (v) => setState(() { _isTaxExempt = v; if (!v) _exemptEndDate = null; }),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]),
        if (_isTaxExempt) ...[
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextFormField(controller: _exemptionCertCtrl, decoration: const InputDecoration(labelText: 'Exemption Certificate #', isDense: true, hintText: 'e.g. Resale Cert #12345'), style: const TextStyle(fontSize: 12))), const SizedBox(width: 8), Expanded(child: TextFormField(controller: _exemptReasonCtrl, decoration: const InputDecoration(labelText: 'Exemption Reason', isDense: true, hintText: 'RESALE, GOV, NON_PROFIT'), style: const TextStyle(fontSize: 12)))]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _exemptStartDate, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _exemptStartDate = d); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Date', isDense: true), child: Text('${_exemptStartDate.year}-${_exemptStartDate.month.toString().padLeft(2,'0')}-${_exemptStartDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))))),
            const SizedBox(width: 8),
            Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: _exemptEndDate ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2035)); if (d != null) setState(() => _exemptEndDate = d); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'End Date', isDense: true), child: Builder(builder: (ctx) { final d = _exemptEndDate; return Text(d == null ? 'No end date' : '${d!.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')); })))),
          ]),
        ],
      ]),
    ),
    const SizedBox(height: 16),
    if (!_loadingJurisdictions) ...[
      DropdownButtonFormField<String>(
        value: _defaultTaxJurisdictionId.isEmpty ? '' : _defaultTaxJurisdictionId,
        decoration: const InputDecoration(labelText: 'Default Tax Jurisdiction', hintText: 'Optional', isDense: true),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('None', style: TextStyle(fontSize: 12))),
          ..._taxJurisdictions.map((j) {
            final state = j['state']?.toString() ?? ''; final county = j['county']?.toString() ?? '';
            final rate = ((j['tax_rate'] as num?)?.toDouble() ?? 0) * 100;
            return DropdownMenuItem(value: j['id']?.toString(), child: Text('$state - ${county.isNotEmpty ? "$county " : ""}(${rate.toStringAsFixed(2)}%)', style: const TextStyle(fontSize: 12)));
          }),
        ],
        onChanged: (v) => setState(() => _defaultTaxJurisdictionId = v ?? ''),
        style: const TextStyle(fontSize: 12),
      ),
    ],
    const SizedBox(height: 40),
  ]);

  Widget _buildCertFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionHeader('Exemption Certificates'), const SizedBox(height: 12),
    if (_customerId.isNotEmpty) ...['TAX_EXEMPT', 'RESALE', 'OTHER'].map((ct) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(icon: const Icon(Icons.upload_file, size: 18), label: Text('Upload $ct Certificate'), onPressed: () => _uploadCertificate(ct)),
    )),
    const SizedBox(height: 16),
    if (_certificates.isEmpty) ...[
      Center(child: Column(children: [Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300), const SizedBox(height: 8), Text('No certificates uploaded', style: TextStyle(color: Colors.grey.shade500))])),
    ] else ...[
      ..._certificates.map((cert) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: Icon(Icons.description, color: Colors.teal),
        title: Text(cert['file_name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
        subtitle: Text('${cert['cert_type']} · ${cert['file_size']} bytes', style: const TextStyle(fontSize: 10)),
        trailing: IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18), onPressed: () => _deleteCertificate(cert['id'].toString())),
      ))),
    ],
    if (_customerId.isEmpty)
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [Icon(Icons.info_outline, size: 16, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Save the customer first, then upload certificates.', style: TextStyle(fontSize: 12)))])),
    const SizedBox(height: 40),
  ]);
}
