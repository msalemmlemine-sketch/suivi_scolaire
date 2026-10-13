import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../models/school.dart';

/// Student files and the "enrolled students" listing. Enrollment changes
/// (transfer / end) go through EnrollmentRepository; here we only create the
/// first enrollment together with the student, in one transaction.
class StudentRepository {
  StudentRepository(this._db);
  final Database _db;

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, Object?> _values({
    String? matricule,
    String? familyNameFr,
    String? givenNameFr,
    String? fullNameAr,
    String? gender,
    String? guardianName,
    String? guardianPhone,
  }) {
    final fam = _clean(familyNameFr), giv = _clean(givenNameFr), ar = _clean(fullNameAr);
    if (fam == null && giv == null && ar == null) throw const AppException(ErrorCodes.requiredField);
    return {
      'matricule': _clean(matricule),
      'family_name_fr': fam,
      'given_name_fr': giv,
      'full_name_ar': ar,
      'gender': (gender == 'M' || gender == 'F') ? gender : null,
      'guardian_name': _clean(guardianName),
      'guardian_phone': _clean(guardianPhone),
    };
  }

  Future<List<EnrolledStudent>> listEnrolled({
    required int institutionId,
    required int yearId,
    int? classId,
    String? query,
  }) async {
    final where = StringBuffer("e.institution_id = ? AND e.academic_year_id = ? AND e.status = 'active'");
    final args = <Object?>[institutionId, yearId];
    if (classId != null) {
      where.write(' AND e.class_id = ?');
      args.add(classId);
    }
    final q = _clean(query);
    if (q != null) {
      where.write(' AND (s.family_name_fr LIKE ? OR s.given_name_fr LIKE ? OR s.full_name_ar LIKE ? OR s.matricule LIKE ?)');
      args.addAll(List.filled(4, '%$q%'));
    }
    final rows = await _db.rawQuery('''
      SELECT s.*, c.name_fr AS class_name, e.class_id AS class_id, e.id AS enrollment_id
      FROM enrollments e JOIN students s ON s.id = e.student_id JOIN classes c ON c.id = e.class_id
      WHERE $where
      ORDER BY coalesce(s.family_name_fr, s.full_name_ar, ''), coalesce(s.given_name_fr, ''), s.id''', args);
    return rows
        .map((r) => EnrolledStudent(
              student: Student.fromMap(r),
              enrollmentId: r['enrollment_id'] as int,
              classId: r['class_id'] as int,
              className: r['class_name'] as String,
            ))
        .toList();
  }

  /// Creates the student and enrolls them in [classId] atomically.
  Future<int> addAndEnroll({
    required int classId,
    String? matricule,
    String? familyNameFr,
    String? givenNameFr,
    String? fullNameAr,
    String? gender,
    String? guardianName,
    String? guardianPhone,
  }) {
    final v = _values(
        matricule: matricule,
        familyNameFr: familyNameFr,
        givenNameFr: givenNameFr,
        fullNameAr: fullNameAr,
        gender: gender,
        guardianName: guardianName,
        guardianPhone: guardianPhone);
    return _db.transaction((txn) async {
      final cls = await txn.query('classes', where: 'id = ?', whereArgs: [classId]);
      if (cls.isEmpty) throw const AppException(ErrorCodes.classNotFound);
      // Name exactly as typed, never rewritten later.
      v['full_name_original'] = v['full_name_ar'] ?? '${v['family_name_fr'] ?? ''} ${v['given_name_fr'] ?? ''}'.trim();
      final id = await txn.insert('students', v);
      await txn.insert('enrollments', {
        'student_id': id,
        'institution_id': cls.first['institution_id'],
        'academic_year_id': cls.first['academic_year_id'],
        'class_id': classId,
        'status': 'active',
        'start_date': DateTime.now().toIso8601String().substring(0, 10),
      });
      return id;
    });
  }

  Future<void> update(
    int id, {
    String? matricule,
    String? familyNameFr,
    String? givenNameFr,
    String? fullNameAr,
    String? gender,
    String? guardianName,
    String? guardianPhone,
  }) async {
    await _db.update(
        'students',
        _values(
            matricule: matricule,
            familyNameFr: familyNameFr,
            givenNameFr: givenNameFr,
            fullNameAr: fullNameAr,
            gender: gender,
            guardianName: guardianName,
            guardianPhone: guardianPhone),
        where: 'id = ?',
        whereArgs: [id]);
  }
}
