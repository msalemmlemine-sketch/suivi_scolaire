import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../core/services/excel_service.dart';
import '../../repositories/enrollment_repository.dart';
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


  void _snack(String key, [String suffix = '']) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.s.t(key)}$suffix')));
  }

  Future<Map<String, Object?>?> _pickClass(String titleKey, {String? hintKey, List<Map<String, Object?>>? options}) async {
    final classes = options ?? await _repo.availableClasses();
    if (!mounted) return null;
    if (classes.isEmpty) {
      _snack(options == null ? 'student_no_classes' : 'transfer_no_classes');
      return null;
    }
    int selected = classes.first['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(widget.s.t(titleKey)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: widget.s.t('class')),
                items: classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(_classLabel(c), maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setDialog(() => selected = v ?? selected),
              ),
              if (hintKey != null) ...[
                const SizedBox(height: 12),
                Text(widget.s.t(hintKey), style: Theme.of(dialogContext).textTheme.bodySmall),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(widget.s.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(widget.s.t('continue_action'))),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return classes.firstWhere((c) => c['id'] == selected);
  }

  String? _normGender(String? v) {
    final x = (v ?? '').trim().toLowerCase();
    if (x.isEmpty) return null;
    const male = {'m', 'h', 'ذ', 'ذكر', 'male', 'masculin', 'garçon', 'garcon', 'homme'};
    const female = {'f', 'أ', 'انثى', 'أنثى', 'female', 'féminin', 'feminin', 'fille', 'femme'};
    if (male.contains(x)) return 'M';
    if (female.contains(x)) return 'F';
    return null;
  }

  String? _normDate(String? v) {
    final x = (v ?? '').trim();
    if (x.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(x)) {
      final d = x.substring(0, 10);
      final parsed = DateTime.tryParse(d);
      if (parsed != null && parsed.toIso8601String().substring(0, 10) == d) return d;
    }
    final m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(x);
    if (m != null) {
      final d = '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
      final parsed = DateTime.tryParse(d);
      if (parsed != null && parsed.toIso8601String().substring(0, 10) == d) return d;
    }
    return null;
  }

  Future<void> _importStudents() async {
    final cls = await _pickClass('import_pick_class', hintKey: 'import_hint');
    if (cls == null) return;
    try {
      final rows = await ExcelService.pickAndParseStudents();
      if (rows == null) return;
      if (rows.isEmpty) {
        _snack('import_empty');
        return;
      }
      var added = 0;
      var failed = 0;
      for (final r in rows) {
        try {
          await _repo.createAndEnroll(
            classId: cls['id'] as int,
            originalName: r.fullNameFr.isNotEmpty ? r.fullNameFr : r.fullNameAr,
            fullNameAr: r.fullNameAr,
            matricule: r.nationalId,
            gender: _normGender(r.gender),
            birthDate: _normDate(r.birthDate),
          );
          added++;
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      setState(_reload);
      _snack('import_done', ': $added${failed > 0 ? ' • ${widget.s.t('import_failed_rows')}: $failed' : ''}');
    } catch (_) {
      _snack('import_error');
    }
  }

  Future<void> _exportClass() async {
    final cls = await _pickClass('export_pick_class');
    if (cls == null) return;
    try {
      final all = await _repo.activeStudents();
      final inClass = all.where((r) => r['class_id'] == cls['id']).toList();
      if (inClass.isEmpty) {
        _snack('export_empty');
        return;
      }
      final list = inClass.map((r) {
        final fr = [r['family_name_fr'], r['given_name_fr']].whereType<String>().map((x) => x.trim()).where((x) => x.isNotEmpty).join(' ');
        final original = (r['full_name_original'] as String?)?.trim() ?? '';
        return <String, dynamic>{
          'national_id': r['matricule'],
          'full_name_ar': r['full_name_ar'],
          'full_name_original': original.isNotEmpty ? original : fr,
          'gender': r['gender'],
          'date_of_birth': r['birth_date'],
        };
      }).toList();
      await ExcelService.exportClassRoster(
        institutionName: _localized(cls, 'institution_name_ar', 'institution_name_fr'),
        className: _localized(cls, 'name_ar', 'name_fr'),
        academicYear: '${cls['year_name']}',
        studentsList: list,
      );
    } catch (_) {
      _snack('export_error');
    }
  }

  String _classLabel(Map<String, Object?> row) {
    final inst = _localized(row, 'institution_name_ar', 'institution_name_fr');
    final cls = _localized(row, 'name_ar', 'name_fr');
    return '$inst — $cls (${row['year_name']})';
  }

  Future<void> _editStudent(Map<String, Object?> row) async {
    String v(String k) => (row[k] as String?) ?? '';
    final original = TextEditingController(text: v('full_name_original'));
    final family = TextEditingController(text: v('family_name_fr'));
    final given = TextEditingController(text: v('given_name_fr'));
    final arabic = TextEditingController(text: v('full_name_ar'));
    final matricule = TextEditingController(text: v('matricule'));
    final birth = TextEditingController(text: v('birth_date'));
    final guardian = TextEditingController(text: v('guardian_name'));
    final phone = TextEditingController(text: v('guardian_phone'));
    final notes = TextEditingController(text: v('notes'));
    String? gender = row['gender'] as String?;
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialog) => AlertDialog(
      title: Text(widget.s.t('student_edit')),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          onChanged: (x) => setDialog(() => gender = x),
        ),
        const SizedBox(height: 10),
        TextField(controller: birth, keyboardType: TextInputType.datetime, decoration: InputDecoration(labelText: widget.s.t('birth_date_hint'))),
        const SizedBox(height: 10),
        TextField(controller: guardian, decoration: InputDecoration(labelText: widget.s.t('guardian_name'))),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: widget.s.t('guardian_phone'))),
        const SizedBox(height: 10),
        TextField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: widget.s.t('teacher_notes'))),
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
    if (ok == true) {
      try {
        final birthDate = birth.text.trim();
        if (birthDate.isNotEmpty) {
          final parsed = DateTime.tryParse(birthDate);
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate) || parsed == null || parsed.toIso8601String().substring(0, 10) != birthDate) throw const FormatException();
        }
        await _repo.updateStudent(
          row['id'] as int, originalName: original.text, familyNameFr: family.text,
          givenNameFr: given.text, fullNameAr: arabic.text, matricule: matricule.text,
          gender: gender, birthDate: birthDate, guardianName: guardian.text, guardianPhone: phone.text, notes: notes.text,
        );
        if (mounted) {
          setState(_reload);
          _snack('student_updated');
        }
      } catch (_) {
        _snack('student_save_error');
      }
    }
  }

  Future<void> _transferStudent(Map<String, Object?> row) async {
    final all = await _repo.availableClasses();
    final targets = all.where((c) => c['year_name'] == row['year_name'] && c['id'] != row['class_id']).toList();
    final cls = await _pickClass('transfer_pick_class', options: targets);
    if (cls == null) return;
    try {
      await EnrollmentRepository(widget.db).transfer(studentId: row['id'] as int, toClassId: cls['id'] as int);
      if (mounted) setState(_reload);
      _snack('student_transferred');
    } catch (_) {
      _snack('student_transfer_error');
    }
  }

  Future<void> _deleteStudent(Map<String, Object?> row) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
      title: Text(widget.s.t('student_delete')),
      content: Text('${_studentName(row)}\n\n${widget.s.t('student_delete_confirm')}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('student_delete'))),
      ],
    ));
    if (ok != true) return;
    try {
      await _repo.deleteStudentPermanently(row['id'] as int);
      if (mounted) setState(_reload);
      _snack('student_deleted');
    } catch (_) {
      _snack('student_delete_error');
    }
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
          IconButton(onPressed: _importStudents, icon: const Icon(Icons.upload_file), tooltip: s.t('import_students')),
          IconButton(onPressed: _exportClass, icon: const Icon(Icons.ios_share), tooltip: s.t('export_students')),
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
                trailing: PopupMenuButton<String>(onSelected: (a) {
                  if (a == 'edit') {
                    _editStudent(row);
                  } else if (a == 'transfer') {
                    _transferStudent(row);
                  } else if (a == 'delete') {
                    _deleteStudent(row);
                  } else {
                    _endEnrollment(row);
                  }
                }, itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(s.t('student_edit'))),
                  PopupMenuItem(value: 'transfer', child: Text(s.t('student_transfer'))),
                  PopupMenuItem(value: 'end', child: Text(s.t('student_end_enrollment'))),
                  PopupMenuItem(value: 'delete', child: Text(s.t('student_delete'), style: const TextStyle(color: Colors.red))),
                ]),
                isThreeLine: true,
              ));
            },
          ));
        })),
      ]),
    );
  }
}
