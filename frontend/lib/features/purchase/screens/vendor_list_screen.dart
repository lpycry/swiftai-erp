import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/purchase/services/purchase_service.dart';
import 'package:swiftai_erp/features/purchase/screens/vendor_form_screen.dart';

class VendorListScreen extends StatefulWidget {
  final AuthService authService;
  final PurchaseService purchaseService;
  const VendorListScreen({super.key, required this.authService, required this.purchaseService});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  List<VendorModel> _vendors = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVendors({String? query}) async {
    setState(() { _loading = true; _error = null; });
    try {
      _vendors = await widget.purchaseService.listVendors(query: query);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() { _loading = false; });
  }

  // ignore: unused_element
  Future<void> _deleteVendor(VendorModel v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Delete "${v.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.purchaseService.deleteVendor(v.id);
      _loadVendors(query: _searchController.text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.orange;
      case 'blacklisted': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors'), actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'New Vendor',
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => VendorFormScreen(authService: widget.authService, purchaseService: widget.purchaseService),
            ));
            _loadVendors(query: _searchController.text);
          },
        ),
      ]),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by code, name or tax number...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _loadVendors(); })
                    : null,
              ),
              onSubmitted: (v) => _loadVendors(query: v),
              onChanged: (v) {
                setState(() {});
              },
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
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => _loadVendors(), child: const Text('Retry')),
    ]));
    if (_vendors.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade400),
      const SizedBox(height: 12),
      Text('No vendors found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('Create a new vendor to get started', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]));

    return RefreshIndicator(
      onRefresh: () => _loadVendors(query: _searchController.text),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _vendors.length,
        itemBuilder: (_, i) {
          final v = _vendors[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => VendorFormScreen(authService: widget.authService, purchaseService: widget.purchaseService, vendor: v),
                ));
                _loadVendors(query: _searchController.text);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: v.aiRating >= 4 ? Colors.green.withValues(alpha: 0.12) : Colors.indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(v.name.isNotEmpty ? v.name[0].toUpperCase() : 'V',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: v.aiRating >= 4 ? Colors.green : Colors.indigo))),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(v.vendorCode, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(v.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(v.status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(v.status))),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(v.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (v.contactEmail.isNotEmpty)
                        Text(v.contactEmail, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      if (v.contactEmail.isNotEmpty && v.contactPhone.isNotEmpty)
                        Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                      if (v.contactPhone.isNotEmpty)
                        Text(v.contactPhone, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  // AI rating
                  if (v.aiRating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: v.aiRating >= 4 ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome, size: 12, color: v.aiRating >= 4 ? Colors.green : Colors.amber),
                        const SizedBox(width: 4),
                        Text(v.aiRating.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: v.aiRating >= 4 ? Colors.green : Colors.amber)),
                      ]),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
