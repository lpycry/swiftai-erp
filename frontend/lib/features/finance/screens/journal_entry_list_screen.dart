import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_screen.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class JournalEntryListScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService? orgService;

  const JournalEntryListScreen({
    super.key,
    required this.authService,
    required this.glService,
    this.orgService,
  });

  @override
  State<JournalEntryListScreen> createState() => _JournalEntryListScreenState();
}

class _JournalEntryListScreenState extends State<JournalEntryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;

  static const _tabs = ['search', 'draft', 'posted'];
  static const _tabLabels = <String, String>{
    'search': 'Accounting Document',
    'draft': 'Draft',
    'posted': 'Posted',
  };

  final Map<String, List<dynamic>> _data = {};
  final Map<String, bool> _loading = {};
  bool _reverseLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final key = _tabs[_tabController.index];
        // Only load if data not already loaded and not currently loading
        if (!_data.containsKey(key) && !(_loading[key] ?? false)) {
          _loadTab(key);
        }
      }
    });
    _loadTab('draft');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(String status) async {
    // Prevent duplicate loading
    if (_loading[status] == true) return;

    setState(() => _loading[status] = true);
    try {
      final list = await widget.glService.listJournalEntries(status: status);
      if (mounted) {
        setState(() {
          _data[status] = list;
          _loading[status] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading[status] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Smart search across document_no, description, reference, and amounts
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await widget.glService.listJournalEntries(
        page: 1,
        pageSize: 50,
        query: query.trim(),
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Reload both tabs
  Future<void> _reloadTabs(List<String> statuses) async {
    await Future.wait(statuses.map((s) => _loadTab(s)));
  }

  // ── Draft actions ──

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this draft entry? This cannot be undone.'),
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
    if (confirmed != true) return;

    try {
      await widget.glService.deleteJournalEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTab('draft');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _editEntry(dynamic entry) async {
    try {
      final detail = await widget.glService.getJournalEntry(
        entry['id']!.toString(),
      );
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JournalEntryScreen(
            authService: widget.authService,
            glService: widget.glService,
            orgService:
                widget.orgService ??
                OrgService(widget.authService.accessToken ?? ''),
            existingEntry: detail,
          ),
        ),
      );

      if (mounted) {
        // Reload both tabs as the entry status might have changed
        final originalStatus = entry['status']?.toString() ?? 'draft';
        final newStatus = detail['status']?.toString() ?? 'draft';

        if (originalStatus == newStatus) {
          await _loadTab(originalStatus);
        } else {
          await _reloadTabs([originalStatus, newStatus]);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load entry: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Posted actions ──

  /// Execute reversal with the chosen type.
  Future<void> _reverseEntry(String id, String reversalType) async {
    if (_reverseLoading) return;

    setState(() => _reverseLoading = true);
    try {
      await widget.glService.reverseJournalEntry(
        id,
        reversalType: reversalType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reversalType == 'negative'
                  ? 'Negative reversal (红字冲销) created and posted'
                  : 'Normal reversal created and posted',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _reloadTabs(['posted', 'draft']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reverse failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reverseLoading = false);
    }
  }

  /// Show reverse dialog with type selection.
  /// Default: Negative Posting (红字冲销).
  Future<void> _confirmReverse(String id, String docNo) async {
    String selectedType = 'negative';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.swap_horiz,
                size: 22,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 10),
              const Text('Reverse Entry', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document: $docNo',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select reversal type:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              // Negative posting (default)
              InkWell(
                onTap: () => setDialogState(() => selectedType = 'negative'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedType == 'negative'
                        ? AppTheme.errorColor.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedType == 'negative'
                          ? AppTheme.errorColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedType == 'negative'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: selectedType == 'negative'
                            ? AppTheme.errorColor
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Negative Posting (红字冲销)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Keep debit/credit position, use negative amounts.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Normal reversal
              InkWell(
                onTap: () => setDialogState(() => selectedType = 'normal'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selectedType == 'normal'
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedType == 'normal'
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedType == 'normal'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: selectedType == 'normal'
                            ? AppTheme.primaryColor
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Normal Reversal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Swap debit and credit amounts.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The reversal entry will be created and posted immediately.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              onPressed: () => Navigator.pop(ctx, selectedType),
              child: const Text('Reverse'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _reverseEntry(id, result);
    }
  }

  // ── View Detail ──

  void _viewDetail(dynamic entry) async {
    try {
      final detail = await widget.glService.getJournalEntry(
        entry['id']!.toString(),
      );
      if (mounted) await _showDetailDialog(detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showDetailDialog(Map<String, dynamic> entry) async {
    final lines = (entry['lines'] as List<dynamic>?) ?? [];
    final status = entry['status']?.toString() ?? 'draft';
    final docNo = entry['document_no']?.toString() ?? 'N/A';
    final entryId = entry['id']?.toString() ?? '';

    double totalDebit = 0, totalCredit = 0;

    // Check if totals are provided directly
    if (entry.containsKey('total_debit') && entry.containsKey('total_credit')) {
      totalDebit = (entry['total_debit'] as num?)?.toDouble() ?? 0;
      totalCredit = (entry['total_credit'] as num?)?.toDouble() ?? 0;
    } else {
      // Calculate from lines
      for (final l in lines) {
        totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
        totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
      }
    }

    // Fetch attachments count
    int attachmentCount = 0;
    try {
      final atts = await widget.glService.getAttachments(entryId);
      attachmentCount = atts.length;
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status == 'posted' ? Icons.check_circle : Icons.edit_note,
              color: status == 'posted'
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                docNo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    (status == 'posted'
                            ? AppTheme.successColor
                            : AppTheme.warningColor)
                        .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: status == 'posted'
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'Description',
                  entry['description']?.toString() ?? '',
                ),
                _detailRow('Posting Date', _fmtDate(entry['posting_date'])),
                _detailRow('Document Date', _fmtDate(entry['document_date'])),
                _detailRow('Reference', entry['reference']?.toString() ?? ''),
                _detailRow('Type', entry['entry_type']?.toString() ?? 'normal'),
                if (entry['organization_name'] != null &&
                    (entry['organization_name'] as String).isNotEmpty)
                  _detailRow('Company', entry['organization_name'] as String),
                const Divider(height: 16),

                // Lines table
                const Text(
                  'Line Items',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Debit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Credit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Description',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...lines.asMap().entries.map(
                        (e) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${e.value['account_code'] ?? ''} ${e.value['account_name'] ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  ((e.value['debit'] as num?)?.toDouble() ??
                                              0) >
                                          0
                                      ? '\$${GlService.fmtAmount(e.value['debit'] as num?)}'
                                      : '',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  ((e.value['credit'] as num?)?.toDouble() ??
                                              0) >
                                          0
                                      ? '\$${GlService.fmtAmount(e.value['credit'] as num?)}'
                                      : '',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  e.value['description']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '\$${GlService.fmtAmount(totalDebit)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '\$${GlService.fmtAmount(totalCredit)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Expanded(flex: 2, child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (attachmentCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$attachmentCount attachment(s)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (attachmentCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(
                'Attachments ($attachmentCount)',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx); // Close detail dialog first
                _showEntryAttachmentsDialog(entryId, docNo);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntryAttachmentsDialog(String entryId, String docNo) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 60,
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final atts = await widget.glService.getAttachments(entryId);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar with close button (matches journal_entry_screen)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Attachments (${atts.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (atts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No attachments found'),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: atts
                          .map(
                            (a) => _buildAttachmentItem(
                              a,
                              entryId,
                              onView: () {
                                // Close attachments dialog first to avoid nesting
                                Navigator.pop(ctx);
                                _previewAttachment(entryId, a);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attachments: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Preview attachment: download then show ──

  Future<void> _previewAttachment(
    String entryId,
    Map<String, dynamic> att,
  ) async {
    final fileType = att['file_type']?.toString() ?? '';
    final fileName = att['file_name']?.toString() ?? 'Unknown';
    final attId = att['id']?.toString() ?? '';
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    if (!mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 60,
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final rawBytes = await widget.glService.downloadAttachmentBytes(
        entryId,
        attId,
      );
      final bytes = Uint8List.fromList(rawBytes);

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      final isImage =
          fileType.startsWith('image/') ||
          ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
      final isPdf = fileType.contains('pdf') || ext == 'pdf';

      if (isImage) {
        _showImagePreview(bytes, fileName, ext);
      } else if (isPdf) {
        _showPdfPreview(bytes, fileName);
      } else {
        _showFilePreview(bytes, att);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to preview: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Image preview with InteractiveViewer (matches journal_entry_screen style)
  void _showImagePreview(Uint8List bytes, String fileName, String ext) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar with file icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _fileIconWidget(ext, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
            // Interactive viewer for image
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
            // Close button bar
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

  /// PDF preview with printing support (full-screen page)
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
                onPressed: () =>
                    Printing.layoutPdf(onLayout: (_) async => bytes),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () =>
                    Printing.sharePdf(bytes: bytes, filename: fileName),
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

  /// Non-image, non-PDF file preview (matches journal_entry_screen style)
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
            // Title bar with file icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _fileIconWidget(ext, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
            // File info display
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fileIconWidget(ext, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _typeLabel(ext),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (fileSize > 0)
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Preview not available for this file type.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Close button bar
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

  /// File type icon (colorful Material icon per type, matches journal_entry_screen)
  Widget _fileIconWidget(String ext, {double size = 40}) {
    final e = ext.toLowerCase();
    IconData icon;
    Color color;
    switch (e) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red.shade600;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green.shade600;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue.shade600;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        icon = Icons.image;
        color = Colors.purple.shade500;
      case 'csv':
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey.shade600;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.orange.shade600;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size * 0.6),
    );
  }

  /// Human-readable type label (matches journal_entry_screen)
  String _typeLabel(String ext) {
    switch (ext) {
      case 'pdf':
        return 'PDF Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      case 'gif':
        return 'GIF Image';
      case 'bmp':
        return 'Bitmap Image';
      case 'csv':
        return 'CSV File';
      case 'txt':
        return 'Text File';
      default:
        return 'Unknown File';
    }
  }

  /// Attachment item card (matches journal_entry_screen structure)
  Widget _buildAttachmentItem(
    Map<String, dynamic> att,
    String entryId, {
    VoidCallback? onView,
  }) {
    final fileName = att['file_name']?.toString() ?? 'Unknown';
    final fileSize = (att['file_size'] as num?)?.toInt() ?? 0;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final fileType = att['file_type']?.toString() ?? '';
    final isImage =
        fileType.startsWith('image/') ||
        ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _fileIconWidget(ext, size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (fileSize > 0)
                        Text(
                          _formatFileSize(fileSize),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Preview button
                IconButton(
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.accentBlue,
                  ),
                  onPressed: onView,
                  tooltip: 'Preview',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
              ],
            ),
          ),
          // Image preview strip at bottom (matches journal_entry_screen)
          if (isImage)
            GestureDetector(
              onTap: onView,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  color: Colors.grey.shade100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to preview image',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Helpers ──

  String _fmtDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Map<String, dynamic> _tabIconAndColor(String key) {
    switch (key) {
      case 'search':
        return {'icon': Icons.search, 'color': AppTheme.accentBlue};
      case 'draft':
        return {'icon': Icons.edit_note, 'color': AppTheme.warningColor};
      case 'posted':
        return {
          'icon': Icons.check_circle_outline,
          'color': AppTheme.successColor,
        };
      default:
        return {'icon': Icons.receipt_long, 'color': Colors.grey};
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: 'Journal Entries',
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.accentBlue,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: _tabs.map((key) {
                final count = _data[key]?.length;
                final meta = _tabIconAndColor(key);
                return Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(meta['icon'] as IconData, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _tabLabels[key]!,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: (meta['color'] as Color).withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                color: meta['color'] as Color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((key) => _buildTab(key)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Search tab with smart search input and results
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  'Search by document no, description, reference, or amount...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) {
              setState(() {}); // refresh suffix icon
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                _performSearch(v);
              });
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _performSearch(v),
          ),
        ),
        const Divider(height: 1),
        // Results
        Expanded(
          child: _searchLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Type something to search'
                            : 'No matching entries found',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, i) =>
                      _buildCard(_searchResults[i], 'search'),
                ),
        ),
      ],
    );
  }

  Widget _buildTab(String key) {
    if (key == 'search') return _buildSearchTab();

    final loading = _loading[key] ?? false;
    final data = _data[key];

    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data == null || data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'No ${_tabLabels[key]!.toLowerCase()} entries',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTab(key),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: data.length,
        itemBuilder: (context, i) => _buildCard(data[i], key),
      ),
    );
  }

  Widget _buildCard(dynamic entry, String key) {
    final meta = _tabIconAndColor(key);
    final statusColor = meta['color'] as Color;
    final dateStr = _fmtDate(entry['posting_date'] ?? entry['date']);
    final docNo = entry['document_no']?.toString() ?? 'N/A';
    final total =
        entry['total_debit'] as num? ?? entry['debit_sum'] as num? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: InkWell(
        onTap: () => _viewDetail(entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  meta['icon'] as IconData,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry['description']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              // Amount + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${GlService.fmtAmount(total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              // Action
              _buildActionButton(entry, key),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(dynamic entry, String key) {
    final id = entry['id']?.toString() ?? '';
    final docNo = entry['document_no']?.toString() ?? '';

    switch (key) {
      case 'draft':
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
          onSelected: (v) {
            if (v == 'view') _viewDetail(entry);
            if (v == 'edit') _editEntry(entry);
            if (v == 'delete') _deleteEntry(id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.visibility_outlined, size: 18),
                title: Text('View', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.edit_outlined, size: 18),
                title: Text('Edit', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppTheme.errorColor,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(fontSize: 13, color: AppTheme.errorColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );

      case 'posted':
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
          onSelected: (v) {
            if (v == 'view') _viewDetail(entry);
            if (v == 'reverse') _confirmReverse(id, docNo);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.visibility_outlined, size: 18),
                title: Text('View', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'reverse',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.undo, size: 18, color: AppTheme.errorColor),
                title: Text(
                  'Reverse',
                  style: TextStyle(fontSize: 13, color: AppTheme.errorColor),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
