import 'package:sqflite/sqflite.dart';

class StudentRepository {
  StudentRepository(this._db);
  final Database _db;

  Future<List<Map<String, Object?>>> activeStudents({String search = ''}) async {
    final q = search.trim();
    return _db.rawQuery('''
      SELECT s.*, e.id AS enrollment_id, e.start_date, c.id AS class_id,
             c.name_ar AS class_name_ar, c.name_fr AS class_name_fr,
             i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr,
             y.name AS year_name
      FROM enrollments e
      JOIN students s ON s.id = e.student_id
      JOIN classes c ON c.id = e.class_id
      JOIN institutions i ON i.id = e.institution_id
      JOIN academic_years y ON y.id = e.academic_year_id
      WHERE e.status = 'active' AND i.status = 'active' AND c.status = 'active'
        AND (? = '' OR s.full_name_original LIKE ? OR s.full_name_ar LIKE ?
             OR s.family_name_fr LIKE ? OR s.given_name_fr LIKE ? OR s.matricule LIKE ?)
      ORDER BY COALESCE(NULLIF(s.family_name_fr,''), NULLIF(s.full_name_ar,''), s.full_name_original), s.given_name_fr
    ''', [q, '%$q%', '%$q%', '%$q%', '%$q%', '%$q%']);
  }

  Future<List<Map<String, Object?>>> availableClasses() => _db.rawQuery('''
    SELECT c.id, c.name_ar, c.name_fr, c.level, c.track, y.name AS year_name,
           i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr
    FROM classes c
    JOIN institutions i ON i.id = c.institution_id
    JOIN academic_years y ON y.id = c.academic_year_id
    JOIN institution_academic_years iy ON iy.institution_id = i.id AND iy.academic_year_id = y.id
    WHERE c.status = 'active' AND i.status = 'active' AND iy.is_active = 1
    ORDER BY i.id, c.name_fr
  ''');

  Future<int> createAndEnroll({
    required int classId,
    required String originalName,
    String? familyNameFr,
    String? givenNameFr,
    String? fullNameAr,
    String? gender,
    String? birthDate,
    String? guardianName,
    String? guardianPhone,
    String? matricule,
    String? notes,
  }) async {
    if ([originalName, familyNameFr, givenNameFr, fullNameAr].every((x) => (x ?? '').trim().isEmpty)) {
      throw ArgumentError('student_name_required');
    }
    return _db.transaction((txn) async {
      final cls = await txn.query('classes', where: 'id = ? AND status = ?', whereArgs: [classId, 'active']);
      if (cls.isEmpty) throw StateError('class_not_found');
      final studentId = await txn.insert('students', {
        'matricule': _clean(matricule),
        'family_name_fr': _clean(familyNameFr),
        'given_name_fr': _clean(givenNameFr),
        'full_name_ar': _clean(fullNameAr),
        'full_name_original': _clean(originalName),
        'gender': gender,
        'birth_date': _clean(birthDate),
        'guardian_name': _clean(guardianName),
        'guardian_phone': _clean(guardianPhone),
        'notes': _clean(notes),
      });
      await txn.insert('enrollments', {
        'student_id': studentId,
        'institution_id': cls.first['institution_id'],
        'academic_year_id': cls.first['academic_year_id'],
        'class_id': classId,
        'status': 'active',
        'start_date': DateTime.now().toIso8601String().substring(0, 10),
      });
      return studentId;
    });
  }

  Future<void> endEnrollment(int enrollmentId) async {
    await _db.update('enrollments', {
      'status': 'ended',
      'end_date': DateTime.now().toIso8601String().substring(0, 10),
      'end_reason': 'ended_by_teacher',
    }, where: "id = ? AND status = 'active'", whereArgs: [enrollmentId]);
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
