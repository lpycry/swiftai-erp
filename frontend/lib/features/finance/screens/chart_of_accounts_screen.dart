import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/core/theme/app_theme.dart';
import 'package:swiftai_erp/core/widgets/app_layout.dart';
import 'package:swiftai_erp/features/finance/services/gl_service.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  final AuthService authService;
  final GlService glService;
  const ChartOfAccountsScreen({super.key, required this.authService, required this.glService});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  List<AccountModel> _roots = [];
  List<AccountModel> _flat = [];
  List<AccountModel> _searchResults = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _expanded = {};

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tree = await widget.glService.getAccountTree();
      _flat = _flatten(tree);
      setState(() => _roots = tree);
    } catch (e) {
      if (mounted) _err('Failed to load: $e');
    } finally { setState(() => _loading = false); }
  }

  List<AccountModel> _flatten(List<AccountModel> list) {
    final r = <AccountModel>[];
    for (final n in list) { r.add(n); if (n.children != null) r.addAll(_flatten(n.children!)); }
    return r;
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor));

  void _search(String q) {
    _query = q;
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    widget.glService.searchAccounts(q.trim()).then((r) {
      if (mounted) setState(() => _searchResults = r);
    }).catchError((e) { if (mounted) _err('Search failed: $e'); });
  }

  void _toggle(String id) => setState(() {
    if (_expanded.contains(id)) {
      _expanded.remove(id);
    } else {
      _expanded.add(id);
    }
  });

  // ── Create ──
  void _create({String? parentId, String? parentCode}) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'ASSET', recType = 'none';
    bool isLeaf = true;
    String? selParent = parentId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(selParent != null ? 'Add Sub Account' : 'Create Account'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (parentCode != null) Padding(padding: const EdgeInsets.only(bottom:8),
            child: Text('Parent: $parentCode', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Account Code', hintText: 'e.g. 1101')),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. Cash')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type, decoration: const InputDecoration(labelText: 'Account Type'),
            items: 'ASSET,LIABILITY,EQUITY,REVENUE,COGS,EXPENSE,OTHER_INCOME,OTHER_EXPENSE'.split(',').map((v) =>
              DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setS(() => type = v!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: recType, decoration: const InputDecoration(labelText: 'Reconciliation Type'),
            items: [['none','None'],['customer','Customer (AR)'],['vendor','Vendor (AP)'],['asset','Asset']]
              .map((v) => DropdownMenuItem(value: v[0], child: Text(v[1], style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setS(() => recType = v!)),
          const SizedBox(height: 12),
          if (selParent == null)
            DropdownButtonFormField<String>(
              initialValue: '', decoration: const InputDecoration(labelText: 'Parent Account'),
              items: [
                const DropdownMenuItem(value: '', child: Text('(None - Top Level)', style: TextStyle(fontSize: 13))),
                ..._flat.where((a) => a.isActive && !a.isLeaf).map((a) => DropdownMenuItem(
                  value: a.id, child: Text('${a.code} - ${a.name}', style: const TextStyle(fontSize: 13)))),
              ], onChanged: (v) => setS(() => selParent = v == '' ? null : v)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Detail Account'), contentPadding: EdgeInsets.zero,
            subtitle: Text(isLeaf ? 'Postable (can post entries)' : 'Grouping account only',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            value: isLeaf, onChanged: (v) => setS(() => isLeaf = v)),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
            try {
              final data = <String, dynamic>{
                'account_code': codeCtrl.text, 'account_name': nameCtrl.text,
                'account_type': type, 'is_leaf': isLeaf, 'reconciliation_type': recType,
                'description': descCtrl.text,
              };
              if (selParent != null && selParent!.isNotEmpty) data['parent_id'] = selParent;
              await widget.glService.createAccount(data);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            } catch (e) { if (mounted) _err('$e'); }
          }, child: const Text('Create')),
        ],
      ),
    ));
  }

  // ── Edit ──
  void _edit(AccountModel a) {
    final nameCtrl = TextEditingController(text: a.name);
    final descCtrl = TextEditingController(text: a.description ?? '');
    String acctType = a.type;
    String recType = a.reconciliationType;
    bool isLeaf = a.isLeaf;
    String? selParent = a.parentId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Edit Account'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AccountModel.typeColor(a.type).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text('${a.code}  ${AccountModel.typeDisplayName(a.type)}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AccountModel.typeColor(a.type))),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: acctType, decoration: const InputDecoration(labelText: 'Account Type'),
            items: 'ASSET,LIABILITY,EQUITY,REVENUE,COGS,EXPENSE,OTHER_INCOME,OTHER_EXPENSE'.split(',').map((v) =>
              DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setS(() => acctType = v!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: recType, decoration: const InputDecoration(labelText: 'Reconciliation Type'),
            items: [['none','None'],['customer','Customer (AR)'],['vendor','Vendor (AP)'],['asset','Asset']]
              .map((v) => DropdownMenuItem(value: v[0], child: Text(v[1], style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setS(() => recType = v!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selParent,
            decoration: const InputDecoration(labelText: 'Parent Account'),
            items: [
              const DropdownMenuItem(value: '', child: Text('(None - Top Level)', style: TextStyle(fontSize: 13))),
              ..._flat.where((x) => x.id != a.id && x.isActive && !x.isLeaf).map((x) => DropdownMenuItem(
                value: x.id, child: Text('${x.code} - ${x.name}', style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) => setS(() => selParent = v == '' ? null : v)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Detail Account'), contentPadding: EdgeInsets.zero,
            subtitle: Text(isLeaf ? 'Postable (can post entries)' : 'Grouping account only',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            value: isLeaf, onChanged: (v) => setS(() => isLeaf = v)),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            try {
              final data = <String, dynamic>{
                'account_name': nameCtrl.text,
                'account_type': acctType,
                'reconciliation_type': recType,
                'is_leaf': isLeaf,
                'description': descCtrl.text,
              };
              if (selParent != null && selParent!.isNotEmpty) data['parent_id'] = selParent;
              await widget.glService.updateAccount(a.id, data);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            } catch (e) { if (mounted) _err('$e'); }
          }, child: const Text('Save')),
        ],
      ),
    ));
  }

  // ── Delete ──
  Future<void> _delete(AccountModel a) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Account'),
      content: Text('Are you sure you want to delete "${a.code} ${a.name}"?\n\n'
          '• Accounts with child accounts cannot be deleted\n'
          '• Accounts with journal entry transactions cannot be deleted\n'
          '• Deleted accounts are deactivated, not permanently removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try {
      await widget.glService.deleteAccount(a.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) _err('$e');
    }
  }

  // ── Reactivate ──
  Future<void> _reactivate(AccountModel a) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reactivate Account'),
      content: Text('Reactivate "${a.code} ${a.name}"?'), actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Reactivate')),
      ],
    ));
    if (ok != true) return;
    try {
      await widget.glService.reactivateAccount(a.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account reactivated'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) { if (mounted) _err('$e'); }
  }

  IconData _icon(String t) {
    switch (t.toUpperCase()) {
      case 'ASSET': return Icons.account_balance;
      case 'LIABILITY': return Icons.credit_card;
      case 'EQUITY': return Icons.business;
      case 'REVENUE': return Icons.trending_up;
      case 'EXPENSE': return Icons.shopping_cart;
      case 'COGS': return Icons.inventory_2;
      case 'OTHER_INCOME': return Icons.add_chart;
      case 'OTHER_EXPENSE': return Icons.money_off;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      authService: widget.authService, currentIndex: 1, onIndexChanged: (_) {},
      title: 'Chart of Accounts',
      body: Column(children: [
        // Search + Toolbar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by code or name...', isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 16),
                          onPressed: () { _searchCtrl.clear(); _search(''); })
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.accentGradientStart, width: 2)),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: _search, onChanged: (v) { if (v.isEmpty) _search(''); },
              ),
            )),
            const SizedBox(width: 8),
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: AppTheme.accentGradientStart.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: IconButton(
                icon: const Icon(Icons.add, color: AppTheme.accentGradientStart, size: 20),
                onPressed: () => _create(), tooltip: 'Create Account', padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load, tooltip: 'Refresh', padding: EdgeInsets.zero),
          ]),
        ),
        // Legend
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _dot('ASSET', AccountModel.typeColor('ASSET')),
              _dot('LIABILITY', AccountModel.typeColor('LIABILITY')),
              _dot('EQUITY', AccountModel.typeColor('EQUITY')),
              _dot('REVENUE', AccountModel.typeColor('REVENUE')),
              _dot('EXPENSE', AccountModel.typeColor('EXPENSE')),
              _dot('COGS', AccountModel.typeColor('COGS')),
              _dot('O.INC', AccountModel.typeColor('OTHER_INCOME')),
              _dot('O.EXP', AccountModel.typeColor('OTHER_EXPENSE')),
            ]),
          ),
        ),
        const Divider(height: 16),
        // Content
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isNotEmpty ? _buildSearch()
          : _roots.isEmpty ? const Center(child: Text('No accounts', style: TextStyle(color: AppTheme.textMuted)))
          : ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: _roots.map((a) => _node(a, 0)).toList())),
      ]),
    );
  }

  Widget _dot(String label, Color c) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _buildSearch() {
    if (_searchResults.isEmpty) {
      return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textMuted),
        const SizedBox(height: 8),
        Text('No matching accounts', style: TextStyle(color: AppTheme.textMuted)),
      ]));
    }
    return ListView.builder(padding: const EdgeInsets.all(8), itemCount: _searchResults.length,
      itemBuilder: (_, i) => _card(_searchResults[i]));
  }

  Widget _node(AccountModel a, int depth) {
    final kids = a.children ?? [];
    final open = _expanded.contains(a.id);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _card(a, depth: depth, hasKids: kids.isNotEmpty, open: open),
      if (kids.isNotEmpty && open) ...kids.map((c) => _node(c, depth + 1)),
    ]);
  }

  Widget _card(AccountModel a, {int depth = 0, bool hasKids = false, bool open = false}) {
    final c = AccountModel.typeColor(a.type);
    final isParent = !a.isLeaf;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderColor, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: hasKids ? () => _toggle(a.id) : null,
        onLongPress: () => _menu(a),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + depth * 20, 8, 12, 8),
          child: Row(children: [
            // Expand icon
            if (hasKids)
              Icon(open ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted)
            else
              const SizedBox(width: 18),
            const SizedBox(width: 4),
            // Type icon
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(_icon(a.type), size: 16, color: c)),
            const SizedBox(width: 10),
            // Code badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.accentGradientStart.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
              child: Text(a.code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentGradientStart)),
            ),
            const SizedBox(width: 8),
            // Name + Description
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: TextStyle(fontSize: 13, fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w500, color: AppTheme.textPrimary)),
              if (a.description != null && a.description!.isNotEmpty)
                Text(a.description!, style: TextStyle(fontSize: 10, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(AccountModel.typeDisplayName(a.type), style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
            ),
            // Parent indicator
            if (isParent)
              Padding(padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                  child: Text('GROUP', style: TextStyle(fontSize: 8, color: Colors.blue.shade600, fontWeight: FontWeight.w700)))),
            // Inactive badge
            if (!a.isActive)
              Padding(padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.textMuted.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: const Text('INACTIVE', style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 4),
            // More menu
            GestureDetector(
              onTap: () => _menu(a),
              child: Icon(Icons.more_horiz_rounded, size: 18, color: AppTheme.textMuted)),
          ]),
        ),
      ),
    );
  }

  void _menu(AccountModel a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AccountModel.typeColor(a.type).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_icon(a.type), color: AccountModel.typeColor(a.type), size: 18)),
            const SizedBox(height: 8),
            Text('${a.code} ${a.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
            Text('${AccountModel.typeDisplayName(a.type)}  ·  ${a.isLeaf ? 'Postable' : 'Grouping'}  ·  ${a.isActive ? 'Active' : 'Inactive'}',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ]),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.edit_outlined, color: AppTheme.accentBlue, size: 20),
          title: const Text('Edit Account', style: TextStyle(fontSize: 14)),
          onTap: () { Navigator.pop(ctx); _edit(a); },
        ),
        ListTile(
          leading: Icon(Icons.add_box_outlined, color: AppTheme.accentTeal, size: 20),
          title: const Text('Add Sub Account', style: TextStyle(fontSize: 14)),
          onTap: () { Navigator.pop(ctx); _create(parentId: a.id, parentCode: a.code); },
        ),
        ListTile(
          leading: Icon(Icons.delete_outlined, color: a.isActive ? AppTheme.errorColor : AppTheme.textMuted, size: 20),
          title: Text(a.isActive ? 'Delete Account' : 'Account Inactive', style: TextStyle(fontSize: 14, color: a.isActive ? AppTheme.textPrimary : AppTheme.textMuted)),
          enabled: a.isActive,
          onTap: a.isActive ? () { Navigator.pop(ctx); _delete(a); } : null,
        ),
        if (!a.isActive)
          ListTile(
            leading: const Icon(Icons.restore_from_trash, color: AppTheme.accentGreen, size: 20),
            title: const Text('Reactivate Account', style: TextStyle(fontSize: 14, color: AppTheme.accentGreen)),
            onTap: () { Navigator.pop(ctx); _reactivate(a); },
          ),
        const SizedBox(height: 8),
      ])),
    );
  }
}
