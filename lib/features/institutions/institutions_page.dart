import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../core/errors/app_exception.dart';
import '../../models/institution.dart';
import '../../repositories/institution_repository.dart';
import '../../widgets/empty_state.dart';

class InstitutionsPage extends StatefulWidget {
  const InstitutionsPage({super.key, required this.db, required this.s, this.onChanged});
  final Database db;
  final S s;
  final VoidCallback? onChanged;

  @override
  State<InstitutionsPage> createState() => _InstitutionsPageState();
}

class _InstitutionsPageState extends State<InstitutionsPage> {
  late final InstitutionRepository _repo = InstitutionRepository(widget.db);
  bool _archived = false;
  late Future<List<Institution>> _future = _repo.list(archived: _archived);

  S get s => widget.s;

  void _reload() {
    setState(() => _future = _repo.list(archived: _archived));
    widget.onChanged?.call();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _errorText(Object e) =>
      e is AppException && e.code == ErrorCodes.nameRequired ? s.t('err_name_required') : s.t('err_unknown');

  Future<void> _openForm([Institution? inst]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _InstitutionForm(s: s, repo: _repo, inst: inst, errorText: _errorText),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleArchive(Institution i) async {
    if (!i.isArchived) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.t('archive')),
          content: Text(s.t('archive_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('archive'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await _repo.setArchived(i.id, !i.isArchived);
      _reload();
    } catch (e) {
      _toast(_errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _archived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(s.t('add_institution')),
            ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(s.t('tab_active'))),
                ButtonSegment(value: true, label: Text(s.t('tab_archived'))),
              ],
              selected: {_archived},
              onSelectionChanged: (v) {
                _archived = v.first;
                _reload();
              },
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Institution>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? const <Institution>[];
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: s.t(_archived ? 'no_archived' : 'no_inst_title'),
                  body: _archived ? null : s.t('no_inst_body'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _InstitutionCard(
                  inst: items[i],
                  s: s,
                  onEdit: () => _openForm(items[i]),
                  onToggleArchive: () => _toggleArchive(items[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({required this.inst, required this.s, required this.onEdit, required this.onToggleArchive});
  final Institution inst;
  final S s;
  final VoidCallback onEdit, onToggleArchive;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitleParts = <String>[
      if (inst.shortName?.trim().isNotEmpty == true) inst.shortName!.trim(),
      if (inst.phone?.trim().isNotEmpty == true) inst.phone!.trim(),
      if (inst.address?.trim().isNotEmpty == true) inst.address!.trim(),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_outlined, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inst.displayName(s.isAr), style: text.titleMedium),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitleParts.join(' · '), style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          IconButton(tooltip: s.t('edit'), onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            tooltip: s.t(inst.isArchived ? 'restore' : 'archive'),
            onPressed: onToggleArchive,
            icon: Icon(inst.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
          ),
        ]),
      ),
    );
  }
}

class _InstitutionForm extends StatefulWidget {
  const _InstitutionForm({required this.s, required this.repo, required this.inst, required this.errorText});
  final S s;
  final InstitutionRepository repo;
  final Institution? inst;
  final String Function(Object) errorText;

  @override
  State<_InstitutionForm> createState() => _InstitutionFormState();
}

class _InstitutionFormState extends State<_InstitutionForm> {
  late final _ar = TextEditingController(text: widget.inst?.nameAr);
  late final _fr = TextEditingController(text: widget.inst?.nameFr);
  late final _short = TextEditingController(text: widget.inst?.shortName);
  late final _address = TextEditingController(text: widget.inst?.address);
  late final _phone = TextEditingController(text: widget.inst?.phone);
  late final _email = TextEditingController(text: widget.inst?.email);
  late final _notes = TextEditingController(text: widget.inst?.notes);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_ar, _fr, _short, _address, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.inst == null) {
        await widget.repo.add(
            nameAr: _ar.text, nameFr: _fr.text, shortName: _short.text, address: _address.text,
            phone: _phone.text, email: _email.text, notes: _notes.text);
      } else {
        await widget.repo.update(widget.inst!.id,
            nameAr: _ar.text, nameFr: _fr.text, shortName: _short.text, address: _address.text,
            phone: _phone.text, email: _email.text, notes: _notes.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.errorText(e);
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label,
      {TextDirection? dir, TextInputType? type, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        textDirection: dir,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t(widget.inst == null ? 'add_institution' : 'edit_institution'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _field(_ar, s.t('name_ar'), dir: TextDirection.rtl),
          _field(_fr, s.t('name_fr'), dir: TextDirection.ltr),
          _field(_short, s.t('short_name')),
          _field(_address, s.t('address')),
          _field(_phone, s.t('phone'), type: TextInputType.phone, dir: TextDirection.ltr),
          _field(_email, s.t('email'), type: TextInputType.emailAddress, dir: TextDirection.ltr),
          _field(_notes, s.t('notes'), maxLines: 3),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
            ),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: Text(s.t('save')))),
          ]),
        ]),
      ),
    );
  }
}
