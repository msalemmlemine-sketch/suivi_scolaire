import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../models/school.dart';

/// Academic years (per institution) and classes. Nothing is deleted:
/// classes are archived so enrollments and grades stay intact.
class SchoolRepository {
  SchoolRepository(this._db);
  final Database _db;

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  Future<List<YearLink>> yearsOf(int institutionId) async {
    final rows = await _db.rawQuery('''
      SELECT y.id, y.name, y.start_date, y.end_date, l.is_active
      FROM institution_academic_years l JOIN academic_years y ON y.id = l.academic_year_id
      WHERE l.institution_id = ? ORDER BY y.start_date DESC, y.id DESC''', [institutionId]);
    return rows
        .map((r) => YearLink(
              id: r['id'] as int,
              name: r['name'] as String,
              startDate: r['start_date'] as String,
              endDate: r['end_date'] as String,
              isActive: (r['is_active'] as int) == 1,
            ))
        .toList();
  }

  Future<int?> activeYearId(int institutionId) async {
    final r = await _db.query('institution_academic_years',
        columns: ['academic_year_id'],
        where: 'institution_id = ? AND is_active = 1',
        whereArgs: [institutionId]);
    return r.isEmpty ? null : r.first['academic_year_id'] as int;
  }

  /// Links a year (created if its name is new) to the institution.
  /// It becomes active only if the institution has no active year yet.
  Future<int> addYear(int institutionId, {required String name, required String startDate, required String endDate}) async {
    final n = _clean(name), s = _clean(startDate), e = _clean(endDate);
    if (n == null || s == null || e == null) throw const AppException(ErrorCodes.requiredField);
    if (!_date.hasMatch(s) || !_date.hasMatch(e) || e.compareTo(s) <= 0) {
      throw const AppException(ErrorCodes.invalidDates);
    }
    return _db.transaction((txn) async {
      final found = await txn.query('academic_years', columns: ['id'], where: 'name = ?', whereArgs: [n]);
      final yearId = found.isNotEmpty
          ? found.first['id'] as int
          : await txn.insert('academic_years', {'name': n, 'start_date': s, 'end_date': e});
      final hasActive = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM institution_academic_years WHERE institution_id = ? AND is_active = 1',
              [institutionId])) ??
          0;
      await txn.insert(
          'institution_academic_years',
          {'institution_id': institutionId, 'academic_year_id': yearId, 'is_active': hasActive == 0 ? 1 : 0},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return yearId;
    });
  }

  Future<void> setActiveYear(int institutionId, int yearId) => _db.transaction((txn) async {
        await txn.update('institution_academic_years', {'is_active': 0},
            where: 'institution_id = ?', whereArgs: [institutionId]);
        await txn.update('institution_academic_years', {'is_active': 1},
            where: 'institution_id = ? AND academic_year_id = ?', whereArgs: [institutionId, yearId]);
      });

  Future<List<SchoolClass>> classesOf(int institutionId, int yearId, {bool archived = false}) async {
    final rows = await _db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM enrollments e WHERE e.class_id = c.id AND e.status = 'active') AS student_count
      FROM classes c WHERE c.institution_id = ? AND c.academic_year_id = ? AND c.status = ?
      ORDER BY c.name_fr''', [institutionId, yearId, archived ? 'archived' : 'active']);
    return rows.map(SchoolClass.fromMap).toList();
  }

  Future<int> addClass(int institutionId, int yearId, {required String nameFr, String? nameAr, String? level}) async {
    final fr = _clean(nameFr);
    if (fr == null) throw const AppException(ErrorCodes.requiredField);
    try {
      return await _db.insert('classes', {
        'institution_id': institutionId,
        'academic_year_id': yearId,
        'name_fr': fr,
        'name_ar': _clean(nameAr),
        'level': _clean(level),
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) throw const AppException(ErrorCodes.classExists);
      rethrow;
    }
  }

  Future<void> updateClass(int id, {required String nameFr, String? nameAr, String? level}) async {
    final fr = _clean(nameFr);
    if (fr == null) throw const AppException(ErrorCodes.requiredField);
    try {
      await _db.update('classes', {'name_fr': fr, 'name_ar': _clean(nameAr), 'level': _clean(level)},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) throw const AppException(ErrorCodes.classExists);
      rethrow;
    }
  }

  Future<void> setClassArchived(int id, bool archived) async {
    await _db.update('classes', {'status': archived ? 'archived' : 'active'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> yearOfClass(int classId) async {
    final r = await _db.query('classes', columns: ['academic_year_id'], where: 'id = ?', whereArgs: [classId]);
    return r.isEmpty ? null : r.first['academic_year_id'] as int;
  }
}
