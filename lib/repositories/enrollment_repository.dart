import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../models/enrollment.dart';

/// All enrollment writes go through here. The "one active enrollment per
/// student per academic year" rule is enforced by the database
/// (partial unique index `ux_one_active_enrollment`); this layer only
/// translates failures into [AppException] codes.
class EnrollmentRepository {
  EnrollmentRepository(this._db);
  final Database _db;

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<Enrollment?> activeFor(int studentId, int academicYearId) async {
    final r = await _db.query('enrollments',
        where: "student_id = ? AND academic_year_id = ? AND status = 'active'",
        whereArgs: [studentId, academicYearId]);
    return r.isEmpty ? null : Enrollment.fromMap(r.first);
  }

  /// History of a student, newest first (never deleted).
  Future<List<Enrollment>> historyOf(int studentId) async {
    final r = await _db.query('enrollments',
        where: 'student_id = ?', whereArgs: [studentId], orderBy: 'start_date DESC, id DESC');
    return r.map(Enrollment.fromMap).toList();
  }

  Future<Enrollment> enroll({required int studentId, required int classId, String? startDate}) =>
      _guard(() => _db.transaction((txn) => _insert(txn, studentId, classId, startDate ?? _today())));

  /// Move a student to another class, in the same or another institution.
  /// The target class's academic year decides which active enrollment is
  /// replaced: that one is closed as `transferred` and the new one opened,
  /// both in one transaction. Any failure rolls everything back.
  Future<Enrollment> transfer({
    required int studentId,
    required int toClassId,
    String? date,
    String? reason,
  }) =>
      _guard(() => _db.transaction((txn) async {
            final day = date ?? _today();
            final cls = await txn.query('classes', columns: ['academic_year_id'], where: 'id = ?', whereArgs: [toClassId]);
            if (cls.isEmpty) throw const AppException(ErrorCodes.classNotFound);
            final year = cls.first['academic_year_id'] as int;
            final cur = await txn.query('enrollments',
                where: "student_id = ? AND academic_year_id = ? AND status = 'active'",
                whereArgs: [studentId, year]);
            if (cur.isEmpty) throw const AppException(ErrorCodes.notActive);
            if (cur.first['class_id'] == toClassId) return Enrollment.fromMap(cur.first); // no-op
            await txn.update(
              'enrollments',
              {'status': 'transferred', 'end_date': day, 'end_reason': reason ?? 'transfer'},
              where: 'id = ?',
              whereArgs: [cur.first['id']],
            );
            return _insert(txn, studentId, toClassId, day);
          }));

  /// Close an enrollment without deleting anything.
  Future<void> end(int enrollmentId, {String? date, String? reason, bool archive = false}) async {
    final n = await _db.update(
      'enrollments',
      {'status': archive ? 'archived' : 'ended', 'end_date': date ?? _today(), 'end_reason': reason},
      where: "id = ? AND status = 'active'",
      whereArgs: [enrollmentId],
    );
    if (n == 0) throw const AppException(ErrorCodes.notActive);
  }

  Future<Enrollment> _insert(DatabaseExecutor ex, int studentId, int classId, String start) async {
    final cls = await ex.query('classes', where: 'id = ?', whereArgs: [classId]);
    if (cls.isEmpty) throw const AppException(ErrorCodes.classNotFound);
    final id = await ex.insert('enrollments', {
      'student_id': studentId,
      'institution_id': cls.first['institution_id'],
      'academic_year_id': cls.first['academic_year_id'],
      'class_id': classId,
      'status': 'active',
      'start_date': start,
    });
    return Enrollment.fromMap((await ex.query('enrollments', where: 'id = ?', whereArgs: [id])).first);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on DatabaseException catch (e) {
      final m = e.toString();
      if (m.contains('ux_one_active_enrollment') || m.contains('enrollments.student_id')) {
        throw const AppException(ErrorCodes.studentAlreadyActive);
      }
      if (m.contains('FOREIGN KEY')) throw const AppException(ErrorCodes.classMismatch);
      throw AppException(ErrorCodes.unknown, m);
    }
  }
}
