import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class WorkCenterScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;
  const WorkCenterScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });
  @override
  State<WorkCenterScreen> createState() => _WorkCenterScreenState();
}

class _WorkCenterScreenState extends State<WorkCenterScreen> {
  List<dynamic> _items = [];
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.productionService.listWorkCenters();
      if (mounted) setState(() => _items = d);
    } catch (e) {
      if (mounted) _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Work Centers', style: TextStyle(fontSize: 16)),
      actions: [
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => _openDetail(),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  'No work centers',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _items.length,
            itemBuilder: (_, i) => _buildCard(_items[i]),
          ),
  );

  Widget _buildCard(dynamic e) {
    final code = e['code'] ?? '';
    final name = e['name'] ?? '';
    final type = e['work_center_type'] ?? '';
    final cap = (e['available_capacity'] as num?)?.toStringAsFixed(1) ?? '8.0';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(entry: e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.precision_manufacturing,
                  color: Colors.green.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$code - $name',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$type | Cap: ${cap}h | \$${(e['cost_per_hour'] as num?)?.toStringAsFixed(2) ?? '0.00'}/hr',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail({Map<String, dynamic>? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WorkCenterDetail(
          productionService: widget.productionService,
          entry: entry,
          onSaved: _load,
        ),
      ),
    );
  }
}

class _WorkCenterDetail extends StatefulWidget {
  final ProductionService productionService;
  final Map<String, dynamic>? entry;
  final VoidCallback onSaved;
  const _WorkCenterDetail({
    required this.productionService,
    this.entry,
    required this.onSaved,
  });
  @override
  State<_WorkCenterDetail> createState() => _WorkCenterDetailState();
}

class _WorkCenterDetailState extends State<_WorkCenterDetail> {
  final _codeCtrl = TextEditingController(),
      _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController(),
      _locationCtrl = TextEditingController();
  final _capCtrl = TextEditingController(text: '8.00'),
      _effCtrl = TextEditingController(text: '1.00'),
      _costCtrl = TextEditingController(text: '0');
  String _type = 'machine';
  bool _saving = false;
  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _populate();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _capCtrl.dispose();
    _effCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _populate() {
    final e = widget.entry;
    if (e == null) return;
    _codeCtrl.text = e['code'] ?? '';
    _nameCtrl.text = e['name'] ?? '';
    _descCtrl.text = e['description'] ?? '';
    _type = e['work_center_type'] ?? 'machine';
    _locationCtrl.text = e['plant_location'] ?? '';
    _capCtrl.text =
        (e['available_capacity'] as num?)?.toStringAsFixed(2) ?? '8.00';
    _effCtrl.text =
        (e['efficiency_rate'] as num?)?.toStringAsFixed(2) ?? '1.00';
    _costCtrl.text = (e['cost_per_hour'] as num?)?.toStringAsFixed(2) ?? '0.00';
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      _showMsg('Code and Name required');
      return;
    }
    setState(() => _saving = true);
    final data = {
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'work_center_type': _type,
      'available_capacity': double.tryParse(_capCtrl.text) ?? 8.00,
      'efficiency_rate': double.tryParse(_effCtrl.text) ?? 1.00,
      'cost_per_hour': double.tryParse(_costCtrl.text) ?? 0,
      'plant_location': _locationCtrl.text.trim(),
    };
    try {
      if (_isEdit) {
        await widget.productionService.updateWorkCenter(
          widget.entry!['id'].toString(),
          data,
        );
      } else {
        await widget.productionService.createWorkCenter(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _isEdit ? 'Edit Work Center' : 'New Work Center',
        style: const TextStyle(fontSize: 16),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code *',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                  ),
                  items: ['machine', 'assembly', 'labor', 'inspection']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name *',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              isDense: true,
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _capCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Daily Capacity (hours)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _effCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Efficiency Rate',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cost per Hour',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plant Location',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    ),
  );
}
