import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';

class ProductionTimeConfirmationScreen extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;

  const ProductionTimeConfirmationScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  State<ProductionTimeConfirmationScreen> createState() =>
      _ProductionTimeConfirmationScreenState();
}

class _ProductionTimeConfirmationScreenState
    extends State<ProductionTimeConfirmationScreen> {
  bool _loading = true;
  bool _posting = false;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _operations = [];
  List<Map<String, dynamic>> _confirmations = [];
  Map<String, dynamic>? _selectedOrder;
  Map<String, dynamic>? _selectedOperation;
  DateTime _confirmationDate = DateTime.now();

  final _yieldCtrl = TextEditingController();
  final _scrapCtrl = TextEditingController(text: '0');
  final _reworkCtrl = TextEditingController(text: '0');
  final _setupHoursCtrl = TextEditingController(text: '0');
  final _laborHoursCtrl = TextEditingController(text: '0');
  final _machineHoursCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _yieldCtrl.dispose();
    _scrapCtrl.dispose();
    _reworkCtrl.dispose();
    _setupHoursCtrl.dispose();
    _laborHoursCtrl.dispose();
    _machineHoursCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final released = await widget.productionService.listProductionOrders(
        status: 'RELEASED',
      );
      final inProcess = await widget.productionService.listProductionOrders(
        status: 'IN_PROCESS',
      );
      final partiallyProduced = await widget.productionService
          .listProductionOrders(status: 'PARTIALLY_PRODUCED');
      _orders = [...released, ...inProcess, ...partiallyProduced]
          .map((e) => e as Map<String, dynamic>)
          .where((o) => _remaining(o) > 0)
          .toList();
      _orders.sort(
        (a, b) => (b['created_at'] ?? '').toString().compareTo(
          (a['created_at'] ?? '').toString(),
        ),
      );
    } catch (e) {
      _snack('Load production orders failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectOrder(String? id) async {
    if (id == null) {
      setState(() {
        _selectedOrder = null;
        _selectedOperation = null;
        _operations = [];
        _confirmations = [];
        _yieldCtrl.clear();
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final order = await widget.productionService.getProductionOrder(id);
      final routing = await widget.productionService.getProductionOrderRouting(
        id,
      );
      final confirmations = await widget.productionService
          .listTimeConfirmations(id);
      setState(() {
        _selectedOrder = order;
        _operations = ((routing?['operations'] as List<dynamic>?) ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _selectedOperation = _operations.isNotEmpty ? _operations.first : null;
        _confirmations = confirmations
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _yieldCtrl.text = _fmt(_remaining(order));
      });
    } catch (e) {
      _snack('Load order failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _confirmationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_confirmationDate),
    );
    setState(() {
      _confirmationDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _confirmationDate.hour,
        time?.minute ?? _confirmationDate.minute,
      );
    });
  }

  Future<void> _submit() async {
    final order = _selectedOrder;
    if (order == null) {
      _snack('Please select a production order.', Colors.red);
      return;
    }
    if (_operations.isNotEmpty && _selectedOperation == null) {
      _snack('Please select an operation.', Colors.red);
      return;
    }
    final yieldQty = double.tryParse(_yieldCtrl.text.trim()) ?? 0;
    final scrapQty = double.tryParse(_scrapCtrl.text.trim()) ?? 0;
    final reworkQty = double.tryParse(_reworkCtrl.text.trim()) ?? 0;
    final setupHours = double.tryParse(_setupHoursCtrl.text.trim()) ?? 0;
    final laborHours = double.tryParse(_laborHoursCtrl.text.trim()) ?? 0;
    final machineHours = double.tryParse(_machineHoursCtrl.text.trim()) ?? 0;
    final remaining = _remaining(order);
    if (yieldQty <= 0 || yieldQty > remaining) {
      _snack(
        'Yield quantity must be between 0 and ${_fmt(remaining)}.',
        Colors.red,
      );
      return;
    }
    if ([
      scrapQty,
      reworkQty,
      setupHours,
      laborHours,
      machineHours,
    ].any((v) => v < 0)) {
      _snack('Quantities and hours cannot be negative.', Colors.red);
      return;
    }

    setState(() => _posting = true);
    try {
      await widget.productionService
          .createTimeConfirmation(order['id'].toString(), {
            if (_selectedOperation != null)
              'operation_id': _selectedOperation!['id'],
            'yield_qty': yieldQty,
            'scrap_qty': scrapQty,
            'rework_qty': reworkQty,
            'setup_hours': setupHours,
            'labor_hours': laborHours,
            'machine_hours': machineHours,
            'actual_work_hours': setupHours + laborHours + machineHours,
            'confirmation_date': _confirmationDate.toIso8601String(),
            'notes': _notesCtrl.text.trim(),
          });
      _snack('Time confirmation posted.', Colors.green);
      _setupHoursCtrl.text = '0';
      _laborHoursCtrl.text = '0';
      _machineHoursCtrl.text = '0';
      _scrapCtrl.text = '0';
      _reworkCtrl.text = '0';
      _notesCtrl.clear();
      await _selectOrder(order['id'].toString());
      await _load();
    } catch (e) {
      _snack('Post confirmation failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  double _remaining(Map<String, dynamic> order) {
    final orderQty = (order['order_qty'] as num?)?.toDouble() ?? 0;
    final completedQty = (order['completed_qty'] as num?)?.toDouble() ?? 0;
    final rem = orderQty - completedQty;
    return rem > 0 ? rem : 0;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _dt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dateFromRaw(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return '-';
    try {
      return _dt(DateTime.parse(text).toLocal());
    } catch (_) {
      return text.length > 16 ? text.substring(0, 16) : text;
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final order = _selectedOrder;
    final remaining = order == null ? 0.0 : _remaining(order);

    return AppLayout(
      authService: widget.authService,
      currentIndex: 3,
      onIndexChanged: (_) {},
      title: 'Production Order Time Confirmation',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Production Order', Colors.deepPurple, [
                    DropdownButtonFormField<String>(
                      value: order?['id']?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Production Order *',
                        prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                      ),
                      isExpanded: true,
                      items: _orders.map((o) {
                        return DropdownMenuItem(
                          value: o['id']?.toString(),
                          child: Text(
                            '${o['order_number'] ?? ''} | ${o['material_sku'] ?? ''} ${o['material_name'] ?? ''} | Remaining ${_fmt(_remaining(o))}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _selectOrder,
                    ),
                  ]),
                  if (order != null) ...[
                    const SizedBox(height: 12),
                    _section('Order Summary', Colors.indigo, [
                      _row(
                        'Order',
                        order['order_number']?.toString() ?? '-',
                        true,
                      ),
                      _row(
                        'Material',
                        '${order['material_sku'] ?? ''} ${order['material_name'] ?? ''}',
                      ),
                      _row('Status', order['status']?.toString() ?? '-'),
                      _row(
                        'Qty',
                        '${_fmt((order['completed_qty'] as num?)?.toDouble() ?? 0)} / ${_fmt((order['order_qty'] as num?)?.toDouble() ?? 0)}',
                      ),
                      _row('Remaining', _fmt(remaining), true),
                    ]),
                    const SizedBox(height: 12),
                    _section('Confirmation', Colors.green, [
                      if (_operations.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedOperation?['id']?.toString(),
                          decoration: InputDecoration(
                            labelText: 'Operation *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: _operations.map((op) {
                            return DropdownMenuItem(
                              value: op['id']?.toString(),
                              child: Text(
                                '${op['operation_no'] ?? ''} ${op['operation_name'] ?? ''} | ${op['work_center_code'] ?? ''} ${op['work_center_name'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (id) => setState(() {
                            _selectedOperation = _operations
                                .cast<Map<String, dynamic>?>()
                                .firstWhere(
                                  (op) => op?['id']?.toString() == id,
                                  orElse: () => null,
                                );
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _yieldCtrl,
                              decoration: InputDecoration(
                                labelText: 'Yield Qty *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _scrapCtrl,
                              decoration: InputDecoration(
                                labelText: 'Scrap Qty',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _reworkCtrl,
                              decoration: InputDecoration(
                                labelText: 'Rework Qty',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _setupHoursCtrl,
                              decoration: InputDecoration(
                                labelText: 'Setup Hours',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _laborHoursCtrl,
                              decoration: InputDecoration(
                                labelText: 'Labor Hours',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _machineHoursCtrl,
                              decoration: InputDecoration(
                                labelText: 'Machine Hours',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 18),
                              label: Text(_dt(_confirmationDate)),
                              onPressed: _pickDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: _posting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _posting ? 'Posting...' : 'Post Confirmation',
                          ),
                          onPressed: _posting ? null : _submit,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _section('Confirmation History', Colors.blueGrey, [
                      if (_confirmations.isEmpty)
                        Text(
                          'No confirmations yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        )
                      else
                        ..._confirmations.map((c) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.access_time_filled_outlined,
                            ),
                            title: Text(
                              '${c['operation_no'] ?? ''} ${c['operation_name'] ?? ''} | Yield ${_fmt((c['yield_qty'] as num?)?.toDouble() ?? 0)} | Scrap ${_fmt((c['scrap_qty'] as num?)?.toDouble() ?? 0)} | Rework ${_fmt((c['rework_qty'] as num?)?.toDouble() ?? 0)}',
                            ),
                            subtitle: Text(
                              '${_dateFromRaw(c['confirmation_date'])} | Setup ${_fmt((c['setup_hours'] as num?)?.toDouble() ?? 0)}h, Labor ${_fmt((c['labor_hours'] as num?)?.toDouble() ?? 0)}h, Machine ${_fmt((c['machine_hours'] as num?)?.toDouble() ?? 0)}h',
                            ),
                          );
                        }),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _section(String title, Color color, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, [bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
