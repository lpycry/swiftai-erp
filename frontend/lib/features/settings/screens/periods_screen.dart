import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class PeriodsScreen extends StatefulWidget {
  final AuthService authService;
  final OrgService orgService;
  const PeriodsScreen({super.key, required this.authService, required this.orgService});

  @override
  State<PeriodsScreen> createState() => _PeriodsScreenState();
}

class _PeriodsScreenState extends State<PeriodsScreen> {
  List<dynamic> _periods = [];
  List<dynamic> _orgs = [];
  bool _loading = true;
  int _year = DateTime.now().year;
  String? _selectedOrgId;

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
      if (mounted) _err('Failed to load: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPeriods() async {
    try {
      final params = <String, String>{'year': '$_year'};
      if (_selectedOrgId != null) params['org_id'] = _selectedOrgId!;
      // We call the period list API through a custom method
      _periods = await _fetchPeriods(params);
    } catch (e) {
      if (mounted) _err('Failed to load periods: $e');
    }
  }

  Future<List<dynamic>> _fetchPeriods(Map<String, String> params) async {
    final token = widget.authService.accessToken;
    final uri = Uri.parse('http://localhost:8080/api/v1/periods').replace(queryParameters: params);
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode >= 400) throw Exception('API error');
    final body = jsonDecode(resp.body);
    return body['data'] as List<dynamic>? ?? [];
  }

  Future<void> _togglePeriod(String id, bool newOpen) async {
    try {
      final token = widget.authService.accessToken;
      await http.put(
        Uri.parse('http://localhost:8080/api/v1/periods/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'is_open': newOpen}),
      );
      await _loadPeriods();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newOpen ? 'Period opened' : 'Period closed'),
            backgroundColor: newOpen ? AppTheme.accentGreen : AppTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) _err('Failed: $e');
    }
  }

  Future<void> _generatePeriods() async {
    final yearCtrl = TextEditingController(text: '$_year');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Periods'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This will create 12 periods (Jan-Dec) for the selected year.'),
          const SizedBox(height: 12),
          TextField(
            controller: yearCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year', hintText: '2026'),
          ),
          if (_selectedOrgId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('For Company: ${_orgs.firstWhere((o) => o['id'] == _selectedOrgId)['org_name'] ?? 'Selected'}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = widget.authService.accessToken;
      final body = <String, dynamic>{'year': int.tryParse(yearCtrl.text) ?? _year};
      if (_selectedOrgId != null) body['organization_id'] = _selectedOrgId;
      await http.post(
        Uri.parse('http://localhost:8080/api/v1/periods/generate'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      await _loadPeriods();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Periods generated'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      if (mounted) _err('$e');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor));

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService, currentIndex: 5, onIndexChanged: (_) {},
      title: 'Accounting Periods',
      body: Column(children: [
        _buildFilterBar(),
        const Divider(height: 1),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildTable()),
      ]),
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(10, (i) => DateTime.now().year - 3 + i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        DropdownButton<int>(
          value: _year, underline: const SizedBox(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
          onChanged: (v) => setState(() { _year = v!; _loadPeriods(); }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedOrgId,
            decoration: const InputDecoration(
              labelText: 'Company', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Companies', style: TextStyle(fontSize: 13))),
              ..._orgs.map((o) => DropdownMenuItem(
                value: o['id'], child: Text('${o['org_code']} - ${o['org_name']}', style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) => setState(() { _selectedOrgId = v; _loadPeriods(); }),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Generate', style: TextStyle(fontSize: 13)),
          onPressed: _generatePeriods,
        ),
      ]),
    );
  }

  Widget _buildTable() {
    if (_periods.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_note, size: 48, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        Text('No periods found. Generate periods first.',
            style: TextStyle(color: AppTheme.textMuted)),
      ]),
    );

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _periods.length,
      itemBuilder: (_, i) => _buildPeriodRow(_periods[i]),
    );
  }

  Widget _buildPeriodRow(dynamic p) {
    final isOpen = p['is_open'] as bool;
    final isLocked = p['is_locked'] as bool;
    final canToggle = !isLocked;
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
          // Period info
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 6),
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
          // Date range
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateRange, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              if (p['organization_id'] != null)
                Text('Company specific', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
            ],
          )),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          // Toggle switch
          if (canToggle)
            Switch(
              value: isOpen,
              activeColor: AppTheme.accentGreen,
              onChanged: (v) => _togglePeriod(p['id'], v),
            ),
          if (!canToggle)
            Icon(Icons.lock_outlined, size: 16, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

