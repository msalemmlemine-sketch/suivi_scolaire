import 'package:suivi_scolaire/core/services/excel_service.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../repositories/student_repository.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.db, required this.s});
  final Database db;
  final S s;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  late StudentRepository _repo;
  final _search = TextEditingController();
  late Future<List<Map<String, Object?>>> _students;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _repo = StudentRepository(widget.db);
    _reload();
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _reload() => _students = _repo.activeStudents(search: _search.text);

  String _localized(Map<String, Object?> row, String arKey, String frKey) {
    final preferred = row[widget.s.isAr ? arKey : frKey] as String?;
    final fallback = row[widget.s.isAr ? frKey : arKey] as String?;
    if (preferred?.trim().isNotEmpty == true) return preferred!;
    return fallback ?? '';
  }

  String _studentName(Map<String, Object?> row) {
    final fr = [row['family_name_fr'], row['given_name_fr']].whereType<String>().map((x) => x.trim()).where((x) => x.isNotEmpty).join(' ');
    final ar = (row['full_name_ar'] as String?)?.trim() ?? '';
    final original = (row['full_name_original'] as String?)?.trim() ?? '';
    if (widget.s.isAr) return ar.isNotEmpty ? ar : (original.isNotEmpty ? original : fr);
    return fr.isNotEmpty ? fr : (original.isNotEmpty ? original : ar);
  }

  Future<void> _addStudent() async {
    final classes = await _repo.availableClasses();
    if (!mounted) return;
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('student_no_classes'))));
      return;
    }
    final original = TextEditingController();
    final family = TextEditingController();
    final given = TextEditingController();
    final arabic = TextEditingController();
    final matricule = TextEditingController();
    final birth = TextEditingController();
    final guardian = TextEditingController();
    final phone = TextEditingController();
    int? classId = classes.first['id'] as int;
    String? gender;
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) => AlertDialog(
      title: Text(widget.s.t('student_add')),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          value: classId,
          isExpanded: true,
          decoration: InputDecoration(labelText: widget.s.t('class')),
          items: classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(_classLabel(c), maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setDialog(() => classId = v),
        ),
        const SizedBox(height: 10),
        TextField(controller: original, decoration: InputDecoration(labelText: widget.s.t('student_original_name'))),
        const SizedBox(height: 10),
        TextField(controller: family, decoration: InputDecoration(labelText: widget.s.t('family_name_fr'))),
        const SizedBox(height: 10),
        TextField(controller: given, decoration: InputDecoration(labelText: widget.s.t('given_name_fr'))),
        const SizedBox(height: 10),
        TextField(controller: arabic, decoration: InputDecoration(labelText: widget.s.t('student_name_ar'))),
        const SizedBox(height: 10),
        TextField(controller: matricule, decoration: InputDecoration(labelText: widget.s.t('matricule'))),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: gender, decoration: InputDecoration(labelText: widget.s.t('gender')),
          items: [DropdownMenuItem(value: 'M', child: Text(widget.s.t('male'))), DropdownMenuItem(value: 'F', child: Text(widget.s.t('female')))],
          onChanged: (v) => setDialog(() => gender = v),
        ),
        const SizedBox(height: 10),
        TextField(controller: birth, keyboardType: TextInputType.datetime, decoration: InputDecoration(labelText: widget.s.t('birth_date_hint'))),
        const SizedBox(height: 10),
        TextField(controller: guardian, decoration: InputDecoration(labelText: widget.s.t('guardian_name'))),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: widget.s.t('guardian_phone'))),
        const SizedBox(height: 8),
        Text(widget.s.t('student_preserve_names'), style: Theme.of(context).textTheme.bodySmall),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(widget.s.t('cancel'))),
        FilledButton(onPressed: () {
          if ([original.text, family.text, given.text, arabic.text].every((x) => x.trim().isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('student_name_required'))));
            return;
          }
          Navigator.pop(dialogContext, true);
        }, child: Text(widget.s.t('save'))),
      ],
    )));
    if (ok == true && classId != null) {
      try {
        final birthDate = birth.text.trim();
        if (birthDate.isNotEmpty) {
          final parsed = DateTime.tryParse(birthDate);
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate) || parsed == null || parsed.toIso8601String().substring(0, 10) != birthDate) throw const FormatException();
        }
        await _repo.createAndEnroll(
          classId: classId!, originalName: original.text, familyNameFr: family.text,
          givenNameFr: given.text, fullNameAr: arabic.text, matricule: matricule.text,
          gender: gender, birthDate: birthDate, guardianName: guardian.text, guardianPhone: phone.text,
        );
        if (mounted) setState(_reload);
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('student_save_error'))));
      }
    }
    original.dispose(); family.dispose(); given.dispose(); arabic.dispose(); matricule.dispose(); birth.dispose(); guardian.dispose(); phone.dispose();
  }

  String _classLabel(Map<String, Object?> row) {
    final inst = _localized(row, 'institution_name_ar', 'institution_name_fr');
    final cls = _localized(row, 'name_ar', 'name_fr');
    return '$inst — $cls (${row['year_name']})';
  }

  Future<void> _endEnrollment(Map<String, Object?> row) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(widget.s.t('student_end_enrollment')),
      content: Text(widget.s.t('student_end_confirm')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('confirm')))],
    ));
    if (ok != true) return;
    await _repo.endEnrollment(row['enrollment_id'] as int);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _addStudent, icon: const Icon(Icons.person_add_alt_1), label: Text(s.t('student_add'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
          Expanded(child: Text(s.t('students_description'), style: Theme.of(context).textTheme.bodyMedium)),
          IconButton(onPressed: () => setState(() => _showSearch = !_showSearch), icon: const Icon(Icons.search), tooltip: s.t('search')),
          IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh), tooltip: s.t('refresh')),
        ])),
        if (_showSearch) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(
          controller: _search, autofocus: true, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.t('search_student'), suffixIcon: IconButton(onPressed: () { _search.clear(); setState(_reload); }, icon: const Icon(Icons.clear))),
          onChanged: (_) => setState(_reload),
        )),
        Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: _students, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(s.t('load_failed')));
          final rows = snap.data ?? [];
          if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.groups_outlined, size: 56, color: AppColors.teal), const SizedBox(height: 12),
            Text(s.t('student_empty'), style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
            Text(s.t('student_empty_hint'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ])));
          return RefreshIndicator(onRefresh: () async { setState(_reload); await _students; }, child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 92), itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = rows[i];
              final cls = _localized(row, 'class_name_ar', 'class_name_fr');
              final inst = _localized(row, 'institution_name_ar', 'institution_name_fr');
              final phone = (row['guardian_phone'] as String?)?.trim() ?? '';
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.tealSoft, child: Text(_studentName(row).isEmpty ? '?' : _studentName(row).substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold))),
                title: Text(_studentName(row), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$inst • $cls'), Text('${s.t('academic_year')}: ${row['year_name']}'),
                  if (phone.isNotEmpty) Text('${s.t('guardian_phone')}: $phone'),
                ])),
                trailing: PopupMenuButton<String>(onSelected: (_) => _endEnrollment(row), itemBuilder: (_) => [PopupMenuItem(value: 'end', child: Text(s.t('student_end_enrollment')))]),
                isThreeLine: true,
              ));
            },
          ));
        })),
      ]),
    );
  }
}
