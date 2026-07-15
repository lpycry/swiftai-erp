import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/production/services/production_service.dart';
import 'package:swiftai_erp/features/production/screens/bom_screen.dart';
import 'package:swiftai_erp/features/production/screens/work_center_screen.dart';
import 'package:swiftai_erp/features/production/screens/routing_template_screen.dart';
import 'package:swiftai_erp/features/production/screens/production_order_screen.dart';
import 'package:swiftai_erp/features/production/screens/time_confirmation_screen.dart';
import 'package:swiftai_erp/features/production/screens/mps_review_screen.dart';
import 'package:swiftai_erp/features/production/screens/material_requirements_screen.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final AuthService authService;
  final ProductionService productionService;
  const ProductionDashboardScreen({
    super.key,
    required this.authService,
    required this.productionService,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: authService,
      currentIndex: 3,
      onIndexChanged: (_) {},
      title: 'Production',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.factory_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Production Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bill of Materials, Production Orders',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Master Data Section ──
            _sectionHeader('Master Data Management'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ProdCard(
                  icon: Icons.account_tree_rounded,
                  title: 'Bill of Materials (BOM)',
                  subtitle:
                      'Multi-version BOM with parent-child tree, scrap factor, valid-from/to',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BomScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
                _ProdCard(
                  icon: Icons.precision_manufacturing_rounded,
                  title: 'Work Centers',
                  subtitle:
                      'Define capacities, efficiency rates, cost per hour',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkCenterScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
                _ProdCard(
                  icon: Icons.route_rounded,
                  title: 'Routing Templates',
                  subtitle:
                      'Reusable process templates with sequenced operations & work centers',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoutingTemplateScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            // ── Production Execution Section ──
            _sectionHeader('Master Production Schedule (MPS)'),
            const SizedBox(height: 12),
            _MpsSection(
              authService: authService,
              productionService: productionService,
            ),

            const SizedBox(height: 32),
            _sectionHeader('Production Execution'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ProdCard(
                  icon: Icons.assignment_rounded,
                  title: 'Production Orders',
                  subtitle:
                      'Create and manage production orders with BOM, priority, and scheduling',
                  color: Colors.amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductionOrderScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
                _ProdCard(
                  icon: Icons.timer_rounded,
                  title: 'Production Order Time Confirmation',
                  subtitle: 'Confirm yield quantity and actual work hours',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductionTimeConfirmationScreen(
                        authService: authService,
                        productionService: productionService,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProdCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProdCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpsSection extends StatefulWidget {
  final AuthService authService;
  final ProductionService productionService;

  const _MpsSection({
    required this.authService,
    required this.productionService,
  });

  @override
  State<_MpsSection> createState() => _MpsSectionState();
}

class _MpsSectionState extends State<_MpsSection> {
  static const _baseUrl = 'http://localhost:8080/api/v1';

  List<dynamic> _sites = [];
  List<dynamic> _plannedOrders = [];
  List<dynamic> _mrpPurchaseRequisitions = [];
  Map<String, dynamic>? _lastRun;
  String? _siteId;
  String _planningMode = 'NEUPL';
  bool _timeFence = true;
  bool _runMrpAfterMps = true;
  bool _loading = false;
  int _fenceDays = 5;
  double _progress = 0;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadSites(), _loadPlannedOrders(), _loadMrpPRs()]);
  }

  Future<void> _loadSites() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/sites'),
        headers: {'Authorization': 'Bearer ${widget.authService.accessToken}'},
      );
      if (resp.statusCode < 400) {
        final all = (jsonDecode(resp.body)['data'] as List<dynamic>?) ?? [];
        final plants = all
            .where((s) => (s['site_type'] ?? '').toString() == 'plant')
            .toList();
        if (mounted) {
          setState(() {
            _sites = plants.isEmpty ? all : plants;
            if (_siteId == null && _sites.isNotEmpty) {
              _siteId = _sites.first['id']?.toString();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPlannedOrders() async {
    try {
      final list = await widget.productionService.listMPSPlannedOrders();
      if (mounted) setState(() => _plannedOrders = list);
    } catch (_) {}
  }

  Future<void> _loadMrpPRs() async {
    try {
      final list = await widget.productionService
          .listMRPPlannedPurchaseRequisitions();
      if (mounted) setState(() => _mrpPurchaseRequisitions = list);
    } catch (_) {}
  }

  Future<void> _runMps() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _progress = 0.08;
      _progressMessage = 'Starting MPS run...';
    });
    try {
      final result = await widget.productionService.runMPS({
        'site_id': _siteId,
        'planning_mode': _planningMode,
        'planning_time_fence_enabled': _timeFence,
        'planning_time_fence_days': _fenceDays,
        'run_mrp_after_mps': _runMrpAfterMps,
      });
      final progress = (result['progress'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _lastRun = result;
          _progress = 1;
          _progressMessage = progress.isNotEmpty
              ? progress.last['message']?.toString() ?? 'MPS run completed'
              : 'MPS run completed';
        });
      }
      await Future.wait([_loadPlannedOrders(), _loadMrpPRs()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFirm(Map<String, dynamic> order) async {
    final id = order['id']?.toString();
    if (id == null) return;
    final next = order['is_firmed'] != true;
    try {
      await widget.productionService.firmMPSPlannedOrder(id, next);
      await _loadPlannedOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openMpsPlannedOrder(Map<String, dynamic> order) async {
    var converting = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final convertedId = order['converted_production_order_id']
              ?.toString();
          final convertedNo = order['converted_order_number']?.toString() ?? '';
          final isConverted = convertedId != null && convertedId.isNotEmpty;
          return AlertDialog(
            title: Text(
              '${order['product_sku'] ?? ''} Planned Work Order',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    'Material',
                    '${order['product_sku'] ?? ''} - ${order['product_name'] ?? ''}',
                  ),
                  _detailRow('Plant', _plantLabel(order)),
                  _detailRow('Planned Qty', _fmt(order['planned_qty'])),
                  _detailRow('Due Date', order['due_date']?.toString() ?? ''),
                  _detailRow(
                    'Firmed',
                    order['is_firmed'] == true ? 'Yes' : 'No',
                  ),
                  _detailRow(
                    'Status',
                    isConverted
                        ? 'Converted to ${convertedNo.isEmpty ? convertedId : convertedNo}'
                        : 'Planned',
                  ),
                  if ((order['exception_message']?.toString() ?? '').isNotEmpty)
                    _detailRow(
                      'Exception',
                      '${order['exception_code'] ?? ''} ${order['exception_message'] ?? ''}',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: converting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              if (isConverted)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Work Order'),
                  onPressed: converting
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _openProductionOrder(convertedId);
                        },
                )
              else
                FilledButton.icon(
                  icon: converting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 16,
                        ),
                  label: Text(
                    converting ? 'Converting...' : 'Convert to Work Order',
                  ),
                  onPressed: converting
                      ? null
                      : () async {
                          setDialogState(() => converting = true);
                          try {
                            final po = await widget.productionService
                                .convertMPSPlannedOrder(order['id'].toString());
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            await _loadPlannedOrders();
                            _openProductionOrder(
                              po['id']?.toString(),
                              entry: po,
                            );
                          } catch (e) {
                            setDialogState(() => converting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openProductionOrder(
    String? id, {
    Map<String, dynamic>? entry,
  }) async {
    if (id == null || id.isEmpty) return;
    Map<String, dynamic> order = entry ?? {};
    if (order.isEmpty) {
      try {
        order = await widget.productionService.getProductionOrder(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionOrderDetailScreen(
          authService: widget.authService,
          productionService: widget.productionService,
          entry: order,
          onSaved: () {},
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _plantLabel(Map<String, dynamic> order) {
    final code = order['site_code']?.toString() ?? '';
    final name = order['site_name']?.toString() ?? '';
    final label = [code, name].where((v) => v.isNotEmpty).join(' - ');
    return label.isEmpty ? '-' : label;
  }

  @override
  Widget build(BuildContext context) {
    final exceptions = (_lastRun?['exceptions'] as List<dynamic>?) ?? [];
    final deps = (_lastRun?['dependent_demands'] as List<dynamic>?) ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(
                    labelText: 'Plant',
                    isDense: true,
                  ),
                  items: _sites
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(
                            '${s['site_code'] ?? ''} - ${s['site_name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _siteId = v),
                ),
              ),
              SizedBox(
                width: 360,
                child: DropdownButtonFormField<String>(
                  initialValue: _planningMode,
                  decoration: const InputDecoration(
                    labelText: 'Planning Mode',
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'NETCH',
                      child: Text(
                        'NETCH - Net change, recalculate changed MPS items',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'NEUPL',
                      child: Text(
                        'NEUPL - Full planning, rebuild selected plant',
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _planningMode = v ?? 'NEUPL'),
                ),
              ),
              SizedBox(
                width: 230,
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Planning Time Fence',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _timeFence,
                  onChanged: (v) => setState(() => _timeFence = v),
                ),
              ),
              SizedBox(
                width: 230,
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Run MRP after MPS',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _runMrpAfterMps,
                  onChanged: (v) => setState(() => _runMrpAfterMps = v),
                ),
              ),
              SizedBox(
                width: 92,
                child: TextFormField(
                  initialValue: _fenceDays.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Days',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _fenceDays = int.tryParse(v) ?? 5,
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _runMps,
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run Global MPS'),
              ),
            ],
          ),
          if (_loading || _progressMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: _loading ? null : _progress),
            const SizedBox(height: 6),
            Text(_progressMessage, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _reviewLink(
                context,
                'Planned Orders',
                _plannedOrders.length.toString(),
                Icons.event_note_rounded,
                Colors.indigo,
                0,
              ),
              _reviewLink(
                context,
                'MRP PR',
                _mrpPurchaseRequisitions.length.toString(),
                Icons.request_quote_rounded,
                Colors.purple,
                1,
              ),
              _materialRequirementsLink(context),
              _reviewLink(
                context,
                'Dependent Demands',
                deps.length.toString(),
                Icons.account_tree_rounded,
                Colors.teal,
                2,
              ),
              _reviewLink(
                context,
                'Exceptions',
                exceptions.length.toString(),
                Icons.warning_amber_rounded,
                Colors.orange,
                3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _materialRequirementsLink(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialRequirementsScreen(
            authService: widget.authService,
            productionService: widget.productionService,
          ),
        ),
      ),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.table_chart_outlined,
              color: Colors.blueGrey,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Materials Request List',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'MD04',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _reviewLink(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    int tab,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MpsReviewScreen(
            authService: widget.authService,
            productionService: widget.productionService,
            initialTab: tab,
          ),
        ),
      ),
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }
}
