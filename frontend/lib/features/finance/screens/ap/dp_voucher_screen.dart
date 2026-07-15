import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/fmt.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/finance/services/ap_service.dart';
import 'package:swiftai_erp/features/finance/screens/ap/dp_create_screen.dart';

class DPVoucherScreen extends StatelessWidget {
  final AuthService authService;
  final ApService apService;
  final DownPaymentModel downPayment;

  const DPVoucherScreen({
    super.key,
    required this.authService,
    required this.apService,
    required this.downPayment,
  });

  @override
  Widget build(BuildContext context) {
    final dp = downPayment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Down Payment Voucher'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Success Header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dp.status == 'POSTED'
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  dp.status == 'POSTED'
                      ? Colors.green.shade500
                      : Colors.orange.shade500,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  dp.status == 'POSTED'
                      ? Icons.check_circle
                      : Icons.save_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  dp.status == 'POSTED' ? 'Down Payment Posted' : 'Draft Saved',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dp.status == 'POSTED'
                      ? '${dp.dpNumber} has been posted to GL'
                      : '${dp.dpNumber} saved as draft.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── DP Info Card ──
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Down Payment Information',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const Divider(),
                  _infoRow('Document No.', dp.dpNumber),
                  _infoRow('Status', dp.statusLabel, valueColor: Colors.green),
                  _infoRow('Created', Fmt.dateTimeStr(dp.createdAt)),
                  const SizedBox(height: 8),
                  _infoRow(
                    'Vendor',
                    dp.vendorName.isNotEmpty
                        ? '${dp.vendorCode} - ${dp.vendorName}'
                        : dp.vendorCode,
                  ),
                  _infoRow('PO Reference', dp.poNumber),
                  _infoRow(
                    'Amount',
                    '\$${ApService.fmtAmount(dp.totalAmount)}  ${dp.currency}',
                    valueColor: Colors.blue.shade700,
                  ),
                  _infoRow(
                    'Special GL',
                    'A (Down Payment)',
                    valueColor: Colors.blue.shade700,
                  ),
                  if (dp.description.isNotEmpty)
                    _infoRow('Description', dp.description),
                  if (dp.referenceNo.isNotEmpty)
                    _infoRow('Reference', dp.referenceNo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── GL Entry Card ──
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Journal Entry',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const Divider(),
                  if (dp.glJeId != null)
                    _infoRow('GL Document No.', dp.glJeId!.substring(0, 8)),
                  _infoRow(
                    'Posting Status',
                    dp.status == 'POSTED' ? 'Posted' : 'Draft',
                    valueColor: dp.status == 'POSTED'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  if (dp.postedAt != null)
                    _infoRow('Posting Date', Fmt.dateStr(dp.postedAt)),
                  const SizedBox(height: 12),

                  // JE lines
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Account',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Name',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Debit',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Credit',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 8),
                        _jeLine(
                          dp.apDpAccountCode.isNotEmpty
                              ? dp.apDpAccountCode
                              : 'AP_DP',
                          dp.apDpAccountName.isNotEmpty
                              ? dp.apDpAccountName
                              : 'AP Down Payment',
                          dp.totalAmount,
                          0,
                        ),
                        _jeLine(
                          dp.creditAccountCode,
                          dp.creditAccountName,
                          0,
                          dp.totalAmount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Action Buttons ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Another Down Payment'),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DPCreateScreen(
                    authService: authService,
                    apService: apService,
                  ),
                ),
              ),
            ),
          ),

          if (downPayment.status == 'DRAFT') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Draft'),
                          content: Text(
                            'Delete down payment ${downPayment.dpNumber}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await apService.deleteDownPayment(downPayment.id);
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.post_add),
                    label: const Text('Post Now'),
                    onPressed: () async {
                      try {
                        await apService.postDownPayment(downPayment.id);
                        if (context.mounted) {
                          final updated = await apService.getDownPayment(
                            downPayment.id,
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DPVoucherScreen(
                                authService: authService,
                                apService: apService,
                                downPayment: updated,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
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
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Back to List'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jeLine(String code, String name, double debit, double credit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              code,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              debit > 0 ? '\$${ApService.fmtAmount(debit)}' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              credit > 0 ? '\$${ApService.fmtAmount(credit)}' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
