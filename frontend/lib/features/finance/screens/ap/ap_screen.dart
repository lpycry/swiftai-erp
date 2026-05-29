import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_create_screen.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_list_screen.dart';

class APScreen extends StatelessWidget {
  final AuthService authService;
  final ApService apService;

  const APScreen({
    super.key,
    required this.authService,
    required this.apService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts Payable')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.payments_rounded, size: 28,
                        color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 12),
                    Text('Down Payment Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Vendor prepayments with SAP-style special GL posting',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Menu Cards ──
            _MenuCard(
              icon: Icons.add_circle_outline,
              title: 'Create Down Payment',
              subtitle: 'Vendor prepayment with auto GL posting',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DPCreateScreen(
                      authService: authService, apService: apService))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.list_alt,
              title: 'Down Payment List',
              subtitle: 'View, search & manage down payments',
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DPListScreen(
                      authService: authService, apService: apService))),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
    );
  }
}
