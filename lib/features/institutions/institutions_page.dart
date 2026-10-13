import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../repositories/institution_repository.dart';
import 'institution_details_page.dart';

class InstitutionsPage extends StatefulWidget {
  const InstitutionsPage({super.key, required this.db, required this.s});
  final Database db;
  final S s;

  @override
  State<InstitutionsPage> createState() => _InstitutionsPageState();
}

class _InstitutionsPageState extends State<InstitutionsPage> {
  late InstitutionRepository _repo;
  late Future<List<Map<String, Object?>>> _future;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _repo = InstitutionRepository(widget.db);
    _reload();
  }

  void _reload() {
    _future = _repo.list(includeArchived: _showArchived);
  }

  String _name(Map<String, Object?> row) {
    final preferred = widget.s.isAr ? row['name_ar'] : row['name_fr'];
    final fallback = widget.s.isAr ? row['name_fr'] : row['name_ar'];
    final value = (preferred as String?)?.trim();
    if (value != null && value.isNotEmpty) return value;
    return (fallback as String?) ?? '';
  }

  Future<void> _edit([Map<String, Object?>? row]) async {
    final ar = TextEditingController(text: row?['name_ar'] as String? ?? '');
    final fr = TextEditingController(text: row?['name_fr'] as String? ?? '');
    final short = TextEditingController(text: row?['short_name'] as String? ?? '');
    final address = TextEditingController(text: row?['address'] as String? ?? '');
    final phone = TextEditingController(text: row?['phone'] as String? ?? '');
    final email = TextEditingController(text: row?['email'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row == null ? widget.s.t('institution_add') : widget.s.t('institution_edit')),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: ar, decoration: InputDecoration(labelText: widget.s.t('institution_name_ar'))),
                const SizedBox(height: 10),
                TextFormField(controller: fr, decoration: InputDecoration(labelText: widget.s.t('institution_name_fr'))),
                const SizedBox(height: 10),
                TextFormField(controller: short, decoration: InputDecoration(labelText: widget.s.t('institution_short'))),
                const SizedBox(height: 10),
                TextFormField(controller: address, decoration: InputDecoration(labelText: widget.s.t('address'))),
                const SizedBox(height: 10),
                TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: widget.s.t('phone'))),
                const SizedBox(height: 10),
                TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: widget.s.t('email'))),
                const SizedBox(height: 8),
                Text(widget.s.t('institution_name_hint'), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(widget.s.t('cancel'))),
          FilledButton(onPressed: () {
            if (ar.text.trim().isEmpty && fr.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('institution_name_required'))));
              return;
            }
            Navigator.pop(dialogContext, true);
          }, child: Text(widget.s.t('save'))),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        await _repo.save(
          id: row?['id'] as int?, nameAr: ar.text, nameFr: fr.text,
          shortName: short.text, address: address.text, phone: phone.text, email: email.text,
        );
        if (mounted) setState(_reload);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('save_failed'))));
      }
    }
    ar.dispose(); fr.dispose(); short.dispose(); address.dispose(); phone.dispose(); email.dispose();
  }

  Future<void> _toggleArchive(Map<String, Object?> row) async {
    final archived = row['status'] == 'archived';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(archived ? widget.s.t('institution_restore') : widget.s.t('institution_archive')),
        content: Text(archived ? widget.s.t('institution_restore_confirm') : widget.s.t('institution_archive_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('confirm'))),
        ],
      ),
    );
    if (confirm != true) return;
    await _repo.setArchived(row['id'] as int, !archived);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(), icon: const Icon(Icons.add), label: Text(s.t('institution_add')),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(child: Text(s.t('institutions_description'), style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(s.t('show_archived')), selected: _showArchived,
              onSelected: (v) => setState(() { _showArchived = v; _reload(); }),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text(s.t('load_failed')));
              final rows = snap.data ?? [];
              if (rows.isEmpty) return _EmptyInstitutions(s: s, onAdd: () => _edit());
              return RefreshIndicator(
                onRefresh: () async { setState(_reload); await _future; },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final archived = row['status'] == 'archived';
                    final classes = row['class_count'] as int? ?? 0;
                    final students = row['student_count'] as int? ?? 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: archived ? Colors.grey.shade200 : AppColors.tealSoft,
                            child: Icon(Icons.account_balance_outlined, color: archived ? Colors.grey : AppColors.teal),
                          ),
                          title: Text(_name(row), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if ((row['short_name'] as String?)?.isNotEmpty == true) Text(row['short_name'] as String),
                              const SizedBox(height: 5),
                              Wrap(spacing: 12, runSpacing: 4, children: [
                                _Meta(icon: Icons.class_outlined, text: '${s.t('classes')}: $classes'),
                                _Meta(icon: Icons.groups_outlined, text: '${s.t('students')}: $students'),
                                if (archived) _Meta(icon: Icons.archive_outlined, text: s.t('archived')),
                              ]),
                              if ((row['phone'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 4), Text(row['phone'] as String),
                              ],
                            ]),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) { if (v == 'edit') _edit(row); if (v == 'archive') _toggleArchive(row); },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                              PopupMenuItem(value: 'archive', child: Text(archived ? s.t('restore') : s.t('archive'))),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => InstitutionDetailsPage(db: widget.db, s: s, institution: row),
                          )),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: AppColors.muted), const SizedBox(width: 4), Text(text, style: Theme.of(context).textTheme.bodySmall),
  ]);
}

class _EmptyInstitutions extends StatelessWidget {
  const _EmptyInstitutions({required this.s, required this.onAdd});
  final S s;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_balance_outlined, size: 58, color: AppColors.teal.withValues(alpha: .65)),
        const SizedBox(height: 12), Text(s.t('no_institution'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6), Text(s.t('institution_empty_hint'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(s.t('institution_add'))),
      ]),
    ),
  );
}
