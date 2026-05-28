import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/logistics/services/warehouse_service.dart';

class CycleCountScreen extends StatefulWidget {
  final AuthService authService; final WarehouseService warehouseService;
  const CycleCountScreen({super.key, required this.authService, required this.warehouseService});
  @override State<CycleCountScreen> createState() => _CycleCountScreenState();
}

class _CycleCountScreenState extends State<CycleCountScreen> {
  List<dynamic> _counts = []; bool _loading = false; bool _aiLoading = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try { final d = await widget.warehouseService.listCycleCounts(); if (mounted) setState(() => _counts = d); }
    catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _aiSuggest() async {
    setState(() => _aiLoading = true);
    try {
      await widget.warehouseService.aiSuggestCycleCounts();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI count suggestions generated'), backgroundColor: Colors.green)); _load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor)); }
    finally { if (mounted) setState(() => _aiLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(authService: widget.authService, currentIndex: 2, onIndexChanged: (_) {}, title: 'Cycle Count',
      body: Column(children: [
        Container(padding: const EdgeInsets.all(12), child: Row(children: [
          Text('${_counts.length} count(s)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          _CountStatusBadge(_counts.where((c) => c['status'] == 'open').length, 'Open', Colors.blue),
          const SizedBox(width: 8),
          _CountStatusBadge(_counts.where((c) => c['status'] == 'counted').length, 'Counted', Colors.green),
          const SizedBox(width: 12),
          OutlinedButton.icon(icon: _aiLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI Suggest', style: TextStyle(fontSize: 11)), onPressed: _aiLoading ? null : _aiSuggest,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ])),
        const Divider(height: 1),
        if (_counts.isNotEmpty)
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), color: Colors.grey.shade100,
            child: Row(children: [
              const Expanded(flex: 2, child: Text('Count No', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              const Expanded(flex: 1, child: Text('Bin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
              Expanded(flex: 1, child: Text('Status', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
            ]),
          ),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _counts.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.how_to_reg, size: 48, color: Colors.grey.shade300), const SizedBox(height: 8),
                Text('No cycle counts', style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 12),
                ElevatedButton.icon(icon: const Icon(Icons.auto_awesome, size: 16), label: const Text('AI Suggest Counts'),
                  onPressed: _aiLoading ? null : _aiSuggest),
              ]))
            : ListView.builder(padding: const EdgeInsets.symmetric(vertical: 4), itemCount: _counts.length,
                itemBuilder: (_, i) => _CountRow(c: _counts[i]))
        ),
      ]),
    );
  }
}

class _CountStatusBadge extends StatelessWidget {
  final int count; final String label; final Color color;
  const _CountStatusBadge(this.count, this.label, this.color);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text('$count $label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)));
}

class _CountRow extends StatelessWidget {
  final dynamic c;
  const _CountRow({required this.c});

  Color _stColor(String s) => switch(s) { 'open' => Colors.blue, 'in_progress' => Colors.orange, 'counted' => Colors.green, 'verified' => Colors.teal, 'closed' => Colors.grey, _ => Colors.grey };
  String _typeLabel(String t) => switch(t) { 'cycle' => 'Cycle', 'annual' => 'Annual', 'adhoc' => 'Ad-hoc', 'aiprompted' => '🤖 AI', _ => t };

  @override Widget build(BuildContext context) {
    final countNo = c['count_no'] ?? c['id']?.toString().substring(0, 8) ?? '';
    final countType = c['count_type'] ?? 'cycle';
    final prodName = c['product_name'] ?? '';
    final binCode = c['bin_code'] ?? '';
    final status = c['status'] ?? 'open';
    final ai = c['ai_suggested'] == true;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(ai ? '🤖 $countNo' : countNo, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        Expanded(flex: 2, child: Text(_typeLabel(countType), style: TextStyle(fontSize: 10, color: ai ? Colors.deepPurple : Colors.grey.shade600))),
        Expanded(flex: 2, child: Text(prodName, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(binCode, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        Expanded(flex: 1, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: _stColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
          child: Text(status.toUpperCase(), textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _stColor(status)))),
        ),
      ]),
    );
  }
}
