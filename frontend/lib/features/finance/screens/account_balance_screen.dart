import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class AccountBalanceScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;

  const AccountBalanceScreen({
    super.key,
    required this.authService,
    required this.glService,
  });

  @override
  State<AccountBalanceScreen> createState() => _AccountBalanceScreenState();
}

class _AccountBalanceScreenState extends State<AccountBalanceScreen> {
  List<dynamic> _balances = [];
  bool _loading = false;
  int _year = DateTime.now().year;
  int? _month;
  final List<int> _years = List.generate(10, (i) => DateTime.now().year - 5 + i);

  static const _months = [
    'All', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() => _loading = true);
    try {
      final data = await widget.glService.getAccountBalances(year: _year, month: _month);
      setState(() => _balances = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load balances: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Show ledger detail dialog for debit/credit side
  Future<void> _showLedgerDetail(dynamic entry, {required bool showDebit}) async {
    final accountId = entry['account_id']?.toString() ?? '';
    final code = entry['account_code'] ?? entry['code'] ?? '';
    final name = entry['account_name'] ?? entry['name'] ?? '';
    final side = showDebit ? 'Debit' : 'Credit';

    if (accountId.isEmpty) return;

    final from = _month != null
        ? '$_year-${_month!.toString().padLeft(2, '0')}-01'
        : '$_year-01-01';
    final to = _month != null
        ? '$_year-${_month!.toString().padLeft(2, '0')}-${DateTime(_year, _month! + 1, 0).day}'
        : '$_year-12-31';

    try {
      final lines = await widget.glService.getAccountLedger(accountId, from: from, to: to);
      if (!mounted) return;
      _showLedgerDetailDialog(code, name, side, lines, showDebit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load detail: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showLedgerDetailDialog(
    String code, String name, String side,
    List<dynamic> lines, bool showDebit,
  ) {
    final filtered = lines.where((l) {
      final amt = (showDebit ? l['debit'] : l['credit']) as num? ?? 0;
      return amt > 0;
    }).toList();

    final total = filtered.fold<double>(
      0.0, (sum, l) => sum + ((showDebit ? l['debit'] : l['credit']) as num? ?? 0).toDouble(),
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    showDebit ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
                    color: showDebit ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$code - $name - $side Details',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Expanded(flex: 2, child: Text('Doc No',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                  const Expanded(flex: 2, child: Text('Date',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                  const Expanded(flex: 4, child: Text('Description',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                  Expanded(
                    flex: 2,
                    child: Text(side, textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final l = filtered[i];
                        final docNo = l['document_no']?.toString() ?? '';
                        final date = l['posting_date']?.toString() ?? '';
                        final desc = l['description']?.toString() ?? '';
                        final amt = (showDebit ? l['debit'] : l['credit']) as num? ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: GestureDetector(
                                onTap: () {
                                  final entryId = l['entry_id']?.toString() ?? '';
                                  if (entryId.isNotEmpty) {
                                    Navigator.pop(ctx);
                                    _showFullEntry(entryId);
                                  }
                                },
                                child: Text(docNo,
                                    style: TextStyle(
                                      fontSize: 11, fontFamily: 'monospace',
                                      color: AppTheme.accentBlue,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppTheme.accentBlue.withValues(alpha: 0.4),
                                    ),
                                    overflow: TextOverflow.ellipsis),
                              )),
                              Expanded(flex: 2, child: Text(_fmtShortDate(date),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                              Expanded(flex: 4, child: Text(desc,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2, child: Text(
                                '\$${GlService.fmtAmount(amt.toDouble())}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: showDebit ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 8, child: Text('Total $side',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text(
                    '\$${GlService.fmtAmount(total)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12,
                      color: showDebit ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fetch and show the full journal entry dialog
  Future<void> _showFullEntry(String entryId) async {
    try {
      final entry = await widget.glService.getJournalEntry(entryId);
      if (!mounted || entry.isEmpty) return;

      final docNo = entry['document_no']?.toString() ?? '';
      final description = entry['description']?.toString() ?? '';
      final postingDate = entry['posting_date']?.toString() ?? '';
      final documentDate = entry['document_date']?.toString() ?? '';
      final reference = entry['reference']?.toString() ?? '';
      final entryType = entry['entry_type']?.toString() ?? 'normal';
      final status = entry['status']?.toString() ?? 'draft';
      final source = entry['source']?.toString() ?? '';
      final lines = (entry['lines'] as List<dynamic>?) ?? [];

      double totalDebit = 0, totalCredit = 0;
      for (final l in lines) {
        totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
        totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
      }

      // Fetch attachments
      List<Map<String, dynamic>> attachments = [];
      final entryIdStr = entry['id']?.toString() ?? '';
      if (entryIdStr.isNotEmpty) {
        try {
          attachments = await widget.glService.getAttachments(entryIdStr);
        } catch (_) {}
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      status == 'posted' ? Icons.check_circle : Icons.edit_note,
                      size: 20,
                      color: status == 'posted' ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(docNo,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (status == 'posted' ? AppTheme.successColor : AppTheme.warningColor)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: status == 'posted' ? AppTheme.successColor : AppTheme.warningColor,
                          )),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _entryRow('Description', description),
                      _entryRow('Posting Date', _fmtShortDate(postingDate)),
                      if (documentDate.isNotEmpty)
                        _entryRow('Document Date', _fmtShortDate(documentDate)),
                      if (reference.isNotEmpty)
                        _entryRow('Reference', reference),
                      _entryRow('Type', entryType),
                      _entryRow('Source', source),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      const Text('Line Items',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      // Lines list
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              color: Colors.grey.shade100,
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Account',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                  Expanded(flex: 1, child: Text('Debit',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                  Expanded(flex: 1, child: Text('Credit',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                  Expanded(flex: 3, child: Text('Description',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                ],
                              ),
                            ),
                            // Lines
                            ...lines.asMap().entries.map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                border: e.key < lines.length - 1
                                    ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(
                                    '${e.value['account_code'] ?? ''} - ${e.value['account_name'] ?? ''}',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis, maxLines: 1,
                                  )),
                                  Expanded(flex: 1, child: Text(
                                    (e.value['debit'] as num? ?? 0) > 0
                                        ? '\$${GlService.fmtAmount((e.value['debit'] as num?)?.toDouble() ?? 0)}'
                                        : '',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                                  )),
                                  Expanded(flex: 1, child: Text(
                                    (e.value['credit'] as num? ?? 0) > 0
                                        ? '\$${GlService.fmtAmount((e.value['credit'] as num?)?.toDouble() ?? 0)}'
                                        : '',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                                  )),
                                  Expanded(flex: 3, child: Text(
                                    e.value['description']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis, maxLines: 1,
                                  )),
                                ],
                              ),
                            )),
                            // Total row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              color: Colors.grey.shade50,
                              child: Row(
                                children: [
                                  const Expanded(flex: 3, child: Text('TOTAL',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Expanded(flex: 1, child: Text(
                                    '\$${GlService.fmtAmount(totalDebit)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  )),
                                  Expanded(flex: 1, child: Text(
                                    '\$${GlService.fmtAmount(totalCredit)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  )),
                                  const Expanded(flex: 3, child: SizedBox()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Attachments section
                      if (attachments.isNotEmpty) ...[                        
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.attach_file, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Attachments (${attachments.length})',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...attachments.map((a) {
                          final name = a['file_name']?.toString() ?? 'Unknown';
                          final size = (a['file_size'] as num?)?.toInt() ?? 0;
                          final ext = name.contains('.')
                              ? name.split('.').last.toLowerCase()
                              : '';
                          return GestureDetector(
                            onTap: () {
                              final attId = a['id']?.toString() ?? '';
                              if (attId.isNotEmpty && entryIdStr.isNotEmpty) {
                                _previewAttachment(entryIdStr, a);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                              children: [
                                Icon(
                                  ext == 'pdf' ? Icons.picture_as_pdf :
                                  ['xls','xlsx'].contains(ext) ? Icons.table_chart :
                                  ['doc','docx'].contains(ext) ? Icons.description :
                                  ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Icons.image :
                                  Icons.insert_drive_file,
                                  size: 18,
                                  color: ext == 'pdf' ? Colors.red.shade600 :
                                         ['xls','xlsx'].contains(ext) ? Colors.green.shade600 :
                                         ['doc','docx'].contains(ext) ? Colors.blue.shade600 :
                                         ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Colors.purple.shade500 :
                                         Colors.orange.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis, maxLines: 1),
                                      if (size > 0)
                                        Text(
                                          size < 1024 ? '$size B' :
                                          size < 1048576 ? '${(size/1024).toStringAsFixed(1)} KB' :
                                          '${(size/1048576).toStringAsFixed(1)} MB',
                                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entry: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  /// Helper row for entry detail dialog
  Widget _entryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Download and preview an attachment
  Future<void> _previewAttachment(String entryId, Map<String, dynamic> att) async {
    final fileType = att['file_type']?.toString() ?? '';
    final fileName = att['file_name']?.toString() ?? 'Unknown';
    final attId = att['id']?.toString() ?? '';
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    if (!mounted || attId.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 60, height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final rawBytes = await widget.glService.downloadAttachmentBytes(entryId, attId);
      final bytes = Uint8List.fromList(rawBytes);
      if (!mounted) return;
      Navigator.pop(context);

      final isImage = fileType.startsWith('image/')
          || ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
      final isPdf = fileType.contains('pdf') || ext == 'pdf';

      if (isImage) {
        _showImagePreview(bytes, fileName);
      } else if (isPdf) {
        _showPdfPreview(bytes, fileName);
      } else {
        _showFilePreview(bytes, att);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showImagePreview(Uint8List bytes, String fileName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.image, size: 28, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('Unable to load image')),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfPreview(Uint8List bytes, String fileName) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(fileName, style: const TextStyle(fontSize: 15)),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Print',
                onPressed: () => Printing.layoutPdf(onLayout: (_) async => bytes),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () => Printing.sharePdf(bytes: bytes, filename: fileName),
              ),
            ],
          ),
          body: PdfPreview(
            pdfPreviewPageDecoration: const BoxDecoration(),
            allowPrinting: true,
            allowSharing: true,
            build: (format) async => bytes,
          ),
        ),
      ),
    );
  }

  void _showFilePreview(Uint8List bytes, Map<String, dynamic> att) {
    final fileName = att['file_name']?.toString() ?? 'Unknown';
    final fileSize = (att['file_size'] as num?)?.toInt() ?? 0;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    ext == 'pdf' ? Icons.picture_as_pdf :
                    ['xls','xlsx'].contains(ext) ? Icons.table_chart :
                    ['doc','docx'].contains(ext) ? Icons.description :
                    ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Icons.image :
                    Icons.insert_drive_file,
                    size: 28,
                    color: ext == 'pdf' ? Colors.red.shade600 :
                           ['xls','xlsx'].contains(ext) ? Colors.green.shade600 :
                           ['doc','docx'].contains(ext) ? Colors.blue.shade600 :
                           ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Colors.purple.shade500 :
                           Colors.orange.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ext == 'pdf' ? Icons.picture_as_pdf :
                    ['xls','xlsx'].contains(ext) ? Icons.table_chart :
                    ['doc','docx'].contains(ext) ? Icons.description :
                    ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Icons.image :
                    Icons.insert_drive_file,
                    size: 72,
                    color: ext == 'pdf' ? Colors.red.shade600 :
                           ['xls','xlsx'].contains(ext) ? Colors.green.shade600 :
                           ['doc','docx'].contains(ext) ? Colors.blue.shade600 :
                           ['jpg','jpeg','png','gif','bmp'].contains(ext) ? Colors.purple.shade500 :
                           Colors.orange.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(fileName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    ext == 'pdf' ? 'PDF Document' :
                    ['xls','xlsx'].contains(ext) ? 'Excel Spreadsheet' :
                    ['doc','docx'].contains(ext) ? 'Word Document' :
                    ['jpg','jpeg'].contains(ext) ? 'JPEG Image' :
                    ext == 'png' ? 'PNG Image' :
                    ext == 'gif' ? 'GIF Image' :
                    ext == 'bmp' ? 'Bitmap Image' :
                    ext == 'csv' ? 'CSV File' :
                    ext == 'txt' ? 'Text File' : 'Unknown File',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (fileSize > 0)
                    Text(
                      fileSize < 1024 ? '$fileSize B' :
                      fileSize < 1048576 ? '${(fileSize/1024).toStringAsFixed(1)} KB' :
                      '${(fileSize/1048576).toStringAsFixed(1)} MB',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Preview not available for this file type.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtShortDate(String dateStr) {
    if (dateStr.length >= 10) return dateStr.substring(0, 10);
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Account Balances',
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Year selector
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) {
                      setState(() => _year = v!);
                      _loadBalances();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Month selector
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('All', style: TextStyle(fontSize: 13)),
                    items: List.generate(_months.length, (i) => DropdownMenuItem(
                      value: i == 0 ? null : i,
                      child: Text(i == 0 ? 'All' : _months[i]),
                    )),
                    onChanged: (v) {
                      setState(() => _month = v);
                      _loadBalances();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadBalances,
                  tooltip: 'Refresh',
                ),
                const Spacer(),
                Text(
                  '$_year${_month != null ? ' ${_months[_month!]}' : ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Column headers
          if (_balances.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _headerText('Code')),
                  Expanded(flex: 3, child: _headerText('Account Name')),
                  Expanded(flex: 2, child: _headerText('Type')),
                  Expanded(flex: 2, child: _headerText('Total Debit', align: TextAlign.right)),
                  Expanded(flex: 2, child: _headerText('Total Credit', align: TextAlign.right)),
                  Expanded(flex: 2, child: _headerText('Balance', align: TextAlign.right)),
                ],
              ),
            ),

          // Balance data
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _balances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.balance_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No balance data found', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _balances.length,
                        itemBuilder: (context, i) => _BalanceRow(
                          entry: _balances[i],
                          onDebitTap: () => _showLedgerDetail(_balances[i], showDebit: true),
                          onCreditTap: () => _showLedgerDetail(_balances[i], showDebit: false),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(text,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey.shade700),
      textAlign: align,
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final dynamic entry;
  final VoidCallback? onDebitTap;
  final VoidCallback? onCreditTap;

  const _BalanceRow({
    required this.entry,
    this.onDebitTap,
    this.onCreditTap,
  });

  @override
  Widget build(BuildContext context) {
    final code = entry['account_code'] ?? entry['code'] ?? '';
    final name = entry['account_name'] ?? entry['name'] ?? '';
    final type = entry['account_type'] ?? entry['type'] ?? '';
    final debit = (entry['total_debit'] as num?)?.toDouble() ?? 0;
    final credit = (entry['total_credit'] as num?)?.toDouble() ?? 0;
    final balance = (entry['balance'] as num?)?.toDouble() ?? (debit - credit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(
            code,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500),
          )),
          Expanded(flex: 3, child: Text(
            name,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          Expanded(flex: 2, child: Text(
            type,
            style: TextStyle(fontSize: 11, color: AccountModel.typeColor(type)),
          )),
          // Debit amount — tappable
          Expanded(flex: 2, child: GestureDetector(
            onTap: debit > 0 ? onDebitTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: debit > 0
                  ? BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                debit > 0 ? '\$${GlService.fmtAmount(debit)}' : '-',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  decoration: debit > 0 ? TextDecoration.underline : null,
                  decorationColor: Colors.green.shade300,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          )),
          // Credit amount — tappable
          Expanded(flex: 2, child: GestureDetector(
            onTap: credit > 0 ? onCreditTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: credit > 0
                  ? BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                credit > 0 ? '\$${GlService.fmtAmount(credit)}' : '-',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  decoration: credit > 0 ? TextDecoration.underline : null,
                  decorationColor: Colors.orange.shade300,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          )),
          Expanded(flex: 2, child: Text(
            '\$${GlService.fmtAmount(balance.abs())}${balance < 0 ? ' CR' : ' DR'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: balance >= 0 ? Colors.green.shade800 : AppTheme.errorColor,
            ),
            textAlign: TextAlign.right,
          )),
        ],
      ),
    );
  }
}
