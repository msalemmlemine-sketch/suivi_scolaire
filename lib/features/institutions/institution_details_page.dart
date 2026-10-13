import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';

class InstitutionDetailsPage extends StatefulWidget {
  const InstitutionDetailsPage({super.key, required this.db, required this.s, required this.institution});
  final Database db;
  final S s;
  final Map<String, Object?> institution;

  @override
  State<InstitutionDetailsPage> createState() => _InstitutionDetailsPageState();
}

class _InstitutionDetailsPageState extends State<InstitutionDetailsPage> {
  int? _yearId;
  late Future<List<Map<String, Object?>>> _years;
  late Future<List<Map<String, Object?>>> _classes;

  int get _institutionId => widget.institution['id'] as int;

  @override
  void initState() {
    super.initState();
    _refreshYears();
  }

  void _refreshYears() {
    _years = widget.db.rawQuery('''
      SELECT y.*, iy.is_active AS institution_active
      FROM institution_academic_years iy JOIN academic_years y ON y.id = iy.academic_year_id
      WHERE iy.institution_id = ? ORDER BY y.start_date DESC
    ''', [_institutionId]);
    _classes = _loadClasses();
  }

  Future<List<Map<String, Object?>>> _loadClasses() async {
    if (_yearId == null) return [];
    return widget.db.query('classes', where: 'institution_id = ? AND academic_year_id = ?',
        whereArgs: [_institutionId, _yearId], orderBy: 'status, name_fr');
  }

  Future<void> _reload() async {
    setState(_refreshYears);
    await _years;
    await _classes;
  }

  String _institutionName() {
    final ar = widget.institution['name_ar'] as String?;
    final fr = widget.institution['name_fr'] as String?;
    return widget.s.isAr ? ((ar?.trim().isNotEmpty == true) ? ar! : fr ?? '') : ((fr?.trim().isNotEmpty == true) ? fr! : ar ?? '');
  }

  Future<void> _addYear() async {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    final name = TextEditingController(text: '$startYear-${startYear + 1}');
    final start = TextEditingController(text: '$startYear-09-01');
    final end = TextEditingController(text: '${startYear + 1}-06-30');
    bool makeActive = true;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setDialog) => AlertDialog(
      title: Text(widget.s.t('year_add')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: InputDecoration(labelText: widget.s.t('year_name'))),
        const SizedBox(height: 10),
        TextField(controller: start, decoration: InputDecoration(labelText: widget.s.t('start_date')), keyboardType: TextInputType.datetime),
        const SizedBox(height: 10),
        TextField(controller: end, decoration: InputDecoration(labelText: widget.s.t('end_date')), keyboardType: TextInputType.datetime),
        const SizedBox(height: 6),
        CheckboxListTile(value: makeActive, contentPadding: EdgeInsets.zero, title: Text(widget.s.t('set_active_year')), onChanged: (v) => setDialog(() => makeActive = v ?? false)),
        Text(widget.s.t('date_format_hint'), style: Theme.of(context).textTheme.bodySmall),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('save')))],
    )));
    if (ok != true) { name.dispose(); start.dispose(); end.dispose(); return; }
    try {
      final yearName = name.text.trim();
      final startDate = start.text.trim();
      final endDate = end.text.trim();
      if (yearName.isEmpty || !_validDate(startDate) || !_validDate(endDate) || endDate <= startDate) throw const FormatException();
      await widget.db.transaction((txn) async {
        int yearId;
        final existing = await txn.query('academic_years', where: 'name = ?', whereArgs: [yearName]);
        if (existing.isNotEmpty) {
          yearId = existing.first['id'] as int;
          final association = await txn.query('institution_academic_years', where: 'institution_id = ? AND academic_year_id = ?', whereArgs: [_institutionId, yearId]);
          if (association.isEmpty) await txn.insert('institution_academic_years', {'institution_id': _institutionId, 'academic_year_id': yearId, 'is_active': 0});
        } else {
          yearId = await txn.insert('academic_years', {'name': yearName, 'start_date': startDate, 'end_date': endDate, 'status': 'current'});
          await txn.insert('institution_academic_years', {'institution_id': _institutionId, 'academic_year_id': yearId, 'is_active': 0});
        }
        if (makeActive) {
          await txn.update('institution_academic_years', {'is_active': 0}, where: 'institution_id = ?', whereArgs: [_institutionId]);
          await txn.update('institution_academic_years', {'is_active': 1}, where: 'institution_id = ? AND academic_year_id = ?', whereArgs: [_institutionId, yearId]);
        }
        _yearId = yearId;
      });
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('year_save_error'))));
    } finally { name.dispose(); start.dispose(); end.dispose(); }
  }

  bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  Future<void> _activateYear(int yearId) async {
    await widget.db.transaction((txn) async {
      await txn.update('institution_academic_years', {'is_active': 0}, where: 'institution_id = ?', whereArgs: [_institutionId]);
      await txn.update('institution_academic_years', {'is_active': 1}, where: 'institution_id = ? AND academic_year_id = ?', whereArgs: [_institutionId, yearId]);
    });
    _yearId = yearId;
    await _reload();
  }

  Future<void> _addClass() async {
    if (_yearId == null) return;
    final fr = TextEditingController();
    final ar = TextEditingController();
    final level = TextEditingController();
    final track = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(widget.s.t('class_add')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: fr, decoration: InputDecoration(labelText: widget.s.t('class_name_fr'))),
        const SizedBox(height: 10), TextField(controller: ar, decoration: InputDecoration(labelText: widget.s.t('class_name_ar'))),
        const SizedBox(height: 10), TextField(controller: level, decoration: InputDecoration(labelText: widget.s.t('class_level'))),
        const SizedBox(height: 10), TextField(controller: track, decoration: InputDecoration(labelText: widget.s.t('class_track'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(widget.s.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(widget.s.t('save')))],
    ));
    if (ok == true) {
      try {
        if (fr.text.trim().isEmpty) throw const FormatException();
        await widget.db.insert('classes', {'institution_id': _institutionId, 'academic_year_id': _yearId, 'name_fr': fr.text.trim(), 'name_ar': ar.text.trim().isEmpty ? null : ar.text.trim(), 'level': level.text.trim().isEmpty ? null : level.text.trim(), 'track': track.text.trim().isEmpty ? null : track.text.trim(), 'status': 'active'});
        if (mounted) await _reload();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.s.t('class_save_error'))));
      }
    }
    fr.dispose(); ar.dispose(); level.dispose(); track.dispose();
  }

  Future<void> _toggleClass(Map<String, Object?> row) async {
    final archived = row['status'] == 'archived';
    await widget.db.update('classes', {'status': archived ? 'active' : 'archived'}, where: 'id = ?', whereArgs: [row['id']]);
    if (mounted) await _reload();
  }

  String _className(Map<String, Object?> row) {
    final ar = row['name_ar'] as String?;
    final fr = row['name_fr'] as String?;
    return widget.s.isAr ? ((ar?.trim().isNotEmpty == true) ? ar! : fr ?? '') : ((fr?.trim().isNotEmpty == true) ? fr! : ar ?? '');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_institutionName())),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text(widget.s.t('academic_years'), style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: _addYear, tooltip: widget.s.t('year_add'), icon: const Icon(Icons.add_circle_outline))]),
      FutureBuilder<List<Map<String, Object?>>>(future: _years, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        final rows = snap.data ?? [];
        if (rows.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(widget.s.t('year_empty'))));
        return Column(children: rows.map((y) {
          final id = y['id'] as int;
          final active = y['institution_active'] == 1;
          return Card(child: ListTile(
            leading: Icon(active ? Icons.check_circle : Icons.calendar_month, color: active ? AppColors.success : AppColors.muted),
            title: Text(y['name'] as String),
            subtitle: Text('${y['start_date']} — ${y['end_date']}'),
            trailing: active ? Chip(label: Text(widget.s.t('active'))) : TextButton(onPressed: () => _activateYear(id), child: Text(widget.s.t('activate'))),
            onTap: () => setState(() { _yearId = id; _classes = _loadClasses(); }),
          ));
        }).toList());
      }),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: Text(widget.s.t('classes_for_year'), style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: _yearId == null ? null : _addClass, tooltip: widget.s.t('class_add'), icon: const Icon(Icons.add_circle_outline))]),
      if (_yearId == null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(widget.s.t('select_year_hint'))))
      else FutureBuilder<List<Map<String, Object?>>>(future: _classes, builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        final rows = snap.data ?? [];
        if (rows.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(widget.s.t('class_empty'))));
        return Column(children: rows.map((row) {
          final archived = row['status'] == 'archived';
          return Card(child: ListTile(
            leading: const Icon(Icons.groups_outlined, color: AppColors.teal),
            title: Text(_className(row)),
            subtitle: Text([row['level'], row['track']].whereType<String>().where((x) => x.trim().isNotEmpty).join(' • ')),
            trailing: PopupMenuButton<String>(onSelected: (_) => _toggleClass(row), itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(archived ? widget.s.t('restore') : widget.s.t('archive')))]),
          ));
        }).toList());
      }),
    ]),
  );
}
