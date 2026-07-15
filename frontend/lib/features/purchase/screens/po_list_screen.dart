import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/po_detail_screen.dart';
import 'package:swiftai_erp/features/purchase/screens/po_form_screen.dart';

class POListScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const POListScreen({
    super.key,
    required this.authService,
    required this.purchaseService,
  });

  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen> {
  List<PurchaseOrderModel> _pos = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const _statuses = [
    '',
    'DRAFT',
    'CONFIRMED',
    'RECEIVED',
    'INVOICED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _loadPOs();
  }

  Future<void> _loadPOs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _pos = await widget.purchaseService.listPOs(status: _statusFilter);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted)
      setState(() {
        _loading = false;
      });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.blue;
      case 'CONFIRMED':
        return Colors.indigo;
      case 'RECEIVED':
        return Colors.teal;
      case 'INVOICED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openEdit(PurchaseOrderModel po) async {
    try {
      final fullPO = await widget.purchaseService.getPO(po.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => POFormScreen(
            authService: widget.authService,
            purchaseService: widget.purchaseService,
            po: fullPO,
          ),
        ),
      );
      _loadPOs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New PO',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => POFormScreen(
                    authService: widget.authService,
                    purchaseService: widget.purchaseService,
                  ),
                ),
              );
              _loadPOs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statuses.map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.isEmpty ? 'All' : s),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _statusFilter = s.isEmpty ? null : s);
                      _loadPOs();
                    },
                    visualDensity: VisualDensity.compact,
                    selectedColor: _statusColor(
                      s.isEmpty ? '' : s,
                    ).withValues(alpha: 0.15),
                    checkmarkColor: _statusColor(s.isEmpty ? '' : s),
                  ),
                );
              }).toList(),
            ),
          ),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPOs, child: const Text('Retry')),
          ],
        ),
      );
    if (_pos.isEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No purchase orders',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );

    return RefreshIndicator(
      onRefresh: _loadPOs,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _pos.length,
        itemBuilder: (_, i) {
          final po = _pos[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final fullPO = await widget.purchaseService.getPO(po.id);
                if (mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PODetailScreen(
                        authService: widget.authService,
                        purchaseService: widget.purchaseService,
                        po: fullPO,
                      ),
                    ),
                  );
                  _loadPOs();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _statusColor(po.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description,
                          color: _statusColor(po.status),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                po.poNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    po.status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  po.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(po.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            po.vendorName.isNotEmpty
                                ? po.vendorName
                                : po.vendorCode,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${po.currency} ${PurchaseService.fmtAmount(po.totalAmount)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (po.status == 'DRAFT')
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEdit(po),
                          ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
