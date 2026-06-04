import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/admin/services/admin_service.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';

class AuthObjectsScreen extends StatefulWidget {
  final AuthService authService;
  final AdminService adminService;
  const AuthObjectsScreen({
    super.key,
    required this.authService,
    required this.adminService,
  });

  @override
  State<AuthObjectsScreen> createState() => _AuthObjectsScreenState();
}

class _AuthObjectsScreenState extends State<AuthObjectsScreen> {
  List<dynamic> _objects = [];
  bool _loading = true;
  String? _classFilter;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    setState(() => _loading = true);
    try {
      final objects = await widget.adminService.getAuthObjects(classFilter: _classFilter);
      setState(() => _objects = objects);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 6,
      onIndexChanged: (_) {},
      title: 'Authorization Objects',
      body: Column(
        children: [
          // Class filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip('All', null, _classFilter == null, () {
                  setState(() => _classFilter = null);
                  _loadObjects();
                }),
                const SizedBox(width: 8),
                _FilterChip('Finance', 'finance', _classFilter == 'finance', () {
                  setState(() => _classFilter = 'finance');
                  _loadObjects();
                }),
                const SizedBox(width: 8),
                _FilterChip('Logistics', 'logistics', _classFilter == 'logistics', () {
                  setState(() => _classFilter = 'logistics');
                  _loadObjects();
                }),
                const SizedBox(width: 8),
                _FilterChip('Admin', 'admin', _classFilter == 'admin', () {
                  setState(() => _classFilter = 'admin');
                  _loadObjects();
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadObjects,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _objects.isEmpty
                    ? const Center(child: Text('No auth objects found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _objects.length,
                        itemBuilder: (context, i) => _ObjectCard(obj: _objects[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ObjectCard extends StatelessWidget {
  final dynamic obj;
  const _ObjectCard({required this.obj});

  @override
  Widget build(BuildContext context) {
    final activities = (obj['activities'] as List<dynamic>?)?.join(', ') ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    obj['object_class'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    obj['object_code'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
            if (obj['description'] != null && obj['description'] != '') ...[
              const SizedBox(height: 4),
              Text(obj['description'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(activities, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
