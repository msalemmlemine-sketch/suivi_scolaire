import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/errors_ui.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../models/institution.dart';
import '../../models/school.dart';
import '../../repositories/school_repository.dart';

/// One institution: its academic years and the classes of the selected year.
class InstitutionDetailPage extends StatefulWidget {
  const InstitutionDetailPage({super.key, required this.db, required this.s, required this.inst});
  final Database db;
  final S s;
  final Institution inst;

  @override
  State<InstitutionDetailPage> createState() => _InstitutionDetailPageState();
}

class _InstitutionDetailPageState extends State<InstitutionDetailPage> {
  late final SchoolRepository _repo = SchoolRepository(widget.db);
  List<YearLink> _years = const [];
  List<SchoolClass> _classes = const [];
  int? _yearId;
  bool _showArchived = false;
  bool _loading = true;

  S get s => widget.s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  YearLink? get _selected {
    for (final y in _years) {
      if (y.id == _yearId) return y;
    }
    return null;
  }

  Future<void> _load({int? selectYear}) async {
    final years = await _repo.yearsOf(widget.inst.id);
    int? sel = selectYear ?? _yearId;
    if (sel == null || !years.any((y) => y.id == sel)) {
      sel = null;
      for (final y in years) {
        if (y.isActive) sel = y.id;
      }
      sel ??= years.isEmpty ? null : years.first.id;
    }
    final classes =
        sel == null ? <SchoolClass>[] : await _repo.classesOf(widget.inst.id, sel, archived: _showArchived);
    if (!mounted) return;
    setState(() {
      _years = years;
      _yearId = sel;
      _classes = classes;
      _loading = false;
    });
  }

  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(s, e))));

  Future<void> _addYear() async {
    final saved = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _YearForm(s: s, repo: _repo, institutionId: widget.inst.id),
    );
    if (saved != null) await _load(selectYear: saved);
  }

  Future<void> _classForm([SchoolClass? c]) async {
    final yid = _yearId;
    if (yid == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ClassForm(s: s, repo: _repo, institutionId: widget.inst.id, yearId: yid, cls: c),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleClass(SchoolClass c) async {
    try {
      await _repo.setClassArchived(c.id, !c.isArchived);
      await _load();
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _activate(YearLink y) async {
    try {
      await _repo.setActiveYear(widget.inst.id, y.id);
      await _load();
    } catch (e) {
      _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sel = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(widget.inst.displayName(s.isAr), maxLines: 1, overflow: TextOverflow.ellipsis)),
      floatingActionButton: sel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _classForm(),
              icon: const Icon(Icons.add),
              label: Text(s.t('add_class')),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(s.t('school_year'), style: text.titleMedium),
                const SizedBox(height: 8),
                if (_years.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.t('no_year_title'), style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(s.t('no_year_body'), style: text.bodySmall),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: _addYear, icon: const Icon(Icons.add), label: Text(s.t('add_year'))),
                      ]),
                    ),
                  )
                else ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final y in _years)
                      ChoiceChip(
                        label: Text(y.isActive ? '${y.name} · ${s.t('active_year')}' : y.name),
                        selected: y.id == _yearId,
                        onSelected: (_) => _load(selectYear: y.id),
                      ),
                    ActionChip(avatar: const Icon(Icons.add, size: 18), label: Text(s.t('add_year')), onPressed: _addYear),
                  ]),
                  if (sel != null && !sel.isActive) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                          onPressed: () => _activate(sel),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(s.t('set_active_year'))),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text(s.t('classes'), style: text.titleMedium)),
                    FilterChip(
                      label: Text(s.t('show_archived')),
                      selected: _showArchived,
                      onSelected: (v) {
                        _showArchived = v;
                        _load();
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (_classes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(s.t('no_classes'), style: text.bodySmall)),
                    )
                  else
                    for (final c in _classes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
                                child: const Icon(Icons.groups_outlined, color: AppColors.teal),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.displayName(s.isAr), style: text.titleMedium),
                                  Text(
                                    [
                                      if (c.level?.trim().isNotEmpty == true) c.level!.trim(),
                                      '${c.studentCount} ${s.t('students_count')}',
                                    ].join(' · '),
                                    style: text.bodySmall,
                                  ),
                                ]),
                              ),
                              IconButton(
                                  tooltip: s.t('edit'),
                                  onPressed: () => _classForm(c),
                                  icon: const Icon(Icons.edit_outlined)),
                              IconButton(
                                tooltip: s.t(c.isArchived ? 'restore' : 'archive'),
                                onPressed: () => _toggleClass(c),
                                icon: Icon(c.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                              ),
                            ]),
                          ),
                        ),
                      ),
                ],
              ],
            ),
    );
  }
}

Widget _sheetField(TextEditingController c, String label, {TextDirection? dir, TextInputType? type}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        textDirection: dir,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      ),
    );

class _YearForm extends StatefulWidget {
  const _YearForm({required this.s, required this.repo, required this.institutionId});
  final S s;
  final SchoolRepository repo;
  final int institutionId;

  @override
  State<_YearForm> createState() => _YearFormState();
}

class _YearFormState extends State<_YearForm> {
  static String _defaultName() {
    final n = DateTime.now();
    final start = n.month >= 8 ? n.year : n.year - 1;
    return '$start-${start + 1}';
  }

  late final _name = TextEditingController(text: _defaultName());
  late final _start = TextEditingController(text: '${_defaultName().substring(0, 4)}-10-01');
  late final _end = TextEditingController(text: '${_defaultName().substring(5)}-07-01');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repo
          .addYear(widget.institutionId, name: _name.text, startDate: _start.text, endDate: _end.text);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(widget.s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('add_year'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _sheetField(_name, s.t('year_name'), dir: TextDirection.ltr),
          _sheetField(_start, s.t('start_date'), dir: TextDirection.ltr, type: TextInputType.datetime),
          _sheetField(_end, s.t('end_date'), dir: TextDirection.ltr, type: TextInputType.datetime),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.t('cancel')))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: Text(s.t('save')))),
          ]),
        ]),
      ),
    );
  }
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({required this.s, required this.repo, required this.institutionId, required this.yearId, this.cls});
  final S s;
  final SchoolRepository repo;
  final int institutionId, yearId;
  final SchoolClass? cls;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  late final _fr = TextEditingController(text: widget.cls?.nameFr);
  late final _ar = TextEditingController(text: widget.cls?.nameAr);
  late final _level = TextEditingController(text: widget.cls?.level);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _fr.dispose();
    _ar.dispose();
    _level.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.cls == null) {
        await widget.repo.addClass(widget.institutionId, widget.yearId,
            nameFr: _fr.text, nameAr: _ar.text, level: _level.text);
      } else {
        await widget.repo.updateClass(widget.cls!.id, nameFr: _fr.text, nameAr: _ar.text, level: _level.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(widget.s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t(widget.cls == null ? 'add_class' : 'edit_class'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _sheetField(_fr, s.t('class_name_fr'), dir: TextDirection.ltr),
          _sheetField(_ar, s.t('class_name_ar'), dir: TextDirection.rtl),
          _sheetField(_level, s.t('level')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(s.t('cancel')))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: Text(s.t('save')))),
          ]),
        ]),
      ),
    );
  }
}
