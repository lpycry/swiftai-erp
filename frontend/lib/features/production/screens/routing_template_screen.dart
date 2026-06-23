import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class RoutingTemplateScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;

  const RoutingTemplateScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  State<RoutingTemplateScreen> createState() => _RoutingTemplateScreenState();
}

class _RoutingTemplateScreenState extends State<RoutingTemplateScreen> {
  List<dynamic> _templates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.productionService.listRoutingTemplates();
      if (mounted) setState(() => _templates = d);
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

  void _openDetail({Map<String, dynamic>? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoutingTemplateDetail(
          productionService: widget.productionService,
          entry: entry,
          onSaved: _load,
        ),
      ),
    );
  }

  Widget _buildCard(dynamic e) {
    final code = e['template_code'] ?? '';
    final name = e['template_name'] ?? '';
    final ver = e['version'] ?? '';
    final setup = (e['total_setup_min'] as num?)?.toDouble() ?? 0;
    final run = (e['total_run_min'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(entry: Map<String, dynamic>.from(e as Map)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.route, color: Colors.blue.shade300, size: 20),
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
                      '$ver | Setup: ${setup.toStringAsFixed(1)}min | Run: ${run.toStringAsFixed(1)}min',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Routing Templates', style: TextStyle(fontSize: 16)),
      actions: [
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => _openDetail(),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _templates.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  'No routing templates',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Template'),
                  onPressed: () => _openDetail(),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _templates.length,
            itemBuilder: (_, i) => _buildCard(_templates[i]),
          ),
  );
}

class _RoutingTemplateDetail extends StatefulWidget {
  final ProductionService productionService;
  final Map<String, dynamic>? entry;
  final VoidCallback onSaved;

  const _RoutingTemplateDetail({
    required this.productionService,
    this.entry,
    required this.onSaved,
  });

  @override
  State<_RoutingTemplateDetail> createState() => _RoutingTemplateDetailState();
}

class _RoutingTemplateDetailState extends State<_RoutingTemplateDetail> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _verCtrl = TextEditingController(text: 'V1');

  bool _saving = false;
  bool _loadingOps = false;

  List<dynamic> _workCenters = [];
  final List<Map<String, dynamic>> _ops = [];

  bool get _isEdit => widget.entry != null;
  String? get _templateId => widget.entry?['id']?.toString();

  @override
  void initState() {
    super.initState();
    _populate();
    _loadWC();

    if (_isEdit) {
      _loadTemplateDetail();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _verCtrl.dispose();
    super.dispose();
  }

  void _populate() {
    final e = widget.entry;
    if (e == null) return;

    _codeCtrl.text = e['template_code'] ?? '';
    _nameCtrl.text = e['template_name'] ?? '';
    _descCtrl.text = e['description'] ?? '';
    _verCtrl.text = e['version'] ?? 'V1';
  }

  Future<void> _loadTemplateDetail() async {
    if (_templateId == null) return;

    setState(() => _loadingOps = true);

    try {
      final d = await widget.productionService.getRoutingTemplate(_templateId!);
      if (!mounted) return;

      final operations = d['operations'] as List? ?? [];

      setState(() {
        _ops.clear();
        for (final op in operations) {
          _ops.add(Map<String, dynamic>.from(op as Map));
        }
      });
    } catch (e) {
      if (mounted) _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingOps = false);
    }
  }

  Future<void> _loadWC() async {
    try {
      final d = await widget.productionService.listWorkCenters();
      if (mounted) setState(() => _workCenters = d);
    } catch (_) {}
  }

  void _addOp([Map<String, dynamic>? data]) {
    setState(() {
      _ops.add(
        data ??
            {
              'id': null,
              'operation_no': (_ops.length + 1) * 10,
              'operation_name': '',
              'description': '',
              'work_center_id': null,
              'work_center_name': '',
              'setup_time_min': 0.0,
              'run_time_min': 0.0,
            },
      );
    });
  }

  void _deleteOp(int idx) {
    setState(() => _ops.removeAt(idx));
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      _showMsg('Code and Name required', isError: true);
      return;
    }

    for (int i = 0; i < _ops.length; i++) {
      final op = _ops[i];

      if ((op['operation_name'] ?? '').toString().trim().isEmpty) {
        _showMsg('Operation name required at row ${i + 1}', isError: true);
        return;
      }

      if (op['work_center_id'] == null ||
          op['work_center_id'].toString().isEmpty) {
        _showMsg('Work center required at row ${i + 1}', isError: true);
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final operations = _ops.asMap().entries.map((entry) {
        final i = entry.key;
        final op = entry.value;

        return {
          if (op['id'] != null && op['id'].toString().isNotEmpty)
            'id': op['id'],
          'operation_no': op['operation_no'] ?? ((i + 1) * 10),
          'operation_name': (op['operation_name'] ?? '').toString().trim(),
          'description': op['description'] ?? '',
          'work_center_id': op['work_center_id'],
          'setup_time_min':
              double.tryParse(op['setup_time_min'].toString()) ?? 0.0,
          'run_time_min': double.tryParse(op['run_time_min'].toString()) ?? 0.0,
        };
      }).toList();

      if (_isEdit) {
        await widget.productionService.updateRoutingTemplate(_templateId!, {
          'template_code': _codeCtrl.text.trim(),
          'template_name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'version': _verCtrl.text.trim(),
          'operations': operations,
        });
      } else {
        final result = await widget.productionService.createRoutingTemplate({
          'template_code': _codeCtrl.text.trim(),
          'template_name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'version': _verCtrl.text.trim(),
        });

        final newTemplateId = result['id']?.toString();

        if (newTemplateId != null && newTemplateId.isNotEmpty) {
          await widget.productionService.updateRoutingTemplate(newTemplateId, {
            'operations': operations,
          });
        }
      }

      widget.onSaved();

      if (mounted) {
        _showMsg('Routing template saved');
        Navigator.pop(context);
      }
    } catch (e) {
      _showMsg('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTemplate() async {
    if (_templateId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routing Template'),
        content: const Text(
          'Are you sure you want to delete this routing template?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.productionService.deleteRoutingTemplate(_templateId!);
      widget.onSaved();

      if (mounted) {
        _showMsg('Routing template deleted');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showMsg('$e', isError: true);
    }
  }

  void _showMsg(String m, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: isError ? AppTheme.errorColor : Colors.green,
        ),
      );

  Widget _buildOpRow(int idx) {
    final op = _ops[idx];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${op['operation_no'] ?? (idx + 1) * 10}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: op['operation_name'] ?? '',
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (v) => op['operation_name'] = v,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final wcList = _workCenters
                    .where(
                      (w) => w['is_active'] == true || w['is_active'] == null,
                    )
                    .toList();

                if (!mounted || wcList.isEmpty) return;

                final selected = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Select Work Center'),
                    children: wcList
                        .map(
                          (w) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, w),
                            child: Text(
                              '${w['code']} - ${w['name']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );

                if (selected != null && mounted) {
                  setState(() {
                    op['work_center_id'] = selected['id']?.toString();
                    op['work_center_name'] = selected['name'] ?? '';
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: op['work_center_id'] != null
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  op['work_center_name']?.isNotEmpty == true
                      ? op['work_center_name']
                      : 'Select...',
                  style: TextStyle(
                    fontSize: 11,
                    color: op['work_center_id'] != null
                        ? Colors.blue.shade800
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: '${op['setup_time_min'] ?? 0}',
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    op['setup_time_min'] = double.tryParse(v) ?? 0.0,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: '${op['run_time_min'] ?? 0}',
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    op['run_time_min'] = double.tryParse(v) ?? 0.0,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.red.shade300,
              ),
              onPressed: () => _deleteOp(idx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _isEdit ? 'Routing Template' : 'New Template',
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        if (_isEdit)
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppTheme.errorColor,
            ),
            onPressed: _deleteTemplate,
          ),
      ],
    ),
    body: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Template Code *',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Template Name *',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _verCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Version',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Operations (${_ops.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Operation',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () => _addOp(),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Template',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.grey.shade50,
          child: const Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '#',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Operation',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  'Work Center',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Setup',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Run',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(width: 36),
            ],
          ),
        ),
        Expanded(
          child: _loadingOps
              ? const Center(child: CircularProgressIndicator())
              : _ops.isEmpty
              ? Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Operation',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _addOp(),
                  ),
                )
              : ListView.builder(
                  itemCount: _ops.length,
                  itemBuilder: (_, i) => _buildOpRow(i),
                ),
        ),
        if (_ops.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              'Total Setup: ${_ops.fold(0.0, (sum, o) => sum + (double.tryParse(o['setup_time_min'].toString()) ?? 0.0))}min | '
              'Total Run: ${_ops.fold(0.0, (sum, o) => sum + (double.tryParse(o['run_time_min'].toString()) ?? 0.0))}min',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
      ],
    ),
  );
}
