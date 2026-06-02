import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/settings/services/finance_settings_service.dart';

class FinanceSettingsScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService orgService;
  final FinanceSettingsService financeSettingsService;
  const FinanceSettingsScreen({
    super.key,
    required this.authService,
    required this.glService,
    required this.orgService,
    required this.financeSettingsService,
  });

  @override
  State<FinanceSettingsScreen> createState() => _FinanceSettingsScreenState();
}

class _FinanceSettingsScreenState extends State<FinanceSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Accounting Periods'),
            Tab(text: 'Chart of Accounts'),
            Tab(text: 'Payment Terms'),
            Tab(text: 'Incoterms'),
            Tab(text: 'Account Types'),

          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PeriodsTab(authService: widget.authService, orgService: widget.orgService),
          _CoaTab(authService: widget.authService, glService: widget.glService, orgService: widget.orgService),
          _PaymentTermsTab(authService: widget.authService, svc: widget.financeSettingsService),
          _IncotermsTab(authService: widget.authService, svc: widget.financeSettingsService),
          _ReconAccountsTab(authService: widget.authService, orgService: widget.orgService, svc: widget.financeSettingsService),

        ],
      ),
    );

  }
}

// ════════════════════════════════════════════════════════════
//  TAB 1: ACCOUNTING PERIODS (moved from periods_screen.dart)
// ════════════════════════════════════════════════════════════

class _PeriodsTab extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;
  const _PeriodsTab({required this.authService, required this.orgService});

  @override
  State<_PeriodsTab> createState() => _PeriodsTabState();
}

class _PeriodsTabState extends State<_PeriodsTab> {
  List<dynamic> _periods = [];
  List<dynamic> _orgs = [];
  bool _loading = true;
  int _year = DateTime.now().year;
  String? _selectedOrgId; // null = global company code

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authService.accessToken}',
      };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _orgs = await widget.orgService.getOrganizations();
      await _loadPeriods();
    } catch (e) {
      _err('Failed to load: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPeriods() async {
    try {
      final params = <String, String>{'year': '$_year'};
      if (_selectedOrgId != null) params['org_id'] = _selectedOrgId!;
      final uri = Uri.parse('http://localhost:8080/api/v1/periods').replace(queryParameters: params);
      final resp = await http.get(uri, headers: _headers);
      if (resp.statusCode < 400) {
        _periods = (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
      }
    } catch (e) {
      _err('Failed: $e');
    }
  }

  Future<void> _togglePeriod(String id, bool newOpen) async {
    try {
      await http.put(
        Uri.parse('http://localhost:8080/api/v1/periods/$id'),
        headers: _headers,
        body: jsonEncode({'is_open': newOpen}),
      );
      await _loadPeriods();
      _snack(newOpen ? 'Period opened' : 'Period closed',
          newOpen ? AppTheme.successColor : AppTheme.errorColor);
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _generatePeriods() async {
    final yearCtrl = TextEditingController(text: '$_year');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Periods'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Creates 12 monthly periods for the selected year and company.'),
          const SizedBox(height: 12),
          TextField(controller: yearCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year')),
          const SizedBox(height: 8),
          Text(_selectedOrgId != null
              ? 'For company code: ${_orgs.firstWhere((o) => o['id'] == _selectedOrgId)['org_name'] ?? ''}'
              : 'For all companies (global periods)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final body = <String, dynamic>{'year': int.tryParse(yearCtrl.text) ?? _year};
      if (_selectedOrgId != null) body['organization_id'] = _selectedOrgId;
      await http.post(
        Uri.parse('http://localhost:8080/api/v1/periods/generate'),
        headers: _headers,
        body: jsonEncode(body),
      );
      await _loadPeriods();
      _snack('Periods generated', AppTheme.successColor);
    } catch (e) {
      _err('$e');
    }
  }

  void _err(String msg) => _snack(msg, AppTheme.errorColor);
  void _snack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          DropdownButton<int>(
            value: _year, underline: const SizedBox(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            items: List.generate(10, (i) => DateTime.now().year - 3 + i).map((y) =>
                DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
            onChanged: (v) => setState(() { _year = v!; _loadPeriods(); }),
          ),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _selectedOrgId,
            decoration: const InputDecoration(
              labelText: 'Company Code', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Global (All Companies)', style: TextStyle(fontSize: 13))),
              ..._orgs.map((o) => DropdownMenuItem(
                  value: o['id'],
                  child: Text('${o['org_code']} - ${o['org_name']}', style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) => setState(() { _selectedOrgId = v; _loadPeriods(); }),
          )),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Generate', style: TextStyle(fontSize: 13)),
            onPressed: _generatePeriods,
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _periods.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_note, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text('No periods found.', style: TextStyle(color: AppTheme.textMuted)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _periods.length,
                    itemBuilder: (_, i) => _buildPeriodRow(_periods[i]),
                  ),
      ),
    ]);
  }

  Widget _buildPeriodRow(dynamic p) {
    final isOpen = p['is_open'] as bool;
    final isLocked = p['is_locked'] as bool;
    final bool companySpecific = p['organization_id'] != null;
    final dateRange = '${p['start_date']} ~ ${p['end_date']}';

    Color statusColor;
    String statusText;
    if (isLocked) {
      statusColor = AppTheme.textMuted;
      statusText = 'LOCKED';
    } else if (isOpen) {
      statusColor = AppTheme.accentGreen;
      statusText = 'OPEN';
    } else {
      statusColor = AppTheme.errorColor;
      statusText = 'CLOSED';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(children: [
          Container(
            width: 70, padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentGradientStart.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(children: [
              Text('P${p['period_no']}', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentGradientStart)),
              Text('${p['fiscal_year']}', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateRange, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              if (companySpecific)
                Text('Company specific', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          if (!isLocked)
            Switch(value: isOpen, activeThumbColor: AppTheme.accentGreen,
                onChanged: (v) => _togglePeriod(p['id'], v))
          else
            Icon(Icons.lock_outlined, size: 16, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 2: CHART OF ACCOUNTS (with per-company support)
// ════════════════════════════════════════════════════════════

class _CoaTab extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService orgService;
  const _CoaTab({required this.authService, required this.glService, required this.orgService});

  @override
  State<_CoaTab> createState() => _CoaTabState();
}

class _CoaTabState extends State<_CoaTab> {
  List<dynamic> _orgs = [];
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    try {
      _orgs = await widget.orgService.getOrganizations();
    } catch (_) {}
  }

  void _showCoaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initialize Chart of Accounts'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This will replace the entire Chart of Accounts.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Only allowed when no journal entries exist.'),
          const SizedBox(height: 16),
          const Text('Select Company Code:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedOrgId,
            decoration: const InputDecoration(
              labelText: 'Company Code', isDense: true,
              hintText: 'Default (global)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Global (use as default)')),
              ..._orgs.map((o) => DropdownMenuItem(
                  value: o['id'],
                  child: Text('${o['org_code']} - ${o['org_name']}')))
            ],
            onChanged: (v) => setState(() => _selectedOrgId = v),
          ),
          const SizedBox(height: 16),
          if (_orgs.length > 1 && _selectedOrgId == null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Multiple companies detected. Select a company to generate per-company COA, or use Global for all.',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton.icon(icon: const Icon(Icons.account_balance, size: 16), label: const Text('US GAAP'),
              onPressed: () { Navigator.pop(ctx); _executeInit('gaap'); }),
          TextButton.icon(icon: const Icon(Icons.language, size: 16), label: const Text('IFRS'),
              onPressed: () { Navigator.pop(ctx); _executeInit('ifrs'); }),
          TextButton.icon(icon: const Icon(Icons.map, size: 16), label: const Text('China CAS'),
              onPressed: () { Navigator.pop(ctx); _executeInit('china'); }),
        ],
      ),
    );
  }

  Future<void> _executeInit(String coaType) async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final data = <String, dynamic>{'coa_type': coaType};
      if (_selectedOrgId != null) data['organization_id'] = _selectedOrgId;
      await widget.glService.initializeCoa(coaType); // existing API — backend already supports org now
      // We need to call a version that passes org_id — use raw HTTP
      final token = widget.authService.accessToken;
      await http.post(
        Uri.parse('http://localhost:8080/api/v1/gl/initialize-coa'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      if (mounted) {
        Navigator.pop(context);
        _snack('Chart of Accounts initialized successfully', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _snack('Failed: $e', AppTheme.errorColor);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Info card
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_outlined, color: AppTheme.accentBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Chart of Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('GAAP · IFRS · China CAS', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ])),
              ]),
              const SizedBox(height: 16),
              const Text('Initialize or reset the Chart of Accounts for a specific company code or globally.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Available standards:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ...[
                _standardRow('US GAAP', 'Standard for US-based companies (4-digit)'),
                _standardRow('IFRS', 'International Financial Reporting Standards'),
                _standardRow('China CAS', 'China Accounting Standards (4-4-2)'),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Initialize COA'),
                  onPressed: _showCoaDialog,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _standardRow(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(Icons.check_circle, size: 16, color: AppTheme.accentGreen),
        const SizedBox(width: 8),
        Text('$name — ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 3: PAYMENT TERMS CRUD
// ════════════════════════════════════════════════════════════

class _PaymentTermsTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _PaymentTermsTab({required this.authService, required this.svc});

  @override
  State<_PaymentTermsTab> createState() => _PaymentTermsTabState();
}

class _PaymentTermsTabState extends State<_PaymentTermsTab> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await widget.svc.listPaymentTerms();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dueCtrl = TextEditingController(text: '30');
    final discDaysCtrl = TextEditingController(text: '0');
    final discPctCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Payment Term'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code *', hintText: 'NET45')),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', hintText: 'Net 45')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: dueCtrl, decoration: const InputDecoration(labelText: 'Due Days *'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: discDaysCtrl, decoration: const InputDecoration(labelText: 'Discount Days'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: discPctCtrl, decoration: const InputDecoration(labelText: 'Discount %'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.createPaymentTerm({
        'code': codeCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'due_days': int.tryParse(dueCtrl.text) ?? 30,
        'discount_days': int.tryParse(discDaysCtrl.text) ?? 0,
        'discount_pct': double.tryParse(discPctCtrl.text) ?? 0,
      });
      _load();
      _snack('Payment term created', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  void _snack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          const Text('Payment Terms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            onPressed: _create,
          ),
        ]),
      ),
      const Divider(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(child: Text('No payment terms defined', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _PaymentTermCard(
                      data: _items[i],
                      onEdit: (id, data) => _editPaymentTerm(id, data),
                      onDelete: (id) => _deletePaymentTerm(id),
                    ),
                  ),
      ),
    ]);
  }

  Future<void> _editPaymentTerm(String id, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['name']);
    final descCtrl = TextEditingController(text: data['description'] ?? '');
    final dueCtrl = TextEditingController(text: '${data['due_days']}');
    final discDaysCtrl = TextEditingController(text: '${data['discount_days'] ?? 0}');
    final discPctCtrl = TextEditingController(text: '${data['discount_pct'] ?? 0}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Payment Term'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Code: ${data['code']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            Row(children: [
              Expanded(child: TextField(controller: dueCtrl, decoration: const InputDecoration(labelText: 'Due Days'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: discDaysCtrl, decoration: const InputDecoration(labelText: 'Discount Days'), keyboardType: TextInputType.number)),
            ]),
            TextField(controller: discPctCtrl, decoration: const InputDecoration(labelText: 'Discount %'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.updatePaymentTerm(id, {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'due_days': int.tryParse(dueCtrl.text) ?? 30,
        'discount_days': int.tryParse(discDaysCtrl.text) ?? 0,
        'discount_pct': double.tryParse(discPctCtrl.text) ?? 0,
      });
      _load();
      _snack('Payment term updated', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  Future<void> _deletePaymentTerm(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Term'),
        content: const Text('Delete this payment term? Standard terms cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.deletePaymentTerm(id);
      _load();
      _snack('Payment term deleted', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }
}

class _PaymentTermCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(String) onDelete;
  const _PaymentTermCard({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isStandard = data['is_standard'] == true;
    final discount = data['discount_pct'] != null && (data['discount_pct'] as num) > 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isStandard ? AppTheme.accentBlue : AppTheme.accentGreen).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(data['code']?.toString() ?? '', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 11, color: isStandard ? AppTheme.accentBlue : AppTheme.accentGreen))),
        ),
        title: Text(data['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text.rich(TextSpan(children: [
          TextSpan(text: 'Due: ${data['due_days']} days'),
          if (discount)
            TextSpan(text: ' · ${data['discount_pct']}% ${data['discount_days']}d'),
          if (isStandard)
            TextSpan(text: ' · Standard', style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w500)),
        ]), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit(data['id'], data);
            if (v == 'delete' && !isStandard) onDelete(data['id']);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('Edit'))),
            if (!isStandard)
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 4: INCOTERMS CRUD
// ════════════════════════════════════════════════════════════

class _IncotermsTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _IncotermsTab({required this.authService, required this.svc});

  @override
  State<_IncotermsTab> createState() => _IncotermsTabState();
}

class _IncotermsTabState extends State<_IncotermsTab> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await widget.svc.listIncoterms();
    } catch (_) {}
    setState(() => _loading = false);
  }

  String _categoryIcon(String cat) {
    switch (cat) {
      case 'E': return '🚪';
      case 'F': return '⛵';
      case 'C': return '🚚';
      case 'D': return '🏁';
      default: return '📦';
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'E': return Colors.blue;
      case 'F': return Colors.teal;
      case 'C': return Colors.orange;
      case 'D': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _create() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'F';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Incoterm'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code *', hintText: 'FOB')),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', hintText: 'Free On Board')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                DropdownMenuItem(value: 'E', child: Text('🚪 E — Departure (EXW)')),
                DropdownMenuItem(value: 'F', child: Text('⛵ F — Main carriage unpaid (FCA, FAS, FOB)')),
                DropdownMenuItem(value: 'C', child: Text('🚚 C — Main carriage paid (CFR, CIF, CPT, CIP)')),
                DropdownMenuItem(value: 'D', child: Text('🏁 D — Arrival (DAP, DPU, DDP)')),
              ],
              onChanged: (v) => setDialogState(() => category = v ?? 'F'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.createIncoterm({
        'code': codeCtrl.text.trim().toUpperCase(),
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': category,
      });
      _load();
      _snack('Incoterm created', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  void _snack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <String, List<dynamic>>{};
    for (final item in _items) {
      final cat = item['category']?.toString() ?? 'OTHER';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          const Text('Incoterms 2020', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            onPressed: _create,
          ),
        ]),
      ),
      const Divider(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No incoterms defined', style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: grouped.entries.map((entry) {
                      final cat = entry.key;
                      final terms = entry.value;
                      final catName = switch (cat) {
                        'E' => 'E — Departure',
                        'F' => 'F — Main Carriage Unpaid',
                        'C' => 'C — Main Carriage Paid',
                        'D' => 'D — Arrival',
                        _ => cat,
                      };
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Row(children: [
                            Text('${_categoryIcon(cat)}  ', style: const TextStyle(fontSize: 16)),
                            Text(catName, style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13, color: _categoryColor(cat))),
                          ]),
                        ),
                        ...terms.map((inc) => _IncotermCard(
                              data: inc,
                              categoryColor: _categoryColor(cat),
                              onEdit: (id, data) => _editIncoterm(id, data),
                              onDelete: (id) => _deleteIncoterm(id),
                            )),
                      ]);
                    }).toList(),
                  ),
      ),
    ]);
  }

  Future<void> _editIncoterm(String id, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['name']);
    final descCtrl = TextEditingController(text: data['description'] ?? '');
    String category = data['category'] ?? 'OTHER';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Incoterm'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Code: ${data['code']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['E', 'F', 'C', 'D', 'OTHER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setDialogState(() => category = v ?? 'OTHER'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.updateIncoterm(id, {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'category': category,
      });
      _load();
      _snack('Incoterm updated', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  Future<void> _deleteIncoterm(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Incoterm'),
        content: const Text('Delete this incoterm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.deleteIncoterm(id);
      _load();
      _snack('Incoterm deleted', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }
}

class _IncotermCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color categoryColor;
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(String) onDelete;
  const _IncotermCard({required this.data, required this.categoryColor, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(data['code']?.toString() ?? '', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 12, color: categoryColor))),
        ),
        title: Text(data['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(data['description']?.toString() ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit(data['id'], data);
            if (v == 'delete') onDelete(data['id']);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('Edit'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 5: ACCOUNT TYPE MAPPING BY COMPANY CODE
// ════════════════════════════════════════════════════════════

/// Predefined account types. A company code can have at most one of each.
const Map<String, String> _accountTypes = {
  'GR_IR': 'GR/IR Clearing',
  'INVENTORY': 'Inventory',
  'AP_RECON': 'AP Reconciliation',
  'AP_DP': 'AP Down Payment',
  'AR_RECON': 'AR Reconciliation',
  'AR_DP': 'AR Down Payment',
  'CASH': 'Cash / Bank Clearing',
  'TAX_INPUT': 'Input Tax (VAT/GST)',
  'TAX_OUTPUT': 'Output Tax (VAT/GST)',
  'CLEARING': 'General Clearing',
  'PRICE_DIF': 'Price Difference',
};

Color _typeColor(String type) {
  switch (type) {
    case 'GR_IR':       return Colors.orange;
    case 'INVENTORY':    return Colors.teal;
    case 'AP_RECON':     return Colors.blue;
    case 'AP_DP':        return Colors.lightBlue;
    case 'AR_RECON':     return Colors.indigo;
    case 'AR_DP':        return Colors.deepPurple;
    case 'CASH':         return Colors.green;
    case 'TAX_INPUT':    return Colors.deepOrange;
    case 'TAX_OUTPUT':   return Colors.red;
    case 'CLEARING':     return Colors.purple;
    case 'PRICE_DIF':    return Colors.cyan;
    default:             return Colors.grey;
  }
}

class _ReconAccountsTab extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;
  final FinanceSettingsService svc;
  const _ReconAccountsTab({required this.authService, required this.orgService, required this.svc});

  @override
  State<_ReconAccountsTab> createState() => _ReconAccountsTabState();
}

class _ReconAccountsTabState extends State<_ReconAccountsTab> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _glAccounts = [];
  bool _loading = true;
  String? _orgFilter;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authService.accessToken}',
      };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _orgs = (await widget.orgService.getOrganizations()).cast<Map<String, dynamic>>();
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/gl/accounts'),
        headers: _headers,
      );
      if (resp.statusCode < 400) {
        final data = (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
        _glAccounts = data.cast<Map<String, dynamic>>();
      }
      await _loadItems();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadItems() async {
    try {
      _items = await widget.svc.listOrgReconAccounts(orgId: _orgFilter);
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    String? selectedOrgId;
    String? selectedType;
    String? selectedAccountId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Configure Account Mapping'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedOrgId,
                decoration: const InputDecoration(labelText: 'Company Code *'),
                isExpanded: true,
                items: _orgs.map((o) => DropdownMenuItem(
                  value: o['id']?.toString(),
                  child: Text('${o['org_code']} - ${o['org_name']}'),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedOrgId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Account Type *'),
                isExpanded: true,
                items: _accountTypes.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Row(children: [
                    Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: _typeColor(e.key), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${e.key} — ${e.value}', style: const TextStyle(fontSize: 13)),
                  ]),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedAccountId,
                decoration: const InputDecoration(labelText: 'GL Account *'),
                isExpanded: true,
                items: _glAccounts.map((a) => DropdownMenuItem(
                  value: a['id']?.toString(),
                  child: Text('${a['account_code']} - ${a['account_name']}',
                      style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedAccountId = v),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('One account per type per company. Save again with the same company+type to update the GL account.',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedOrgId != null && selectedType != null && selectedAccountId != null
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.createOrgReconAccount({
        'org_id': selectedOrgId,
        'account_id': selectedAccountId,
        'reconciliation_type': '',
        'account_type': selectedType,
      });
      _loadItems();
      _snack('Account mapping configured', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    String? selectedAccountId = item['account_id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Update GL Account'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item['org_code']} - ${item['org_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Type: ${item['account_type']} — ${_accountTypes[item['account_type']] ?? ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedAccountId,
                decoration: const InputDecoration(labelText: 'GL Account *'),
                isExpanded: true,
                items: _glAccounts.map((a) => DropdownMenuItem(
                  value: a['id']?.toString(),
                  child: Text('${a['account_code']} - ${a['account_name']}',
                      style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedAccountId = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedAccountId != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      // Upsert with same org_id + account_type to replace the GL account
      await widget.svc.createOrgReconAccount({
        'org_id': item['org_id'],
        'account_id': selectedAccountId,
        'reconciliation_type': item['reconciliation_type'] ?? '',
        'account_type': item['account_type'],
      });
      _loadItems();
      _snack('Account mapping updated', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Configuration'),
        content: const Text('Remove this account mapping?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.svc.deleteOrgReconAccount(id);
      _loadItems();
      _snack('Configuration removed', Colors.green);
    } catch (e) {
      _snack('$e', AppTheme.errorColor);
    }
  }

  void _snack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _orgFilter,
            decoration: const InputDecoration(labelText: 'Company Code', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Companies', style: TextStyle(fontSize: 13))),
              ..._orgs.map((o) => DropdownMenuItem(
                  value: o['id']?.toString(),
                  child: Text('${o['org_code']} - ${o['org_name']}', style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) { _orgFilter = v; _loadItems(); },
          )),
          const SizedBox(width: 8),
          TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('New'), onPressed: _create),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _buildContent()),
    ]);
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.settings_applications, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text('No account mappings configured', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('Click "New" to assign a GL account type to a company code',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final type = item['account_type']?.toString() ?? '';
          final color = _typeColor(type);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(
                  type.split('_').map((s) => s[0]).take(2).join(),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color),
                )),
              ),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${item['org_code'] ?? ''} - ${item['org_name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
              ]),
              subtitle: Text('${item['account_code'] ?? ''} - ${item['account_name'] ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editItem(item);
                  if (v == 'delete') _delete(item['id']);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(
                      leading: Icon(Icons.edit, size: 18),
                      title: Text('Edit'))),
                  const PopupMenuItem(value: 'delete', child: ListTile(
                      leading: Icon(Icons.delete, size: 18, color: Colors.red),
                      title: Text('Remove', style: TextStyle(color: Colors.red)))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaxRateDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _TaxRateDialog({this.existing});
  @override State<_TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends State<_TaxRateDialog> {
  final _jurCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _effDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _jurCtrl.text = e['jurisdiction_name']?.toString() ?? '';
      _zipCtrl.text = e['zip_code']?.toString() ?? '';
      _cityCtrl.text = e['city']?.toString() ?? '';
      final r = ((e['tax_rate'] as num?)?.toDouble() ?? 0) * 100;
      _rateCtrl.text = r.toStringAsFixed(2);
      _descCtrl.text = e['description']?.toString() ?? '';
      if (e['effective_date'] != null) { _effDate = DateTime.parse(e['effective_date'].toString()); }
      if (e['end_date'] != null) { _endDate = DateTime.parse(e['end_date'].toString()); }
      _isActive = e['is_active'] == true;
    }
  }

  @override void dispose() { _jurCtrl.dispose(); _zipCtrl.dispose(); _cityCtrl.dispose(); _rateCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Tax Rate' : 'Add Tax Rate'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _jurCtrl, decoration: const InputDecoration(labelText: 'Jurisdiction Name *', isDense: true), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _zipCtrl, decoration: const InputDecoration(labelText: 'Zip Code *', isDense: true), style: TextStyle(fontSize: 13, fontFamily: 'monospace'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City', isDense: true), style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _rateCtrl, decoration: const InputDecoration(labelText: 'Tax Rate % *', isDense: true, suffixText: '%'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _effDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _effDate = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Effective *', isDense: true),
                  child: Text('${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _endDate = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'End Date (optional)', isDense: true),
                child: Builder(builder: (ctx) { final d = _endDate; return Text(d == null ? "No end date" : "${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}", style: TextStyle(fontSize: 11, fontFamily: "monospace")); })),
              )),
              const SizedBox(width: 8),
              Row(children: [
                const Text('Active', style: TextStyle(fontSize: 12)),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ]),
            ]),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), style: const TextStyle(fontSize: 12), maxLines: 2),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_jurCtrl.text.isEmpty || _zipCtrl.text.isEmpty || _rateCtrl.text.isEmpty) { return; }
          final rate = double.tryParse(_rateCtrl.text);
          if (rate == null || rate <= 0) { return; }
          Navigator.pop(context, {
            'jurisdiction_name': _jurCtrl.text.trim(),
            'zip_code': _zipCtrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'tax_rate': rate / 100.0,
            'effective_date': '${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}',
            "end_date": _endDate == null ? "" : (() { final d = _endDate!; return "${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}"; })(),
            'description': _descCtrl.text.trim(),
            'is_active': _isActive,
          });
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}
