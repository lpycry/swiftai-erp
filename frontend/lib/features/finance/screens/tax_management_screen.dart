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
    _tabController = TabController(length: 2, vsync: this);
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
