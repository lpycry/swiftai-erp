import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/settings/services/finance_settings_service.dart';

class TaxManagementScreen extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService financeSettingsService;
  const TaxManagementScreen({
    super.key,
    required this.authService,
    required this.financeSettingsService,
  });

  @override
  State<TaxManagementScreen> createState() => _TaxManagementScreenState();
}

class _TaxManagementScreenState extends State<TaxManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Tax Rate Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tax Jurisdictions'),
            Tab(text: 'Nexus Management'),
            Tab(text: 'Product Category Tax Code'),
            Tab(text: 'Tax Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TaxJurisdictionsTab(
            authService: widget.authService,
            svc: widget.financeSettingsService,
          ),
          _TaxNexusTab(
            authService: widget.authService,
            svc: widget.financeSettingsService,
          ),
          _TaxJurisdictionRulesTab(
            authService: widget.authService,
            svc: widget.financeSettingsService,
          ),
          _TaxCategoriesTab(
            authService: widget.authService,
            svc: widget.financeSettingsService,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1: TAX JURISDICTIONS
// ═══════════════════════════════════════════════════════════════

class _TaxJurisdictionsTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _TaxJurisdictionsTab({required this.authService, required this.svc});
  @override State<_TaxJurisdictionsTab> createState() => _TaxJurisdictionsTabState();
}

class _TaxJurisdictionsTabState extends State<_TaxJurisdictionsTab> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _stateFilter;
  bool _activeOnly = false;

  @override void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_activeOnly) params['active_only'] = 'true';
      final uri = Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions').replace(queryParameters: params);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        var list = ((jsonDecode(resp.body)['data'] as List?) ?? []);
        if (_stateFilter != null && _stateFilter!.isNotEmpty) {
          list = list.where((e) =>
            (e['state']?.toString() ?? '').toUpperCase().contains(_stateFilter!.toUpperCase())).toList();
        }
        _items = list;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _JurisdictionDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await http.post(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
            body: jsonEncode(result));
      } else {
        await http.put(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions/${existing['id']}'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
            body: jsonEncode(result));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Tax Jurisdiction'), content: Text('Delete $label?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red))],
    ));
    if (ok != true) return;
    try {
      await http.delete(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdictions/$id'),
          headers: {'Authorization': 'Bearer $_token'});
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          SizedBox(width: 100, child: TextField(
            decoration: const InputDecoration(labelText: 'State', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12), onChanged: (v) => _stateFilter = v.isEmpty ? null : v, onSubmitted: (_) => _load(),
          )),
          const SizedBox(width: 8),
          FilterChip(label: const Text('Active Only', style: TextStyle(fontSize: 10)), selected: _activeOnly,
            onSelected: (v) { setState(() => _activeOnly = v); _load(); }, visualDensity: VisualDensity.compact),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _upsert(null), tooltip: 'Add Jurisdiction'),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ]),
      ),
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: Colors.grey.shade100,
        child: Row(children: [
          const Expanded(flex: 1, child: Text('State', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 2, child: Text('County', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Zip', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          Expanded(flex: 1, child: Text('Rate', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const SizedBox(width: 72),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty ? const Center(child: Text('No tax jurisdictions configured'))
          : ListView.builder(itemCount: _items.length, itemBuilder: (_, i) => _buildRow(_items[i] as Map<String, dynamic>)),
      ),
    ]);
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final label = '${r['state']} - ${r['county']}';
    final rate = ((r['tax_rate'] as num?)?.toDouble() ?? 0) * 100;
    final active = r['is_active'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: active ? null : Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(flex: 1, child: Text(r['state']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? null : Colors.grey))),
        Expanded(flex: 2, child: Text(r['county']?.toString() ?? '', style: TextStyle(fontSize: 11, color: active ? null : Colors.grey))),
        Expanded(flex: 1, child: Text(r['city']?.toString() ?? '', style: TextStyle(fontSize: 11, color: active ? null : Colors.grey))),
        Expanded(flex: 1, child: Text(r['zip_code']?.toString() ?? '', style: TextStyle(fontSize: 10, fontFamily: 'monospace'))),
        Expanded(flex: 1, child: Text('${rate.toStringAsFixed(3)}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))),
        SizedBox(width: 72, child: Row(children: [
          IconButton(icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade600), onPressed: () => _upsert(r), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete, size: 14, color: Colors.red.shade400), onPressed: () => _delete(id, label), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ])),
      ]),
    );
  }
}

class _JurisdictionDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _JurisdictionDialog({this.existing});
  @override State<_JurisdictionDialog> createState() => _JurisdictionDialogState();
}

class _JurisdictionDialogState extends State<_JurisdictionDialog> {
  final _stateCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  DateTime _effDate = DateTime.now();
  DateTime? _expDate;
  bool _isActive = true;

  static const _states = [
    'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
    'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
    'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
    'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
    'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
  ];

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _stateCtrl.text = e['state']?.toString() ?? '';
      _countyCtrl.text = e['county']?.toString() ?? '';
      _cityCtrl.text = e['city']?.toString() ?? '';
      _zipCtrl.text = e['zip_code']?.toString() ?? '';
      final r = ((e['tax_rate'] as num?)?.toDouble() ?? 0) * 100;
      _rateCtrl.text = r.toStringAsFixed(3);
      if (e['effective_date'] != null) { _effDate = DateTime.parse(e['effective_date'].toString()); }
      if (e['expiration_date'] != null) { _expDate = DateTime.parse(e['expiration_date'].toString()); }
      _isActive = e['is_active'] == true;
    }
  }

  @override void dispose() {
    _stateCtrl.dispose(); _countyCtrl.dispose(); _cityCtrl.dispose(); _zipCtrl.dispose(); _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Tax Jurisdiction' : 'Add Tax Jurisdiction'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // State dropdown
            DropdownButtonFormField<String>(
              value: _stateCtrl.text.isEmpty ? null : _stateCtrl.text,
              decoration: const InputDecoration(labelText: 'State *', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => _stateCtrl.text = v ?? '',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _countyCtrl, decoration: const InputDecoration(labelText: 'County', isDense: true), style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City', isDense: true), style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _zipCtrl, decoration: const InputDecoration(labelText: 'ZIP Code', isDense: true), style: TextStyle(fontSize: 13, fontFamily: 'monospace'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _rateCtrl, decoration: const InputDecoration(labelText: 'Tax Rate % *', isDense: true, suffixText: '%'), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _effDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _effDate = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Effective *', isDense: true),
                  child: Text('${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              )),
              const SizedBox(width: 8),
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _expDate ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _expDate = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Expiration', isDense: true),
                  child: Builder(builder: (ctx) { final d = _expDate; return Text(d == null ? 'No end' : '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')); })),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Active', style: TextStyle(fontSize: 12)),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_stateCtrl.text.isEmpty || _rateCtrl.text.isEmpty) return;
          final rate = double.tryParse(_rateCtrl.text);
          if (rate == null || rate <= 0) return;
          Navigator.pop(context, {
            'state': _stateCtrl.text.trim(),
            'county': _countyCtrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'zip_code': _zipCtrl.text.trim(),
            'tax_rate': rate / 100.0,
            'effective_date': '${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}',
            'expiration_date': _expDate == null ? '' : '${_expDate!.year}-${_expDate!.month.toString().padLeft(2,'0')}-${_expDate!.day.toString().padLeft(2,'0')}',
            'is_active': _isActive,
          });
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2: NEXUS MANAGEMENT
// ═══════════════════════════════════════════════════════════════

class _TaxNexusTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _TaxNexusTab({required this.authService, required this.svc});
  @override State<_TaxNexusTab> createState() => _TaxNexusTabState();
}

class _TaxNexusTabState extends State<_TaxNexusTab> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _activeOnly = true;

  @override void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{};
      if (_activeOnly) params['active_only'] = 'true';
      final uri = Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-nexus').replace(queryParameters: params);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $_token'});
      if (resp.statusCode < 400) {
        _items = ((jsonDecode(resp.body)['data'] as List?) ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NexusDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await http.post(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-nexus'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
            body: jsonEncode(result));
      } else {
        await http.put(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-nexus/${existing['id']}'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
            body: jsonEncode(result));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Nexus'), content: Text('Delete $label?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red))],
    ));
    if (ok != true) return;
    try {
      await http.delete(Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-nexus/$id'),
          headers: {'Authorization': 'Bearer $_token'});
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  Color _nexusColor(String type) {
    switch (type) {
      case 'PHYSICAL': return Colors.teal;
      case 'ECONOMIC': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _nexusTypeLabel(String type) => type == 'PHYSICAL' ? 'Physical' : 'Economic';

  String _subTypeLabel(Map<String, dynamic> r) {
    final t = r['nexus_type']?.toString() ?? '';
    final s = r['sub_type']?.toString() ?? '';
    if (t == 'ECONOMIC') {
      final amt = r['threshold_amount'];
      if (amt != null) {
        final v = (amt as num).toDouble();
        return 'Sales > \$${_fmtAmount(v)}';
      }
      return '';
    }
    return s;
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          FilterChip(label: const Text('Active Only', style: TextStyle(fontSize: 10)), selected: _activeOnly,
            onSelected: (v) { setState(() => _activeOnly = v); _load(); }, visualDensity: VisualDensity.compact),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _upsert(null), tooltip: 'Add Nexus'),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: Colors.grey.shade100,
        child: Row(children: [
          const Expanded(flex: 2, child: Text('State', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 2, child: Text('Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          Expanded(flex: 1, child: Text('Eff.Date', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const SizedBox(width: 72),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty ? const Center(child: Text('No tax nexus configured'))
          : ListView.builder(itemCount: _items.length, itemBuilder: (_, i) => _buildRow(_items[i] as Map<String, dynamic>)),
      ),
    ]);
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final state = r['state']?.toString() ?? '';
    final nexusType = r['nexus_type']?.toString() ?? '';
    final label = '$state ${_nexusTypeLabel(nexusType)}';
    final eff = r['effective_date']?.toString() ?? '';
    final active = r['is_active'] == true;
    final color = _nexusColor(nexusType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: active ? null : Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(state, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? null : Colors.grey))),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(_nexusTypeLabel(nexusType), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        )),
        Expanded(flex: 2, child: Text(_subTypeLabel(r), style: TextStyle(fontSize: 11, color: active ? null : Colors.grey))),
        Expanded(flex: 1, child: Text(eff.length >= 10 ? eff.substring(0, 10) : eff, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey))),
        SizedBox(width: 72, child: Row(children: [
          IconButton(icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade600), onPressed: () => _upsert(r), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete, size: 14, color: Colors.red.shade400), onPressed: () => _delete(id, label), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ])),
      ]),
    );
  }
}

class _NexusDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _NexusDialog({this.existing});
  @override State<_NexusDialog> createState() => _NexusDialogState();
}

class _NexusDialogState extends State<_NexusDialog> {
  String _state = '';
  String _nexusType = 'PHYSICAL';
  String _subType = 'WAREHOUSE';
  final _thresholdCtrl = TextEditingController();
  DateTime _effDate = DateTime.now();
  bool _isActive = true;

  static const _states = [
    'Alabama','Alaska','Arizona','Arkansas','California','Colorado','Connecticut','Delaware','Florida','Georgia',
    'Hawaii','Idaho','Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland',
    'Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana','Nebraska','Nevada','New Hampshire','New Jersey',
    'New Mexico','New York','North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania','Rhode Island','South Carolina',
    'South Dakota','Tennessee','Texas','Utah','Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming',
  ];

  static const _physicalTypes = ['WAREHOUSE', 'OFFICE', 'EMPLOYEE'];

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _state = e['state']?.toString() ?? '';
      _nexusType = e['nexus_type']?.toString() ?? 'PHYSICAL';
      if (_nexusType == 'PHYSICAL') {
        _subType = e['sub_type']?.toString() ?? 'WAREHOUSE';
      }
      final amt = e['threshold_amount'];
      if (amt != null) _thresholdCtrl.text = (amt as num).toDouble().toStringAsFixed(0);
      if (e['effective_date'] != null) { _effDate = DateTime.parse(e['effective_date'].toString()); }
      _isActive = e['is_active'] == true;
    }
  }

  @override void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Tax Nexus' : 'Add Tax Nexus'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // State dropdown (full name)
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _state),
              optionsBuilder: (v) => _states.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _state = v,
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) => TextField(
                controller: ctrl,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'State *', isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),

            // Nexus Type
            DropdownButtonFormField<String>(
              value: _nexusType,
              decoration: const InputDecoration(labelText: 'Nexus Type *', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              items: const [
                DropdownMenuItem(value: 'PHYSICAL', child: Text('Physical Nexus', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'ECONOMIC', child: Text('Economic Nexus', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) { setState(() => _nexusType = v ?? 'PHYSICAL'); },
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Sub-type for Physical
            if (_nexusType == 'PHYSICAL') ...[
              DropdownButtonFormField<String>(
                value: _subType,
                decoration: const InputDecoration(labelText: 'Physical Nexus Type *', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                items: _physicalTypes.map((s) => DropdownMenuItem(value: s, child: Text(s[0] + s.substring(1).toLowerCase(), style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => _subType = v ?? 'WAREHOUSE',
                style: const TextStyle(fontSize: 13),
              ),
            ],

            // Threshold for Economic
            if (_nexusType == 'ECONOMIC') ...[
              TextField(
                controller: _thresholdCtrl,
                decoration: const InputDecoration(labelText: 'Annual Sales Threshold (\$)', isDense: true, hintText: '500000'),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
              ),
            ],

            const SizedBox(height: 8),

            // Effective Date
            InkWell(
              onTap: () async { final d = await showDatePicker(context: context, initialDate: _effDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _effDate = d); },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Effective Date *', isDense: true),
                child: Text('${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
            ),

            const SizedBox(height: 8),
            Row(children: [
              const Text('Active', style: TextStyle(fontSize: 12)),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_state.isEmpty) return;
          final data = <String, dynamic>{
            'state': _state,
            'nexus_type': _nexusType,
            'sub_type': _nexusType == 'PHYSICAL' ? _subType : '',
            'effective_date': '${_effDate.year}-${_effDate.month.toString().padLeft(2,'0')}-${_effDate.day.toString().padLeft(2,'0')}',
            'is_active': _isActive,
          };
          if (_nexusType == 'ECONOMIC') {
            final amt = double.tryParse(_thresholdCtrl.text);
            if (amt != null && amt > 0) data['threshold_amount'] = amt;
          }
          Navigator.pop(context, data);
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3: PRODUCT CATEGORY TAX CODE (Tax Jurisdiction Rules)
// ═══════════════════════════════════════════════════════════════

class _TaxJurisdictionRulesTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _TaxJurisdictionRulesTab({required this.authService, required this.svc});
  @override State<_TaxJurisdictionRulesTab> createState() => _TaxJurisdictionRulesTabState();
}

class _TaxJurisdictionRulesTabState extends State<_TaxJurisdictionRulesTab> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _jurisFilter;
  String? _catFilter;

  @override void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdiction-rules'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) {
        var list = ((jsonDecode(resp.body)['data'] as List?) ?? []);
        if (_jurisFilter != null && _jurisFilter!.isNotEmpty) {
          list = list.where((e) =>
            (e['jurisdiction_code']?.toString() ?? '').toUpperCase().contains(_jurisFilter!.toUpperCase())).toList();
        }
        if (_catFilter != null && _catFilter!.isNotEmpty) {
          list = list.where((e) =>
            (e['tax_category_code']?.toString() ?? '').toUpperCase().contains(_catFilter!.toUpperCase())).toList();
        }
        _items = list;
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List failed: HTTP ${resp.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TaxRuleDialog(existing: existing, token: _token),
    );
    if (result == null) return;
    try {
      http.Response resp;
      if (existing == null) {
        resp = await http.post(
          Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdiction-rules'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
      } else {
        final ruleId = existing['rule_id'];
        resp = await http.put(
          Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdiction-rules/$ruleId'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
      }
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        final msg = body['message']?.toString() ?? 'HTTP ${resp.statusCode}';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        return;
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(int ruleId, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Tax Rule'),
      content: Text('Delete rule for $label?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
      ],
    ));
    if (ok != true) return;
    try {
      await http.delete(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-jurisdiction-rules/$ruleId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          SizedBox(width: 130, child: TextField(
            decoration: const InputDecoration(labelText: 'Jurisdiction', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12), onChanged: (v) => _jurisFilter = v.isEmpty ? null : v, onSubmitted: (_) => _load(),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: TextField(
            decoration: const InputDecoration(labelText: 'Tax Category', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12), onChanged: (v) => _catFilter = v.isEmpty ? null : v, onSubmitted: (_) => _load(),
          )),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _upsert(null), tooltip: 'Add Rule'),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ]),
      ),
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: Colors.grey.shade100,
        child: Row(children: [
          const Expanded(flex: 1, child: Text('Jurisdiction', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('State', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Tax Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 1, child: Text('Taxable', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          Expanded(flex: 1, child: Text('Rate', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const SizedBox(width: 72),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty ? const Center(child: Text('No product tax code rules configured'))
          : ListView.builder(itemCount: _items.length, itemBuilder: (_, i) => _buildRow(_items[i] as Map<String, dynamic>)),
      ),
    ]);
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final ruleId = r['rule_id'] as int? ?? 0;
    final label = '${r['jurisdiction_code']} / ${r['tax_category_code']}';
    final rate = ((r['base_rate'] as num?)?.toDouble() ?? 0) * 100;
    final isTaxable = r['is_taxable'] == true;
    final effTo = r['effective_to']?.toString();
    final current = effTo == null || effTo.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isTaxable ? null : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Text(r['jurisdiction_code']?.toString() ?? '',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: current ? null : Colors.grey))),
        Expanded(flex: 1, child: Text(r['state_code']?.toString() ?? '',
          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: current ? null : Colors.grey))),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _catColor(r['tax_category_code']?.toString() ?? '').withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(r['tax_category_code']?.toString() ?? '',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: _catColor(r['tax_category_code']?.toString() ?? ''))),
        )),
        Expanded(flex: 1, child: Icon(
          isTaxable ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: isTaxable ? Colors.green : Colors.red.shade300,
        )),
        Expanded(flex: 1, child: Text('${rate.toStringAsFixed(3)}%',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue))),
        SizedBox(width: 72, child: Row(children: [
          IconButton(icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
            onPressed: () => _upsert(r), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete, size: 14, color: Colors.red.shade400),
            onPressed: () => _delete(ruleId, label), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ])),
      ]),
    );
  }

  Color _catColor(String code) {
    switch (code.toUpperCase()) {
      case 'STANDARD': return Colors.blue;
      case 'REDUCED': return Colors.teal;
      case 'ZERO': return Colors.green;
      case 'EXEMPT': return Colors.orange;
      case 'SERVICE': return Colors.purple;
      default: return Colors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAX RULE DIALOG
// ═══════════════════════════════════════════════════════════════

class _TaxRuleDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String token;
  const _TaxRuleDialog({this.existing, required this.token});
  @override State<_TaxRuleDialog> createState() => _TaxRuleDialogState();
}

class _TaxRuleDialogState extends State<_TaxRuleDialog> {
  final _jurisCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String _stateCode = '';
  String? _taxCategory;
  bool _isTaxable = true;
  final _rateCtrl = TextEditingController();
  String _conditionType = 'NONE';
  final _conditionCtrl = TextEditingController();
  DateTime _effFrom = DateTime.now();
  DateTime? _effTo;
  final _updatedByCtrl = TextEditingController();

  List<Map<String, dynamic>> _taxCategoryOptions = [];
  bool _loadingCategories = true;

  static const _states = ['AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
    'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
    'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
    'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
    'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
  ];

  static const _conditionTypes = ['NONE', 'THRESHOLD', 'FLAT'];

  Future<void> _loadTaxCategories() async {
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (resp.statusCode < 400) {
        final list = ((jsonDecode(resp.body)['data'] as List?) ?? []);
        _taxCategoryOptions = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCategories = false);
  }

  @override void initState() {
    super.initState();
    _loadTaxCategories();
    if (widget.existing != null) {
      final e = widget.existing!;
      _jurisCtrl.text = e['jurisdiction_code']?.toString() ?? '';
      _zipCtrl.text = e['zip_code']?.toString() ?? '';
      _stateCode = e['state_code']?.toString() ?? '';
      _taxCategory = e['tax_category_code']?.toString();
      _isTaxable = e['is_taxable'] == true;
      final r = ((e['base_rate'] as num?)?.toDouble() ?? 0) * 100;
      _rateCtrl.text = r.toStringAsFixed(3);
      _conditionType = e['condition_type']?.toString() ?? 'NONE';
      final cv = e['condition_value'];
      if (cv != null) _conditionCtrl.text = (cv as num).toDouble().toStringAsFixed(2);
      if (e['effective_from'] != null) { _effFrom = DateTime.parse(e['effective_from'].toString()); }
      if (e['effective_to'] != null) { _effTo = DateTime.parse(e['effective_to'].toString()); }
      _updatedByCtrl.text = e['updated_by']?.toString() ?? '';
    }
  }

  @override void dispose() {
    _jurisCtrl.dispose();
    _zipCtrl.dispose();
    _rateCtrl.dispose();
    _conditionCtrl.dispose();
    _updatedByCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Tax Jurisdiction Rule' : 'Add Tax Jurisdiction Rule'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Jurisdiction Code
            TextField(
              controller: _jurisCtrl,
              decoration: const InputDecoration(labelText: 'Jurisdiction Code *', isDense: true, hintText: 'e.g. CA_MILPITAS, TX_STATE'),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),

            // State Code
            DropdownButtonFormField<String>(
              value: _stateCode.isEmpty ? null : _stateCode,
              decoration: const InputDecoration(labelText: 'State Code *', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')))).toList(),
              onChanged: (v) => _stateCode = v ?? '',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Zip Code
            TextField(
              controller: _zipCtrl,
              decoration: const InputDecoration(labelText: 'Zip Code', isDense: true, hintText: 'e.g. 95035', helperText: 'Optional — for granular jurisdiction matching'),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),

            // Tax Category (loaded from server, no default)
            DropdownButtonFormField<String>(
              value: _taxCategory,
              decoration: const InputDecoration(labelText: 'Tax Category *', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              items: _loadingCategories
                ? [const DropdownMenuItem(value: null, child: Text('Loading...', style: TextStyle(fontSize: 13, color: Colors.grey)))]
                : _taxCategoryOptions.map((c) => DropdownMenuItem(
                    value: c['code']?.toString(),
                    child: Text('${c['code']} — ${c['description']}', style: const TextStyle(fontSize: 13)),
                  )).toList(),
              onChanged: _loadingCategories ? null : (v) => setState(() => _taxCategory = v),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Is Taxable + Rate
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Is Taxable', style: TextStyle(fontSize: 12)),
                Switch(value: _isTaxable, onChanged: (v) => setState(() => _isTaxable = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  decoration: const InputDecoration(labelText: 'Base Rate % *', isDense: true, suffixText: '%'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // Condition Type + Condition Value
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _conditionType,
                decoration: const InputDecoration(labelText: 'Condition Type', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                items: _conditionTypes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _conditionType = v ?? 'NONE'),
                style: const TextStyle(fontSize: 13),
              )),
              const SizedBox(width: 8),
              if (_conditionType != 'NONE')
                Expanded(child: TextField(
                  controller: _conditionCtrl,
                  decoration: InputDecoration(labelText: _conditionType == 'THRESHOLD' ? 'Threshold (\$)' : 'Flat Amount (\$)', isDense: true),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ))
              else
                const Expanded(child: SizedBox()),
            ]),
            const SizedBox(height: 8),

            // Effective From / To
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _effFrom, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _effFrom = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Effective From *', isDense: true),
                  child: Text('${_effFrom.year}-${_effFrom.month.toString().padLeft(2,'0')}-${_effFrom.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              )),
              const SizedBox(width: 8),
              Expanded(child: InkWell(
                onTap: () async { final d = await showDatePicker(context: context, initialDate: _effTo ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() => _effTo = d); },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Effective To', isDense: true),
                  child: Builder(builder: (ctx) { final d = _effTo; return Text(d == null ? 'No end' : '${d.year}-${d.month.toString().padLeft(2,"0")}-${d.day.toString().padLeft(2,"0")}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')); })),
              )),
            ]),
            const SizedBox(height: 8),

            // Updated By
            TextField(
              controller: _updatedByCtrl,
              decoration: const InputDecoration(labelText: 'Updated By', isDense: true),
              style: const TextStyle(fontSize: 13),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_jurisCtrl.text.isEmpty || _stateCode.isEmpty || _taxCategory == null || _rateCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jurisdiction Code, State Code, Tax Category, and Base Rate are required'), backgroundColor: Colors.red));
            return;
          }
          final rate = double.tryParse(_rateCtrl.text);
          if (rate == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Base Rate'), backgroundColor: Colors.red));
            return;
          }
          final data = <String, dynamic>{
            'jurisdiction_code': _jurisCtrl.text.trim(),
            'state_code': _stateCode,
            'zip_code': _zipCtrl.text.trim(),
            'tax_category_code': _taxCategory,
            'is_taxable': _isTaxable,
            'base_rate': rate / 100.0,
            'condition_type': _conditionType,
            'effective_from': '${_effFrom.year}-${_effFrom.month.toString().padLeft(2,'0')}-${_effFrom.day.toString().padLeft(2,'0')}',
            'updated_by': _updatedByCtrl.text.trim(),
          };
          if (_conditionType != 'NONE') {
            final cv = double.tryParse(_conditionCtrl.text);
            if (cv != null) data['condition_value'] = cv;
          }
          if (_effTo != null) {
            data['effective_to'] = '${_effTo!.year}-${_effTo!.month.toString().padLeft(2,'0')}-${_effTo!.day.toString().padLeft(2,'0')}';
          }
          Navigator.pop(context, data);
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 4: TAX CATEGORIES
// ═══════════════════════════════════════════════════════════════

class _TaxCategoriesTab extends StatefulWidget {
  final AuthService authService;
  final FinanceSettingsService svc;
  const _TaxCategoriesTab({required this.authService, required this.svc});
  @override State<_TaxCategoriesTab> createState() => _TaxCategoriesTabState();
}

class _TaxCategoriesTabState extends State<_TaxCategoriesTab> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _codeFilter;

  @override void initState() { super.initState(); _load(); }

  String get _token => widget.authService.accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (resp.statusCode < 400) {
        var list = ((jsonDecode(resp.body)['data'] as List?) ?? []);
        if (_codeFilter != null && _codeFilter!.isNotEmpty) {
          list = list.where((e) =>
            (e['code']?.toString() ?? '').toUpperCase().contains(_codeFilter!.toUpperCase())).toList();
        }
        _items = list;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert(Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TaxCategoryDialog(existing: existing),
    );
    if (result == null) return;
    try {
      http.Response resp;
      if (existing == null) {
        resp = await http.post(
          Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
      } else {
        final id = existing['id']?.toString() ?? '';
        resp = await http.put(
          Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories/$id'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
          body: jsonEncode(result),
        );
      }
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        final msg = body['message']?.toString() ?? 'HTTP ${resp.statusCode}';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        return;
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Tax Category'),
      content: Text('Delete category "$label"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
      ],
    ));
    if (ok != true) return;
    try {
      await http.delete(
        Uri.parse('http://localhost:8080/api/v1/finance-settings/tax-categories/$id'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          SizedBox(width: 100, child: TextField(
            decoration: const InputDecoration(labelText: 'Code', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12), onChanged: (v) => _codeFilter = v.isEmpty ? null : v, onSubmitted: (_) => _load(),
          )),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _upsert(null), tooltip: 'Add Category'),
          IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        ]),
      ),
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: Colors.grey.shade100,
        child: Row(children: [
          const Expanded(flex: 1, child: Text('Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const Expanded(flex: 3, child: Text('Example', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          Expanded(flex: 1, child: Text('Active', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
          const SizedBox(width: 72),
        ]),
      ),
      Expanded(
        child: _loading ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty ? const Center(child: Text('No tax categories configured'))
          : ListView.builder(itemCount: _items.length, itemBuilder: (_, i) => _buildRow(_items[i] as Map<String, dynamic>)),
      ),
    ]);
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final code = r['code']?.toString() ?? '';
    final active = r['is_active'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? null : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _catColor(code).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(code, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1,
            fontFamily: 'monospace', color: _catColor(code),
          )),
        )),
        Expanded(flex: 3, child: Text(r['description']?.toString() ?? '', style: TextStyle(fontSize: 12, color: active ? null : Colors.grey))),
        Expanded(flex: 3, child: Text(r['example']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        Expanded(flex: 1, child: Icon(
          active ? Icons.check_circle : Icons.cancel,
          size: 14, color: active ? Colors.green : Colors.red.shade300,
        )),
        SizedBox(width: 72, child: Row(children: [
          IconButton(icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
            onPressed: () => _upsert(r), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          IconButton(icon: Icon(Icons.delete, size: 14, color: Colors.red.shade400),
            onPressed: () => _delete(id, code), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ])),
      ]),
    );
  }

  Color _catColor(String code) {
    switch (code.toUpperCase()) {
      case 'STD': case 'STANDARD': return Colors.blue;
      case 'RED': case 'REDUCED': return Colors.teal;
      case 'ZER': case 'ZERO': return Colors.green;
      case 'EXP': case 'EXEMPT': return Colors.orange;
      case 'SRV': case 'SERVICE': return Colors.purple;
      default: return Colors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAX CATEGORY DIALOG
// ═══════════════════════════════════════════════════════════════

class _TaxCategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _TaxCategoryDialog({this.existing});
  @override State<_TaxCategoryDialog> createState() => _TaxCategoryDialogState();
}

class _TaxCategoryDialogState extends State<_TaxCategoryDialog> {
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _exampleCtrl = TextEditingController();
  bool _isActive = true;

  @override void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _codeCtrl.text = e['code']?.toString() ?? '';
      _descCtrl.text = e['description']?.toString() ?? '';
      _exampleCtrl.text = e['example']?.toString() ?? '';
      _isActive = e['is_active'] == true;
    }
  }

  @override void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _exampleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Tax Category' : 'Add Tax Category'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Code (max 4 chars)
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code *',
                isDense: true,
                hintText: 'e.g. STD, RED, ZER, EXP, SRV',
                helperText: 'Max 4 characters',
              ),
              maxLength: 4,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 2),
            ),
            const SizedBox(height: 4),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description', isDense: true,
                hintText: 'e.g. Standard rate, Reduced rate, Zero rate',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Example
            TextField(
              controller: _exampleCtrl,
              decoration: const InputDecoration(
                labelText: 'Example', isDense: true,
                hintText: 'e.g. General merchandise, electronics',
              ),
              style: const TextStyle(fontSize: 13),
            ),

            if (isEdit) ...[const SizedBox(height: 8),
              Row(children: [
                const Text('Active', style: TextStyle(fontSize: 12)),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ]),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final code = _codeCtrl.text.trim().toUpperCase();
          if (code.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code is required'), backgroundColor: Colors.red));
            return;
          }
          if (code.length > 4) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code must be 4 characters or fewer'), backgroundColor: Colors.red));
            return;
          }
          final data = <String, dynamic>{
            'code': code,
            'description': _descCtrl.text.trim(),
            'example': _exampleCtrl.text.trim(),
          };
          if (isEdit) {
            data['is_active'] = _isActive;
          }
          Navigator.pop(context, data);
        }, child: Text(isEdit ? 'Update' : 'Create')),
      ],
    );
  }
}
