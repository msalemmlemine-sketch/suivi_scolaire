import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/errors_ui.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../models/institution.dart';
import '../../models/school.dart';
import '../../repositories/enrollment_repository.dart';
import '../../repositories/institution_repository.dart';
import '../../repositories/school_repository.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/empty_state.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.db,
    required this.s,
    required this.revision,
    required this.onGoInstitutions,
  });
  final Database db;
  final S s;
  final int revision; // bumped by the shell when institutions/classes may have changed
  final VoidCallback onGoInstitutions;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  late final _inst = InstitutionRepository(widget.db);
  late final _school = SchoolRepository(widget.db);
  late final _students = StudentRepository(widget.db);
  late final _enroll = EnrollmentRepository(widget.db);
  final _search = TextEditingController();

  List<Institution> _institutions = const [];
  int? _instId;
  int? _yearId;
  String _yearName = '';
  List<SchoolClass> _classes = const [];
  int? _classFilter;
  List<EnrolledStudent> _rows = const [];
  bool _loading = true;

  S get s => widget.s;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void didUpdateWidget(StudentsPage old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) _reloadAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(s, e))));

  Future<void> _reloadAll() async {
    final list = await _inst.list(archived: false);
    int? id = _instId;
    if (id == null || !list.any((i) => i.id == id)) id = list.isEmpty ? null : list.first.id;
    if (!mounted) return;
    _institutions = list;
    await _selectInstitution(id);
  }

  Future<void> _selectInstitution(int? id) async {
    int? year;
    String yearName = '';
    List<SchoolClass> classes = const [];
    if (id != null) {
      year = await _school.activeYearId(id);
      if (year != null) {
        classes = await _school.classesOf(id, year);
        final years = await _school.yearsOf(id);
        yearName = years.firstWhere((y) => y.id == year).name;
      }
    }
    if (!mounted) return;
    setState(() {
      _instId = id;
      _yearId = year;
      _yearName = yearName;
      _classes = classes;
      if (!classes.any((c) => c.id == _classFilter)) _classFilter = null;
    });
    await _loadRows();
  }

  Future<void> _loadRows() async {
    final id = _instId, year = _yearId;
    final rows = (id == null || year == null)
        ? <EnrolledStudent>[]
        : await _students.listEnrolled(
            institutionId: id, yearId: year, classId: _classFilter, query: _search.text);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _form([EnrolledStudent? row]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _StudentForm(s: s, repo: _students, classes: _classes, initialClass: _classFilter, row: row),
    );
    if (saved == true) {
      await _selectInstitution(_instId);
    }
  }

  Future<void> _end(EnrolledStudent r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('end_enrollment')),
        content: Text(s.t('end_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('end_enrollment'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _enroll.end(r.enrollmentId, reason: 'ended');
      await _selectInstitution(_instId);
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _transfer(EnrolledStudent r) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _TransferSheet(
        s: s,
        db: widget.db,
        institutions: _institutions,
        row: r,
        currentYearId: _yearId!,
        school: _school,
        enroll: _enroll,
      ),
    );
    if (done == true) await _selectInstitution(_instId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_institutions.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_outlined,
        title: s.t('no_inst_title'),
        body: s.t('no_inst_body'),
        actionLabel: s.t('go_institutions'),
        onAction: widget.onGoInstitutions,
      );
    }
    if (_yearId == null || _classes.isEmpty) {
      return Column(children: [
        _instPicker(),
        Expanded(
          child: EmptyState(
            icon: Icons.groups_outlined,
            title: s.t(_yearId == null ? 'no_year_title' : 'need_class_title'),
            body: s.t('need_class_body'),
            actionLabel: s.t('go_institutions'),
            onAction: widget.onGoInstitutions,
          ),
        ),
      ]);
    }
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(s.t('add_student')),
      ),
      body: Column(children: [
        _instPicker(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _loadRows(),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.t('search')),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                    label: Text(s.t('all_classes')),
                    selected: _classFilter == null,
                    onSelected: (_) {
                      _classFilter = null;
                      _loadRows();
                    }),
              ),
              for (final c in _classes)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                      label: Text(c.displayName(s.isAr)),
                      selected: _classFilter == c.id,
                      onSelected: (_) {
                        _classFilter = c.id;
                        _loadRows();
                      }),
                ),
            ],
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? EmptyState(
                  icon: Icons.person_outline,
                  title: s.t('no_students_title'),
                  body: s.t('no_students_body'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.student.displayName(s.isAr), style: text.titleMedium),
                        subtitle: Text(
                          [r.className, if (r.student.matricule?.isNotEmpty == true) r.student.matricule!].join(' · '),
                          style: text.bodySmall,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _form(r);
                            if (v == 'transfer') _transfer(r);
                            if (v == 'end') _end(r);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(s.t('edit'))),
                            PopupMenuItem(value: 'transfer', child: Text(s.t('transfer'))),
                            PopupMenuItem(value: 'end', child: Text(s.t('end_enrollment'))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _instPicker() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: DropdownButtonFormField<int>(
          key: ValueKey('inst-$_instId-$_yearName'),
          initialValue: _instId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _yearName.isEmpty ? s.t('institution') : '${s.t('institution')} · ${s.t('year_prefix')} $_yearName',
          ),
          items: [
            for (final i in _institutions)
              DropdownMenuItem(value: i.id, child: Text(i.displayName(s.isAr), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => _selectInstitution(v),
        ),
      );
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.s, required this.repo, required this.classes, this.initialClass, this.row});
  final S s;
  final StudentRepository repo;
  final List<SchoolClass> classes;
  final int? initialClass;
  final EnrolledStudent? row;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  late final Student? _st = widget.row?.student;
  late final _family = TextEditingController(text: _st?.familyNameFr);
  late final _given = TextEditingController(text: _st?.givenNameFr);
  late final _ar = TextEditingController(text: _st?.fullNameAr);
  late final _mat = TextEditingController(text: _st?.matricule);
  late final _gName = TextEditingController(text: _st?.guardianName);
  late final _gPhone = TextEditingController(text: _st?.guardianPhone);
  late String? _gender = _st?.gender;
  late int? _classId = widget.initialClass ?? (widget.classes.isEmpty ? null : widget.classes.first.id);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_family, _given, _ar, _mat, _gName, _gPhone]) {
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
      if (_st == null) {
        await widget.repo.addAndEnroll(
            classId: _classId!,
            matricule: _mat.text,
            familyNameFr: _family.text,
            givenNameFr: _given.text,
            fullNameAr: _ar.text,
            gender: _gender,
            guardianName: _gName.text,
            guardianPhone: _gPhone.text);
      } else {
        await widget.repo.update(_st.id,
            matricule: _mat.text,
            familyNameFr: _family.text,
            givenNameFr: _given.text,
            fullNameAr: _ar.text,
            gender: _gender,
            guardianName: _gName.text,
            guardianPhone: _gPhone.text);
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

  Widget _f(TextEditingController c, String label, {TextDirection? dir, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c, textDirection: dir, keyboardType: type, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t(_st == null ? 'add_student' : 'edit_student'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_st == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                initialValue: _classId,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.t('class_label')),
                items: [for (final c in widget.classes) DropdownMenuItem(value: c.id, child: Text(c.displayName(s.isAr)))],
                onChanged: (v) => setState(() => _classId = v),
              ),
            ),
          _f(_family, s.t('family_name'), dir: TextDirection.ltr),
          _f(_given, s.t('given_name'), dir: TextDirection.ltr),
          _f(_ar, s.t('full_name_ar'), dir: TextDirection.rtl),
          _f(_mat, s.t('matricule'), dir: TextDirection.ltr),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'M', label: Text(s.t('male'))),
                ButtonSegment(value: 'F', label: Text(s.t('female'))),
              ],
              selected: _gender == null ? <String>{} : {_gender!},
              onSelectionChanged: (v) => setState(() => _gender = v.isEmpty ? null : v.first),
            ),
          ),
          _f(_gName, s.t('guardian_name')),
          _f(_gPhone, s.t('guardian_phone'), dir: TextDirection.ltr, type: TextInputType.phone),
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
            Expanded(
                child: FilledButton(onPressed: (_busy || (_st == null && _classId == null)) ? null : _save, child: Text(s.t('save')))),
          ]),
        ]),
      ),
    );
  }
}

/// Moves a student to a class of any active institution. Same academic year →
/// a real transfer (old enrollment closed as `transferred`, history kept);
/// a later year → a new enrollment, the old one is left untouched.
class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.s,
    required this.db,
    required this.institutions,
    required this.row,
    required this.currentYearId,
    required this.school,
    required this.enroll,
  });
  final S s;
  final Database db;
  final List<Institution> institutions;
  final EnrolledStudent row;
  final int currentYearId;
  final SchoolRepository school;
  final EnrollmentRepository enroll;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  int? _instId;
  List<SchoolClass> _classes = const [];
  int? _classId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pick(widget.institutions.isEmpty ? null : widget.institutions.first.id);
  }

  Future<void> _pick(int? id) async {
    List<SchoolClass> classes = const [];
    if (id != null) {
      final y = await widget.school.activeYearId(id);
      if (y != null) classes = await widget.school.classesOf(id, y);
    }
    if (!mounted) return;
    setState(() {
      _instId = id;
      _classes = classes;
      _classId = null;
    });
  }

  Future<void> _go() async {
    final target = _classId;
    if (target == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final year = await widget.school.yearOfClass(target);
      if (year == widget.currentYearId) {
        await widget.enroll.transfer(studentId: widget.row.student.id, toClassId: target, reason: 'transfer');
      } else {
        await widget.enroll.enroll(studentId: widget.row.student.id, classId: target);
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
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.t('transfer_to'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _instId,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.t('institution')),
          items: [
            for (final i in widget.institutions)
              DropdownMenuItem(value: i.id, child: Text(i.displayName(s.isAr), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _pick,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('cls-$_instId'),
          initialValue: _classId,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.t('class_label')),
          items: [for (final c in _classes) DropdownMenuItem(value: c.id, child: Text(c.displayName(s.isAr)))],
          onChanged: (v) => setState(() => _classId = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(s.t('cancel')))),
          const SizedBox(width: 12),
          Expanded(
              child: FilledButton(onPressed: (_busy || _classId == null) ? null : _go, child: Text(s.t('transfer')))),
        ]),
      ]),
    );
  }
}
