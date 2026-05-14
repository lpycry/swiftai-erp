import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';
import 'package:swiftai_erp/features/finance/screens/journal_entry_list_screen.dart';
import 'package:swiftai_erp/features/settings/services/org_service.dart';

class JournalEntryScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  final OrgService orgService;
  final Map<String, dynamic>? existingEntry;

  const JournalEntryScreen({
    super.key,
    required this.authService,
    required this.glService,
    required this.orgService,
    this.existingEntry,
  });

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  // â”€â”€ Mode â”€â”€
  bool _professionalMode = true;
  bool _loading = false;
  bool _aiLoading = false;

  // â”€â”€ Header fields â”€â”€
  List<dynamic> _organizations = [];
  String? _selectedOrgId;
  String _documentType = 'normal';
  DateTime _postingDate = DateTime.now();
  DateTime _documentDate = DateTime.now();
  final TextEditingController _referenceCtrl = TextEditingController();
  final TextEditingController _headerDescCtrl = TextEditingController();

  // â”€â”€ Professional Mode â€” start with 2 default line items â”€â”€
  final List<_JournalLine> _lines = [_JournalLine(), _JournalLine()];

  // â”€â”€ AI Mode â”€â”€
  final TextEditingController _aiDescriptionCtrl = TextEditingController();
  final TextEditingController _aiAmountCtrl = TextEditingController();
  Map<String, dynamic>? _aiSuggestion;

  // â”€â”€ Accounts cache â”€â”€
  List<AccountModel> _accounts = [];
  bool _accountsLoading = true;

  // â”€â”€ Attachments â”€â”€
  final List<PlatformFile> _attachedFiles = [];

  // ── Editing mode ──
  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _headerDescCtrl.dispose();
    _aiDescriptionCtrl.dispose();
    _aiAmountCtrl.dispose();
    for (final l in _lines) {
      l.debitCtrl.dispose();
      l.creditCtrl.dispose();
      l.lineDescCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitData() async {
    await Future.wait([_loadOrganizations(), _loadAccounts()]);
    if (_isEditing) _populateFromExisting();
  }

  Future<void> _loadOrganizations() async {
    try {
      final orgs = await widget.orgService.getOrganizations();
      setState(() {
        _organizations = orgs;
        // Auto-select if only one company code
        if (orgs.length == 1) {
          _selectedOrgId = orgs[0]['id'] as String?;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.glService.getAccounts();
      setState(() {
        _accounts = accounts;
        _accountsLoading = false;
      });
    } catch (e) {
      setState(() => _accountsLoading = false);
      if (mounted) {
        _showError('Failed to load accounts: $e');
      }
    }
  }

  // â”€â”€ Balance calculation â”€â”€
  double get _totalDebit => _lines.fold(
    0.0,
    (sum, l) => sum + (double.tryParse(l.debitCtrl.text) ?? 0),
  );

  double get _totalCredit => _lines.fold(
    0.0,
    (sum, l) => sum + (double.tryParse(l.creditCtrl.text) ?? 0),
  );

  double get _balanceDiff => (_totalDebit - _totalCredit).abs();
  bool get _isBalanced => _balanceDiff < 0.01 && _totalDebit > 0;

  // â”€â”€ File Picker â”€â”€
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'pdf',
        'xls',
        'xlsx',
        'doc',
        'docx',
        'csv',
        'txt',
      ],
    );
    if (result != null) {
      setState(() => _attachedFiles.addAll(result.files));
    }
  }

  /// Build the JSON body for creating a journal entry.
  Map<String, dynamic> _buildRequestBody(
    String source,
    String description,
    List<Map<String, dynamic>> lines,
  ) {
    final body = <String, dynamic>{
      'posting_date': _postingDate.toUtc().toIso8601String(),
      'document_date': _documentDate.toUtc().toIso8601String(),
      'description': description,
      'reference': _referenceCtrl.text.trim(),
      'entry_type': _documentType,
      'source': source,
      'lines': lines.map((l) => Map<String, dynamic>.from(l)).toList(),
    };
    if (_selectedOrgId != null && _selectedOrgId!.isNotEmpty) {
      body['organization_id'] = _selectedOrgId;
    }
    return body;
  }

  bool _validateBeforeSubmit() {
    if (_headerDescCtrl.text.trim().isEmpty) {
      _showError('Please enter a description');
      return false;
    }
    if (!_isBalanced) {
      _showError('Debit and credit are not balanced');
      return false;
    }
    // Check each line has an account selected
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].selectedAccount == null) {
        _showError('Line ${i + 1}: please select an account');
        return false;
      }
      final d = double.tryParse(_lines[i].debitCtrl.text) ?? 0;
      final c = double.tryParse(_lines[i].creditCtrl.text) ?? 0;
      if (d <= 0 && c <= 0) {
        _showError('Line ${i + 1}: amount must be greater than zero');
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _collectLineData() {
    return _lines
        .where((l) => l.selectedAccount != null)
        .map(
          (l) => <String, dynamic>{
            'account_id': l.selectedAccount,
            'debit': double.tryParse(l.debitCtrl.text) ?? 0,
            'credit': double.tryParse(l.creditCtrl.text) ?? 0,
            'description': l.lineDescCtrl.text.trim(),
          },
        )
        .toList();
  }

  // â”€â”€ Save as Draft (no balance updates) â”€â”€
  Future<void> _saveDraft() async {
    if (!_validateBeforeSubmit()) return;

    setState(() => _loading = true);
    try {
      final lines = _collectLineData();
      final body = _buildRequestBody(
        'manual',
        _headerDescCtrl.text.trim(),
        lines,
      );
      final entry = _isEditing
          ? await widget.glService.updateJournalEntry(
              widget.existingEntry!['id']!.toString(),
              body,
            )
          : await widget.glService.createJournalEntry(body);

      if (_attachedFiles.isNotEmpty) {
        await widget.glService.uploadAttachments(
          entry['id']!.toString(),
          _attachedFiles,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry saved as draft'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        _showSavedInfo(entry, isDraft: true);
      }
    } catch (e) {
      if (mounted) _showError('Failed to save draft: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Save & Post (status='posted', updates gl_account_balances) ──
  Future<void> _saveAndPost() async {
    if (!_validateBeforeSubmit()) return;

    // Check if period is open before proceeding
    final periodOpen = await widget.glService.isPeriodOpenForDate(_postingDate);
    if (!periodOpen) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.red, size: 22),
                SizedBox(width: 10),
                Text('Period Closed', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: const Text(
              'Account Period is closed!\n\nPlease select a posting date that falls within an open accounting period.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      // Step 1: Create entry as draft
      final lines = _collectLineData();
      final body = _buildRequestBody(
        'manual',
        _headerDescCtrl.text.trim(),
        lines,
      );
      final entry = _isEditing
          ? await widget.glService.updateJournalEntry(
              widget.existingEntry!['id']!.toString(),
              body,
            )
          : await widget.glService.createJournalEntry(body);

      // Step 2: Post it (status → 'posted', balance update)
      final entryId = entry['id']!.toString();
      final postedEntry = await widget.glService.postJournalEntry(entryId);

      // Step 3: Upload attachments if any
      if (_attachedFiles.isNotEmpty) {
        await widget.glService.uploadAttachments(entryId, _attachedFiles);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry posted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _showSavedInfo(postedEntry, isDraft: false);
      }
    } catch (e) {
      if (mounted) _showError('Failed to post entry: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  //   // ── Saved Entry Info Dialog + Print + Attachments ──
  void _showSavedInfo(Map<String, dynamic> entry, {bool isDraft = false}) {
    final lines = (entry['lines'] as List<dynamic>?) ?? [];
    final status =
        entry['status']?.toString() ?? (isDraft ? 'draft' : 'posted');
    final docNo = entry['document_no']?.toString() ?? 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDraft ? Icons.edit_note : Icons.check_circle,
              color: isDraft ? AppTheme.warningColor : AppTheme.successColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isDraft ? 'Draft Saved' : 'Entry Posted',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPrintContent(entry, lines, docNo, status),
                // Attachments inline summary
                if (_attachedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _buildDialogAttachmentList(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAll();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Entry'),
          ),
          if (_attachedFiles.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(
                'Attachments (${_attachedFiles.length})',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _showAttachmentsDialog(),
            ),
          if (!isDraft)
            TextButton.icon(
              onPressed: () => _printEntry(entry, lines, docNo, status),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAll();
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Attachment list widget shown inside the saved-info dialog
  Widget _buildDialogAttachmentList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Attached Files',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._attachedFiles.map(
          (f) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _fileIconWidget(f.extension, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (f.size > 0)
                        Text(
                          _formatSize(f.size),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Full attachment preview dialog (accessible from saved-info dialog)
  void _showAttachmentsDialog() {
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
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Attachments (${_attachedFiles.length})',
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _attachedFiles
                      .map((f) => _buildAttachmentItem(f))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(ext);

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
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: file.bytes != null
                          ? Image.memory(
                              file.bytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fileIconWidget(file.extension),
                            )
                          : (file.path != null
                                ? Image.file(
                                    File(file.path!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _fileIconWidget(file.extension),
                                  )
                                : _fileIconWidget(file.extension)),
                    ),
                  )
                else
                  _fileIconWidget(file.extension, size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (file.size > 0)
                        Text(
                          _formatSize(file.size),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.accentBlue,
                  ),
                  onPressed: () => _showFilePreview(file, isImage),
                  tooltip: 'Preview',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
              ],
            ),
          ),
          if (isImage)
            GestureDetector(
              onTap: () => _showFilePreview(file, isImage),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: file.bytes != null
                      ? Image.memory(
                          file.bytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        )
                      : (file.path != null
                            ? Image.file(
                                File(file.path!),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              )
                            : const SizedBox()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  _buildPrintContent(
    Map<String, dynamic> entry,
    List<dynamic> lines,
    String docNo,
    String status,
  ) {
    double totalDebit = 0, totalCredit = 0;
    for (final l in lines) {
      totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
      totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long,
                size: 32,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                'Journal Entry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 2),
              _statusBadge(status),
            ],
          ),
        ),
        const Divider(height: 20),
        // Header info
        _printRow('Document No.', docNo),
        _printRow('Description', entry['description']?.toString() ?? ''),
        _printRow('Posting Date', _fmtDate(entry['posting_date'])),
        _printRow('Document Date', _fmtDate(entry['document_date'])),
        _printRow('Reference', entry['reference']?.toString() ?? ''),
        _printRow('Type', entry['entry_type']?.toString() ?? 'normal'),
        if (entry['organization_id'] != null) _printRow('Company', _orgName),
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        textAlign: TextAlign.right,
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
                        textAlign: TextAlign.right,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Rows
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
                          ((e.value['debit'] as num?)?.toDouble() ?? 0) > 0
                              ? '\$${GlService.fmtAmount(e.value['debit'] as num?)}'
                              : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          ((e.value['credit'] as num?)?.toDouble() ?? 0) > 0
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Totals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
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
        if (status == 'posted') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'Posted balances updated',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (totalDebit == totalCredit) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.balance, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Balanced: \$${GlService.fmtAmount(totalDebit)} DR = \$${GlService.fmtAmount(totalCredit)} CR',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _printRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'posted' => AppTheme.successColor,
      'draft' => AppTheme.warningColor,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  String _fmtDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> _printEntry(
    Map<String, dynamic> entry,
    List<dynamic> lines,
    String docNo,
    String status,
  ) async {
    double totalDebit = 0, totalCredit = 0;
    for (final l in lines) {
      totalDebit += (l['debit'] as num?)?.toDouble() ?? 0;
      totalCredit += (l['credit'] as num?)?.toDouble() ?? 0;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Center(
          child: pw.Column(
            children: [
              pw.SizedBox(height: 4),
              pw.Text(
                'Journal Entry',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.green800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
        ),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfRow('Document No.', docNo),
              _pdfRow('Description', entry['description']?.toString() ?? ''),
              _pdfRow('Posting Date', _fmtDate(entry['posting_date'])),
              _pdfRow('Document Date', _fmtDate(entry['document_date'])),
              _pdfRow('Reference', entry['reference']?.toString() ?? ''),
              _pdfRow('Type', entry['entry_type']?.toString() ?? 'normal'),
              if (entry['organization_id'] != null)
                _pdfRow('Company', _orgName),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Account',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Debit',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Credit',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Description',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...lines.map(
            (l) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      '${l['account_code'] ?? ''} ${l['account_name'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      ((l['debit'] as num?)?.toDouble() ?? 0) > 0
                          ? '\$${GlService.fmtAmount(l['debit'] as num?)}'
                          : '',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      ((l['credit'] as num?)?.toDouble() ?? 0) > 0
                          ? '\$${GlService.fmtAmount(l['credit'] as num?)}'
                          : '',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      l['description']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(
            color: PdfColors.grey50,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    '\$${GlService.fmtAmount(totalDebit)}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    '\$${GlService.fmtAmount(totalCredit)}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Expanded(flex: 3, child: pw.Container()),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated by SwiftAI ERP at ${DateTime.now().toString().substring(0, 19)}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  // â”€â”€ AI Mode (Professional) â”€â”€
  Future<void> _getAiSuggestion() async {
    final desc = _aiDescriptionCtrl.text.trim();
    final amount = double.tryParse(_aiAmountCtrl.text.trim());

    if (desc.isEmpty) {
      _showError('Please enter a business description');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    setState(() => _aiLoading = true);
    try {
      final suggestion = await widget.glService.aiSuggest(desc, amount);
      setState(() => _aiSuggestion = suggestion);
    } catch (e) {
      if (mounted) _showError('AI suggestion failed: $e');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _submitFromAi() async {
    final desc = _aiDescriptionCtrl.text.trim();
    if (desc.isEmpty) {
      _showError('Please enter a business description');
      return;
    }
    if (_aiSuggestion == null) {
      _showError('Please get an AI suggestion first');
      return;
    }

    setState(() => _loading = true);
    try {
      final suggested =
          _aiSuggestion!['suggested_lines'] as List<dynamic>? ?? [];
      double aiDebit = 0, aiCredit = 0;
      final lines = suggested.map((l) {
        final d = (l['debit'] as num?)?.toDouble() ?? 0;
        final c = (l['credit'] as num?)?.toDouble() ?? 0;
        aiDebit += d;
        aiCredit += c;
        return <String, dynamic>{
          'account_id': l['account_id'],
          'debit': d,
          'credit': c,
          'description': l['description'] ?? desc,
        };
      }).toList();

      final diff = (aiDebit - aiCredit).abs();
      if (diff > 0.01 && lines.length >= 2) {
        if (aiDebit > aiCredit) {
          lines.last['credit'] = (lines.last['credit'] as double) + diff;
        } else {
          lines.last['debit'] = (lines.last['debit'] as double) + diff;
        }
      }

      // Create entry
      final body = _buildRequestBody('ai', desc, lines);
      final entry = _isEditing
          ? await widget.glService.updateJournalEntry(
              widget.existingEntry!['id']!.toString(),
              body,
            )
          : await widget.glService.createJournalEntry(body);

      // Post it
      final entryId = entry['id']!.toString();
      final postedEntry = await widget.glService.postJournalEntry(entryId);

      if (_attachedFiles.isNotEmpty) {
        await widget.glService.uploadAttachments(entryId, _attachedFiles);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI journal entry posted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _showSavedInfo(postedEntry, isDraft: false);
      }
    } catch (e) {
      if (mounted) _showError('Failed to create entry: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetAll() {
    setState(() {
      _headerDescCtrl.clear();
      _referenceCtrl.clear();
      _aiDescriptionCtrl.clear();
      _aiAmountCtrl.clear();
      _aiSuggestion = null;
      _lines.clear();
      _lines.add(_JournalLine());
      _lines.add(_JournalLine());
      _attachedFiles.clear();
      _postingDate = DateTime.now();
      _documentDate = DateTime.now();
    });
  }

  /// Get the organization name by ID, falling back to the ID itself
  String get _orgName {
    if (_selectedOrgId == null) return '';
    final org = _organizations
        .cast<Map<String, dynamic>>()
        .where((o) => o['id']?.toString() == _selectedOrgId)
        .firstOrNull;
    if (org != null) {
      final code = org['org_code']?.toString() ?? '';
      final name = org['org_name']?.toString() ?? '';
      if (code.isNotEmpty && name.isNotEmpty) return '$code - $name';
      return name.isNotEmpty ? name : code;
    }
    return '';
  }

  /// Populate form fields from an existing draft entry
  void _populateFromExisting() {
    final e = widget.existingEntry!;
    _headerDescCtrl.text = e['description']?.toString() ?? '';
    _referenceCtrl.text = e['reference']?.toString() ?? '';
    _selectedOrgId = e['organization_id']?.toString();
    _documentType = e['entry_type']?.toString() ?? 'normal';

    if (e['posting_date'] != null) {
      final dt = DateTime.tryParse(e['posting_date'].toString());
      if (dt != null) _postingDate = dt;
    }
    if (e['document_date'] != null) {
      final dt = DateTime.tryParse(e['document_date'].toString());
      if (dt != null) _documentDate = dt;
    }

    // Load lines
    final existingLines = (e['lines'] as List<dynamic>?) ?? [];
    _lines.clear();
    for (final l in existingLines) {
      final line = _JournalLine();
      line.selectedAccount = l['account_id']?.toString();
      line.debitCtrl.text = ((l['debit'] as num?)?.toDouble() ?? 0) > 0
          ? GlService.fmtAmount(l['debit'] as num?)
          : '';
      line.creditCtrl.text = ((l['credit'] as num?)?.toDouble() ?? 0) > 0
          ? GlService.fmtAmount(l['credit'] as num?)
          : '';
      line.lineDescCtrl.text = l['description']?.toString() ?? '';
      _lines.add(line);
    }
    // Ensure at least 2 lines
    if (_lines.isEmpty) {
      _lines.add(_JournalLine());
      _lines.add(_JournalLine());
    }
  }

  /// Auto-balance: add the difference to the last line's opposite side
  void _autoBalance() {
    if (_isBalanced || _totalDebit + _totalCredit <= 0) return;
    final diff = _balanceDiff;
    if (_lines.isEmpty) return;
    final last = _lines.last;

    setState(() {
      if (_totalDebit > _totalCredit) {
        final current = double.tryParse(last.creditCtrl.text) ?? 0;
        last.creditCtrl.text = (current + diff).toStringAsFixed(2);
        if (current <= 0) last.debitCtrl.clear();
      } else {
        final current = double.tryParse(last.debitCtrl.text) ?? 0;
        last.debitCtrl.text = (current + diff).toStringAsFixed(2);
        if (current <= 0) last.creditCtrl.clear();
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  /// File type icon (colorful Material icon per type)
  Widget _fileIconWidget(String? ext, {double size = 40}) {
    final e = ext?.toLowerCase() ?? '';
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

  /// Show a larger preview of the file in a full-screen dialog
  void _showFilePreview(PlatformFile file, bool isImage) {
    final e = file.extension?.toLowerCase() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _fileIconWidget(file.extension, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.name,
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
            // Preview content
            if (isImage)
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: file.bytes != null
                      ? Image.memory(
                          file.bytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Text('Unable to load image')),
                        )
                      : (file.path != null
                            ? Image.file(
                                File(file.path!),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Unable to load image'),
                                ),
                              )
                            : const Center(child: Text('No image data'))),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    _fileIconWidget(file.extension, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      file.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _typeLabel(e),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (file.size > 0)
                      Text(
                        _formatSize(file.size),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Preview not available for this file type.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            // Bottom bar
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
        return 'File';
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  BUILD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService,
      currentIndex: 1,
      onIndexChanged: (_) {},
      title: _isEditing ? 'Edit Entry' : 'Journal Entry',
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _professionalMode ? _buildExpertGrid() : _buildAiMode(),
                  const SizedBox(height: 16),
                  _buildAttachmentRow(),
                  const SizedBox(height: 12),
                  _buildBalanceFooter(),
                  const SizedBox(height: 16),
                  _buildActionBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top bar with navigation to Journal Entry List
  /// Unified toolbar: mode chips (left) + navigation (right)
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          // Mode chips
          _ModeChip(
            label: 'Professional',
            icon: Icons.table_chart_outlined,
            selected: _professionalMode,
            onTap: () => setState(() => _professionalMode = true),
          ),
          const SizedBox(width: 6),
          _ModeChip(
            label: 'AI Smart Entry',
            icon: Icons.auto_fix_high,
            selected: !_professionalMode,
            onTap: () => setState(() => _professionalMode = false),
          ),
          const Spacer(),
          // Entry List button
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JournalEntryListScreen(
                    authService: widget.authService,
                    glService: widget.glService,
                    orgService: widget.orgService,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.list_alt, size: 16),
            label: const Text('Entry List', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              foregroundColor: AppTheme.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Document Header',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _documentTypeLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Company Code
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedOrgId,
                    decoration: const InputDecoration(
                      labelText: 'Company Code',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    isExpanded: true,
                    hint: Text(
                      'Select company',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    items: _organizations
                        .map<DropdownMenuItem<String>>(
                          (o) => DropdownMenuItem<String>(
                            value: o['id'] as String?,
                            child: Text(
                              '${o['org_code']} - ${o['org_name']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOrgId = v),
                  ),
                ),
                const SizedBox(width: 12),
                // Document Type
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _documentType,
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Standard', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: 'adjusting',
                        child: Text(
                          'Adjusting',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'accrual',
                        child: Text('Accrual', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _documentType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Posting Date
                Expanded(
                  child: _DateField(
                    label: 'Posting Date',
                    value: _postingDate,
                    onChanged: (d) => setState(() => _postingDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                // Document Date
                Expanded(
                  child: _DateField(
                    label: 'Document Date',
                    value: _documentDate,
                    onChanged: (d) => setState(() => _documentDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                // Reference
                Expanded(
                  child: TextField(
                    controller: _referenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reference',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headerDescCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Raw material purchase 5000.00',
                prefixIcon: const Icon(Icons.description_outlined, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String get _documentTypeLabel {
    switch (_documentType) {
      case 'adjusting':
        return 'Adjusting';
      case 'accrual':
        return 'Accrual';
      default:
        return 'Standard';
    }
  }

  // â”€â”€ Expert Grid (SAP FB50 style) â”€â”€
  Widget _buildExpertGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Line Items',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 4),
                  Expanded(flex: 3, child: _AlignedHeader('Account')),
                  Expanded(
                    flex: 1,
                    child: _AlignedHeader('Debit', align: TextAlign.center),
                  ),
                  Expanded(
                    flex: 1,
                    child: _AlignedHeader('Credit', align: TextAlign.center),
                  ),
                  Expanded(
                    flex: 2,
                    child: _AlignedHeader('Line Text', align: TextAlign.center),
                  ),
                  SizedBox(width: 32),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(_lines.length, (i) => _buildLineRow(i)),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Line', style: TextStyle(fontSize: 13)),
                onPressed: () => setState(() => _lines.add(_JournalLine())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Account
          Expanded(
            flex: 3,
            child: _accountsLoading
                ? const SizedBox(
                    height: 36,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : SizedBox(
                    height: 36,
                    child: DropdownButtonFormField<String>(
                      value: line.selectedAccount,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      hint: const Text(
                        'Select account',
                        style: TextStyle(fontSize: 12),
                      ),
                      items: _accounts.where((a) => a.isLeaf && a.isActive && a.reconciliationType == 'none').map(
                        (a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${a.code} - ${a.name}',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (v) =>
                          setState(() => line.selectedAccount = v),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          // Debit
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: line.debitCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: _lineInputDeco('0.00'),
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {
                  // Auto-clear the opposite field when user types
                  if (double.tryParse(line.debitCtrl.text) != null &&
                      double.tryParse(line.debitCtrl.text)! > 0) {
                    line.creditCtrl.clear();
                  }
                }),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Credit
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: line.creditCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: _lineInputDeco('0.00'),
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {
                  // Auto-clear the opposite field
                  if (double.tryParse(line.creditCtrl.text) != null &&
                      double.tryParse(line.creditCtrl.text)! > 0) {
                    line.debitCtrl.clear();
                  }
                }),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Description
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: line.lineDescCtrl,
                decoration: _lineInputDeco('Description'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Remove
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: AppTheme.errorColor,
              size: 18,
            ),
            onPressed: _lines.length > 1
                ? () => setState(() => _lines.removeAt(index))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28),
          ),
        ],
      ),
    );
  }

  InputDecoration _lineInputDeco(String hint) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: const OutlineInputBorder(),
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
    );
  }

  // â”€â”€ AI Mode â”€â”€
  Widget _buildAiMode() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AI Smart Entry',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiDescriptionCtrl,
              decoration: InputDecoration(
                labelText: 'Describe the business in natural language',
                hintText: 'e.g. Pay office rent 5000 from bank account',
                prefixIcon: const Icon(Icons.edit_note, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aiAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '5000.00',
                      prefixIcon: Icon(Icons.attach_money, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _aiLoading ? null : _getAiSuggestion,
                  icon: _aiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(
                    _aiLoading ? 'Analyzing...' : 'AI Suggest',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 40),
                  ),
                ),
              ],
            ),
            if (_aiSuggestion != null) ...[
              const SizedBox(height: 16),
              _buildAiResult(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiResult() {
    final confidence = (_aiSuggestion!['confidence'] as num?)?.toDouble() ?? 0;
    final suggested = _aiSuggestion!['suggested_lines'] as List<dynamic>? ?? [];

    double aiDebit = 0, aiCredit = 0;
    for (final l in suggested) {
      aiDebit += (l['debit'] as num?)?.toDouble() ?? 0;
      aiCredit += (l['credit'] as num?)?.toDouble() ?? 0;
    }
    final aiDiff = (aiDebit - aiCredit).abs();
    final aiBalanced = aiDiff < 0.01 && aiDebit > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AI Confidence: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      confidence > 0.8
                          ? Colors.green
                          : confidence > 0.5
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: confidence > 0.8
                      ? Colors.green.shade700
                      : confidence > 0.5
                      ? Colors.orange.shade700
                      : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggested.asMap().entries.map(
            (e) => Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ((e.value['debit'] as num?)?.toDouble() ?? 0) > 0
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        ((e.value['debit'] as num?)?.toDouble() ?? 0) > 0
                            ? 'DR'
                            : 'CR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              ((e.value['debit'] as num?)?.toDouble() ?? 0) > 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.value['account_code']} - ${e.value['account_name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        if (e.value['description'] != null &&
                            (e.value['description'] as String).isNotEmpty)
                          Text(
                            e.value['description'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${GlService.fmtAmount(((e.value['debit'] as num?) ?? (e.value['credit'] as num?)))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                aiBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 16,
                color: aiBalanced ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                aiBalanced
                    ? 'Balanced \u2713'
                    : 'Difference: \$${GlService.fmtAmount(aiDiff)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: aiBalanced ? Colors.green : Colors.orange,
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Attachments â”€â”€
  /// Compact attachment row (no expandable preview)
  Widget _buildAttachmentRow() {
    final count = _attachedFiles.length;
    return Row(
      children: [
        if (count > 0) ...[
          Icon(Icons.attach_file, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$count file(s) attached',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 14),
            label: const Text('View', style: TextStyle(fontSize: 11)),
            onPressed: () => _showAttachmentsDialog(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppTheme.accentBlue,
            ),
          ),
        ],
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.attach_file, size: 14),
          label: Text(
            count > 0 ? 'Add more' : 'Add Attachment',
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: _pickFile,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isBalanced ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isBalanced ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
            color: _isBalanced ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Total Debit: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            '\$${GlService.fmtAmount(_totalDebit)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            'Total Credit: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            '\$${GlService.fmtAmount(_totalCredit)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          if (!_isBalanced && _totalDebit + _totalCredit > 0) ...[
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Diff: \$${GlService.fmtAmount(_balanceDiff)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.balance, size: 14),
              label: const Text(
                'Balance',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              onPressed: _autoBalance,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.accentBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isBalanced ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isBalanced ? '\u2713 Balanced' : '\u26A0 Unbalanced',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Action Bar â”€â”€
  Widget _buildActionBar() {
    return Column(
      children: [
        // Primary actions: Save Draft | Save & Post
        Row(
          children: [
            // Save as Draft
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _saveDraft,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note, size: 18),
                label: const Text('Save Draft', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: AppTheme.warningColor,
                  side: const BorderSide(color: AppTheme.warningColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Save & Post
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : (_professionalMode ? _saveAndPost : _submitFromAi),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  _loading ? 'Processing...' : 'Save Entry',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Reset
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetAll,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Reset', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  Helper Widgets
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _AlignedHeader extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _AlignedHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Colors.grey.shade700,
      ),
      textAlign: align,
    );
  }
}

class _JournalLine {
  String? selectedAccount;
  final TextEditingController debitCtrl = TextEditingController();
  final TextEditingController creditCtrl = TextEditingController();
  final TextEditingController lineDescCtrl = TextEditingController();
}
