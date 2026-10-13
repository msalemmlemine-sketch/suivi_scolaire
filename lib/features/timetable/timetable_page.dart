import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../repositories/timetable_repository.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.db, required this.s});
  final Database db;
  final S s;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> with SingleTickerProviderStateMixin {
  late final TimetableRepository _repo = TimetableRepository(widget.db);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  List<Map<String, Object?>> _classes = [];
  int? _classId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final classes = await _repo.activeClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        if (_classId == null || !classes.any((c) => c['id'] == _classId)) {
          _classId = classes.isEmpty ? null : classes.first['id'] as int;
        }
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = widget.s.t('load_failed'); });
    }
  }

  String _name(Map<String, Object?> row, String arKey, String frKey) {
    final preferred = row[widget.s.isAr ? arKey : frKey] as String?;
    final fallback = row[widget.s.isAr ? frKey : arKey] as String?;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return fallback?.trim() ?? '';
  }

  String _classLabel(Map<String, Object?> row) {
    final institution = _name(row, 'institution_name_ar', 'institution_name_fr');
    final cls = _name(row, 'name_ar', 'name_fr');
    final year = row['year_name'] as String? ?? '';
    return [institution, cls, year].where((x) => x.trim().isNotEmpty).join(' • ');
  }

  String _subjectLabel(Map<String, Object?> row) => _name(row, 'subject_name_ar', 'subject_name_fr');

  String _day(int day) {
    const ar = ['','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const fr = ['','Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    return widget.s.isAr ? ar[day] : fr[day];
  }

  void _message(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t(key))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_classes.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_month_outlined, size: 48),
        const SizedBox(height: 12),
        Text(widget.s.t('timetable_no_classes'), textAlign: TextAlign.center),
      ]),
    ));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: DropdownButtonFormField<int>(
          value: _classId,
          isExpanded: true,
          decoration: InputDecoration(labelText: widget.s.t('class'), prefixIcon: const Icon(Icons.school_outlined)),
          items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(_classLabel(c), maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() => _classId = value),
        ),
      ),
      TabBar(controller: _tabs, tabs: [
        Tab(icon: const Icon(Icons.calendar_view_week_outlined), text: widget.s.t('timetable_tab_schedule')),
        Tab(icon: const Icon(Icons.menu_book_outlined), text: widget.s.t('timetable_tab_sessions')),
        Tab(icon: const Icon(Icons.fact_check_outlined), text: widget.s.t('timetable_tab_attendance')),
      ]),
      Expanded(child: TabBarView(controller: _tabs, children: [
        _ScheduleTab(repo: _repo, s: widget.s, classId: _classId!, name: _name, day: _day, onRefresh: () => setState(() {}), onError: _message),
        _SessionsTab(repo: _repo, s: widget.s, classId: _classId!, name: _name, subjectLabel: _subjectLabel, onRefresh: () => setState(() {}), onError: _message, onAttendance: (session) { _tabs.animateTo(2); _showAttendance(session); }),
        _AttendanceTab(repo: _repo, s: widget.s, classId: _classId!, name: _name, subjectLabel: _subjectLabel, onOpen: _showAttendance),
      ])),
    ]);
  }

  Future<void> _showAttendance(Map<String, Object?> session) async {
    await showDialog<void>(context: context, builder: (dialogContext) => _AttendanceDialog(
      repo: _repo, s: widget.s, session: session, name: _name, subjectLabel: _subjectLabel,
    ));
    if (mounted) setState(() {});
  }
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({required this.repo, required this.s, required this.classId, required this.name, required this.day, required this.onRefresh, required this.onError});
  final TimetableRepository repo;
  final S s;
  final int classId;
  final String Function(Map<String, Object?>, String, String) name;
  final String Function(int) day;
  final VoidCallback onRefresh;
  final ValueChanged<String> onError;
  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant _ScheduleTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.classId != widget.classId) _reload(); }
  void _reload() { _future = widget.repo.entriesForClass(widget.classId); }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final rows = snap.data ?? [];
      return Stack(children: [
        rows.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(widget.s.t('timetable_empty'), textAlign: TextAlign.center))) : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88), itemCount: rows.length,
          itemBuilder: (context, index) {
            final r = rows[index];
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text('${r['day_of_week']}')),
              title: Text(widget.name(r, 'subject_name_ar', 'subject_name_fr')),
              subtitle: Text('${widget.day(r['day_of_week'] as int)} • ${r['start_time']}–${r['end_time']}${(r['room'] as String?)?.isNotEmpty == true ? ' • ${r['room']}' : ''}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: widget.s.t('timetable_deactivate'), onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: Text(widget.s.t('timetable_deactivate')),
                  content: Text(widget.s.t('timetable_deactivate_hint')),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('confirm')))],
                ));
                if (confirm == true) { try { await widget.repo.deactivateEntry(r['id'] as int); if (mounted) setState(_reload); } catch (_) { widget.onError('save_failed'); } }
              }),
            ));
          },
        ),
        Positioned(right: 16, bottom: 16, child: FloatingActionButton.extended(onPressed: _addEntry, icon: const Icon(Icons.add), label: Text(widget.s.t('timetable_add_slot')))),
      ]);
    },
  );

  Future<void> _addEntry() async {
    var subjects = await widget.repo.subjects();
    if (!mounted) return;
    final ar = TextEditingController(); final fr = TextEditingController(); final code = TextEditingController();
    int? subjectId = subjects.isEmpty ? null : subjects.first['id'] as int;
    var day = 1; var start = '08:00'; var end = '09:00';
    final room = TextEditingController(); final notes = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text(widget.s.t('timetable_add_slot')),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (subjects.isNotEmpty) DropdownButtonFormField<int>(value: subjectId, isExpanded: true, decoration: InputDecoration(labelText: widget.s.t('subject')), items: subjects.map((r) => DropdownMenuItem(value: r['id'] as int, child: Text(_subjectName(r)))).toList(), onChanged: (v) => setDialog(() => subjectId = v)),
        if (subjects.isEmpty) Text(widget.s.t('timetable_no_subjects')),
        TextField(controller: fr, decoration: InputDecoration(labelText: widget.s.t('subject_name_fr'))),
        TextField(controller: ar, decoration: InputDecoration(labelText: widget.s.t('subject_name_ar'))),
        TextField(controller: code, decoration: InputDecoration(labelText: widget.s.t('subject_code'))),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(value: day, decoration: InputDecoration(labelText: widget.s.t('weekday')), items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(widget.day(i + 1)))), onChanged: (v) => setDialog(() => day = v ?? 1)),
        TextFormField(initialValue: start, decoration: InputDecoration(labelText: widget.s.t('start_time'), hintText: '08:00'), onChanged: (v) => start = v.trim()),
        TextFormField(initialValue: end, decoration: InputDecoration(labelText: widget.s.t('end_time'), hintText: '09:00'), onChanged: (v) => end = v.trim()),
        TextField(controller: room, decoration: InputDecoration(labelText: widget.s.t('room_optional'))),
        TextField(controller: notes, decoration: InputDecoration(labelText: widget.s.t('notes_optional'))),
        const SizedBox(height: 6), Text(widget.s.t('time_format_hint'), style: Theme.of(context).textTheme.bodySmall),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.s.t('save')))],
    )));
    if (result != true) return;
    try {
      if (subjectId == null) {
        subjectId = await widget.repo.saveSubject(nameAr: ar.text, nameFr: fr.text, code: code.text);
      } else if (ar.text.trim().isNotEmpty || fr.text.trim().isNotEmpty) {
        // An explicitly entered new subject is saved separately; existing subjects are not overwritten.
        subjectId = await widget.repo.saveSubject(nameAr: ar.text, nameFr: fr.text, code: code.text);
      }
      if (subjectId == null) throw ArgumentError('subject_name_required');
      await widget.repo.saveEntry(classId: widget.classId, subjectId: subjectId!, dayOfWeek: day, startTime: start, endTime: end, room: room.text, notes: notes.text);
      if (mounted) setState(_reload);
    } catch (_) { widget.onError('timetable_save_error'); }
  }

  String _subjectName(Map<String, Object?> r) {
    final preferred = r[widget.s.isAr ? 'name_ar' : 'name_fr'] as String?;
    final fallback = r[widget.s.isAr ? 'name_fr' : 'name_ar'] as String?;
    return (preferred?.trim().isNotEmpty == true ? preferred : fallback) ?? '';
  }
}

class _SessionsTab extends StatefulWidget {
  const _SessionsTab({required this.repo, required this.s, required this.classId, required this.name, required this.subjectLabel, required this.onRefresh, required this.onError, required this.onAttendance});
  final TimetableRepository repo; final S s; final int classId;
  final String Function(Map<String, Object?>, String, String) name;
  final String Function(Map<String, Object?>) subjectLabel;
  final VoidCallback onRefresh; final ValueChanged<String> onError;
  final ValueChanged<Map<String, Object?>> onAttendance;
  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant _SessionsTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.classId != widget.classId) _reload(); }
  void _reload() { _future = widget.repo.sessionsForClass(widget.classId); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    final rows = snap.data ?? [];
    return Stack(children: [
      rows.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(widget.s.t('sessions_empty'), textAlign: TextAlign.center))) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 8, 12, 88), itemCount: rows.length, itemBuilder: (context, index) {
        final r = rows[index]; final status = r['status'] as String;
        return Card(child: ListTile(
          leading: Icon(status == 'done' ? Icons.task_alt : status == 'cancelled' ? Icons.event_busy : Icons.event_note_outlined),
          title: Text(widget.name(r, 'subject_name_ar', 'subject_name_fr')),
          subtitle: Text('${r['session_date']} • ${r['actual_start'] ?? '--:--'}–${r['actual_end'] ?? '--:--'} • ${_status(status)}'),
          onTap: () => _editSession(r),
          trailing: IconButton(tooltip: widget.s.t('attendance_title'), icon: const Icon(Icons.fact_check_outlined), onPressed: status == 'cancelled' ? null : () => widget.onAttendance(r)),
        ));
      }),
      Positioned(right: 16, bottom: 16, child: FloatingActionButton.extended(onPressed: _createSession, icon: const Icon(Icons.add), label: Text(widget.s.t('session_create')))),
    ]);
  });

  String _status(String value) {
    switch (value) {
      case 'done': return widget.s.t('session_status_done');
      case 'cancelled': return widget.s.t('session_status_cancelled');
      case 'made_up': return widget.s.t('session_status_made_up');
      default: return widget.s.t('session_status_scheduled');
    }
  }

  Future<void> _createSession() async {
    final entries = await widget.repo.entriesForClass(widget.classId);
    if (!mounted) return;
    if (entries.isEmpty) { widget.onError('timetable_empty_first'); return; }
    int entryId = entries.first['id'] as int;
    var date = DateTime.now().toIso8601String().substring(0, 10);
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text(widget.s.t('session_create')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: entryId, isExpanded: true, decoration: InputDecoration(labelText: widget.s.t('timetable_entry')), items: entries.map((e) => DropdownMenuItem(value: e['id'] as int, child: Text('${widget.name(e, 'subject_name_ar', 'subject_name_fr')} • ${e['start_time']}–${e['end_time']}'))).toList(), onChanged: (v) => setDialog(() => entryId = v ?? entryId)),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(widget.s.t('session_date')), subtitle: Text(date), trailing: const Icon(Icons.calendar_month), onTap: () async { final now = DateTime.tryParse(date) ?? DateTime.now(); final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setDialog(() => date = picked.toIso8601String().substring(0, 10)); }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.s.t('save'))],
    )));
    if (ok != true) return;
    try { await widget.repo.createSessionFromEntry(timetableEntryId: entryId, date: date); if (mounted) setState(_reload); }
    catch (_) { widget.onError('session_create_error'); }
  }

  Future<void> _editSession(Map<String, Object?> row) async {
    var status = row['status'] as String;
    final topic = TextEditingController(text: row['topic'] as String? ?? '');
    final notes = TextEditingController(text: row['notes'] as String? ?? '');
    final start = TextEditingController(text: row['actual_start'] as String? ?? '');
    final end = TextEditingController(text: row['actual_end'] as String? ?? '');
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text(widget.s.t('session_edit')),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: status, decoration: InputDecoration(labelText: widget.s.t('session_status')), items: ['scheduled','done','cancelled','made_up'].map((v) => DropdownMenuItem(value: v, child: Text(_status(v)))).toList(), onChanged: (v) => setDialog(() => status = v ?? status)),
        TextField(controller: topic, decoration: InputDecoration(labelText: widget.s.t('lesson_topic'))),
        TextField(controller: start, decoration: InputDecoration(labelText: widget.s.t('start_time'))),
        TextField(controller: end, decoration: InputDecoration(labelText: widget.s.t('end_time'))),
        TextField(controller: notes, decoration: InputDecoration(labelText: widget.s.t('notes_optional')), maxLines: 2),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.s.t('save'))],
    )));
    if (ok != true) return;
    try { await widget.repo.updateSession(row['id'] as int, status: status, topic: topic.text, notes: notes.text, actualStart: start.text, actualEnd: end.text); if (mounted) setState(_reload); }
    catch (_) { widget.onError('session_save_error'); }
  }
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.repo, required this.s, required this.classId, required this.name, required this.subjectLabel, required this.onOpen});
  final TimetableRepository repo; final S s; final int classId;
  final String Function(Map<String, Object?>, String, String) name;
  final String Function(Map<String, Object?>) subjectLabel;
  final ValueChanged<Map<String, Object?>> onOpen;
  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  late Future<List<Map<String, Object?>>> _future;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant _AttendanceTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.classId != widget.classId) _reload(); }
  void _reload() { _future = widget.repo.sessionsForClass(widget.classId); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(future: _future, builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    final rows = (snap.data ?? []).where((r) => r['status'] != 'cancelled').toList();
    return rows.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(widget.s.t('attendance_no_sessions'), textAlign: TextAlign.center))) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) {
      final r = rows[i];
      return Card(child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(widget.name(r, 'subject_name_ar', 'subject_name_fr')),
        subtitle: Text('${r['session_date']} • ${_status(r['status'] as String)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async { widget.onOpen(r); if (mounted) setState(_reload); },
      ));
    });
  });
  String _status(String v) {
    switch (v) {
      case 'done': return widget.s.t('session_status_done');
      case 'cancelled': return widget.s.t('session_status_cancelled');
      case 'made_up': return widget.s.t('session_status_made_up');
      default: return widget.s.t('session_status_scheduled');
    }
  }
}

class _AttendanceDialog extends StatefulWidget {
  const _AttendanceDialog({required this.repo, required this.s, required this.session, required this.name, required this.subjectLabel});
  final TimetableRepository repo; final S s; final Map<String, Object?> session;
  final String Function(Map<String, Object?>, String, String) name;
  final String Function(Map<String, Object?>) subjectLabel;
  @override
  State<_AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<_AttendanceDialog> {
  late Future<List<Map<String, Object?>>> _roster;
  List<Map<String, Object?>> _statuses = [];
  bool _saving = false;
  @override
  void initState() { super.initState(); _roster = widget.repo.attendanceRoster(widget.session['id'] as int); _loadStatuses(); }
  Future<void> _loadStatuses() async { final rows = await widget.repo.attendanceStatuses(); if (mounted) setState(() => _statuses = rows); }
  String _studentName(Map<String, Object?> row) {
    final fr = [row['family_name_fr'], row['given_name_fr']].whereType<String>().map((v) => v.trim()).where((v) => v.isNotEmpty).join(' ');
    final ar = (row['full_name_ar'] as String?)?.trim() ?? '';
    final original = (row['full_name_original'] as String?)?.trim() ?? '';
    return widget.s.isAr ? (ar.isNotEmpty ? ar : original.isNotEmpty ? original : fr) : (fr.isNotEmpty ? fr : original.isNotEmpty ? original : ar);
  }
  String _statusLabel(Map<String, Object?> row) {
    final key = widget.s.isAr ? 'label_ar' : 'label_fr';
    return row[key] as String? ?? row['code'] as String;
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.s.t('attendance_title')} • ${widget.session['session_date']}'),
    content: SizedBox(width: 560, height: MediaQuery.of(context).size.height * .65, child: FutureBuilder<List<Map<String, Object?>>>(future: _roster, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done || _statuses.isEmpty) return const Center(child: CircularProgressIndicator());
      final rows = snap.data ?? [];
      if (rows.isEmpty) return Center(child: Text(widget.s.t('attendance_empty_roster')));
      return ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) {
        final row = rows[index];
        final current = row['status_code'] as String?;
        final selected = _statuses.any((s) => s['code'] == current) ? current : 'present';
        return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_studentName(row), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(value: selected, isExpanded: true, decoration: InputDecoration(labelText: widget.s.t('attendance_status')), items: _statuses.map((s) => DropdownMenuItem<String>(value: s['code'] as String, child: Text(_statusLabel(s)))).toList(), onChanged: _saving ? null : (v) async {
            if (v == null) return;
            setState(() => _saving = true);
            try {
              await widget.repo.saveAttendance(sessionId: widget.session['id'] as int, enrollmentId: row['enrollment_id'] as int, classId: widget.session['class_id'] as int, statusCode: v, lateMinutes: v == 'late' ? 5 : null);
              _roster = widget.repo.attendanceRoster(widget.session['id'] as int);
            } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('attendance_save_error')))); }
            if (mounted) setState(() => _saving = false);
          }),
        ]));
      });
    })),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.s.t('close'))],
  );
}
