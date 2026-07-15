import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/cost_center_service.dart';

class CostCenterScreen extends StatefulWidget {
  final AuthService authService;
  final CostCenterService costCenterService;

  const CostCenterScreen({
    super.key,
    required this.authService,
    required this.costCenterService,
  });

  @override
  State<CostCenterScreen> createState() => _CostCenterScreenState();
}

class _CostCenterScreenState extends State<CostCenterScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _q => _searchCtrl.text.trim();

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await widget.costCenterService.getCostCenters(search: _q);
    } catch (e) {
      if (mounted) _msg('Failed to load: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _msg(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Create Dialog
  // ═══════════════════════════════════════

  void _showCreateDialog() {
    final idCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final fromCtrl = TextEditingController(text: _today());
    final toCtrl = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('New Cost Center'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cost Center ID *',
                    hintText: 'e.g. CC-1001',
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g. R&D Department',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    hintText: 'e.g. Admin, Production, R&D',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid From',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid To (optional)',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v ?? true),
                  title: const Text('Active', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (idCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
                try {
                  await widget.costCenterService.createCostCenter({
                    'cost_center_id': idCtrl.text,
                    'description': descCtrl.text,
                    'cost_center_type': typeCtrl.text,
                    'is_active': isActive,
                    'valid_from': fromCtrl.text,
                    'valid_to': toCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  _msg('Cost center created');
                } catch (e) {
                  _msg('$e', isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Edit Dialog
  // ═══════════════════════════════════════

  void _showEditDialog(dynamic item) {
    final descCtrl = TextEditingController(text: item['description'] ?? '');
    final typeCtrl = TextEditingController(
      text: item['cost_center_type'] ?? '',
    );
    final fromCtrl = TextEditingController(
      text: _cleanDate(item['valid_from']),
    );
    final toCtrl = TextEditingController(text: _cleanDate(item['valid_to']));
    bool isActive = item['is_active'] as bool? ?? true;
    final itemId = item['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Edit — ${item['cost_center_id'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    hintText: 'e.g. Admin, Production, R&D',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid From',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valid To',
                          hintText: 'YYYY-MM-DD',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v ?? true),
                  title: const Text('Active', style: TextStyle(fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (descCtrl.text.isEmpty) return;
                try {
                  await widget.costCenterService.updateCostCenter(itemId, {
                    'description': descCtrl.text,
                    'cost_center_type': typeCtrl.text,
                    'is_active': isActive,
                    'valid_from': fromCtrl.text,
                    'valid_to': toCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  _msg('Cost center updated');
                } catch (e) {
                  _msg('$e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  Delete Confirmation
  // ═══════════════════════════════════════

  Future<void> _confirmDelete(dynamic item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cost Center'),
        content: Text(
          'Delete "${item['cost_center_id']} — ${item['description']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.costCenterService.deleteCostCenter(item['id'].toString());
        _load();
        _msg('Cost center deleted');
      } catch (e) {
        _msg('$e', isError: true);
      }
    }
  }

  // ═══════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _cleanDate(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    return Fmt.dateStr(d);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Cost Centers',
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by ID, description or type...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Cost Centers',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (_q.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    '${_items.length} result(s)',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: _showCreateDialog,
                  tooltip: 'Add Cost Center',
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _q.isNotEmpty
                              ? 'No cost centers match "$_q"'
                              : 'No cost centers defined',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => _CCCard(
                      item: _items[i],
                      onEdit: () => _showEditDialog(_items[i]),
                      onDelete: () => _confirmDelete(_items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CCCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CCCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = item['is_active'] as bool? ?? true;
    final validTo = item['valid_to']?.toString() ?? '';
    final isExpired =
        !isActive ||
        (validTo.isNotEmpty &&
            validTo != '0001-01-01' &&
            DateTime.tryParse(validTo) != null &&
            DateTime.parse(validTo).isBefore(DateTime.now()));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isExpired ? Colors.grey : AppTheme.primaryColor).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              Icons.account_balance_outlined,
              color: isExpired ? Colors.grey : AppTheme.primaryColor,
              size: 22,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              item['cost_center_id'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'monospace',
                color: isExpired ? Colors.grey : null,
              ),
            ),
            const SizedBox(width: 8),
            if (item['cost_center_type'] != null &&
                item['cost_center_type'] != '')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item['cost_center_type'],
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['description'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.date_range, size: 10, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(
                  _fmtDate(item['valid_from']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
                if (validTo.isNotEmpty && validTo != '0001-01-01') ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 10,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _fmtDate(validTo),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (!isExpired && isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
                if (isExpired || !isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Inactive',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.blue.shade400,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.shade400,
              ),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty || d == '0001-01-01') return '';
    return Fmt.dateStr(d);
  }
}
