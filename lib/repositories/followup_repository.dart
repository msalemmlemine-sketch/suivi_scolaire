import 'package:sqflite/sqflite.dart';

/// Local-only repository for behaviour records, assessments and marks.
class FollowupRepository {
  FollowupRepository(this._db);
  final Database _db;

  Future<List<Map<String, Object?>>> activeClasses() => _db.rawQuery('''
    SELECT c.id,c.name_ar,c.name_fr,c.institution_id,c.academic_year_id,
           i.name_ar AS institution_name_ar,i.name_fr AS institution_name_fr,y.name AS year_name
    FROM classes c JOIN institutions i ON i.id=c.institution_id
    JOIN academic_years y ON y.id=c.academic_year_id
    JOIN institution_academic_years iy ON iy.institution_id=c.institution_id AND iy.academic_year_id=c.academic_year_id
    WHERE c.status='active' AND i.status='active' AND iy.is_active=1
    ORDER BY i.id,c.name_fr
  ''');

  Future<List<Map<String, Object?>>> studentsForClass(int classId) => _db.rawQuery('''
    SELECT e.id AS enrollment_id,s.id AS student_id,s.matricule,s.full_name_original,
           s.full_name_ar,s.family_name_fr,s.given_name_fr
    FROM enrollments e JOIN students s ON s.id=e.student_id
    WHERE e.class_id=? AND e.status='active'
    ORDER BY COALESCE(NULLIF(s.family_name_fr,''),NULLIF(s.full_name_ar,''),s.full_name_original),s.given_name_fr
  ''', [classId]);

  Future<List<Map<String, Object?>>> behaviorCategories() => _db.query(
    'behavior_categories', where: 'is_active=1', orderBy: 'polarity DESC,name_fr');

  Future<List<Map<String, Object?>>> behaviorRecords(int classId) => _db.rawQuery('''
    SELECT b.*,c.name_ar AS category_ar,c.name_fr AS category_fr,c.polarity,
           s.full_name_ar,s.full_name_original,s.family_name_fr,s.given_name_fr,s.matricule
    FROM behavior_records b JOIN behavior_categories c ON c.id=b.category_id
    JOIN enrollments e ON e.id=b.enrollment_id JOIN students s ON s.id=e.student_id
    WHERE e.class_id=? ORDER BY b.record_date DESC,b.id DESC
  ''', [classId]);

  Future<int> addBehavior({required int enrollmentId, required int categoryId,
    required String date, required int severity, String? description,
    String? actionTaken, String? teacherNotes}) async {
    if (!_validDate(date)) throw ArgumentError('invalid_date');
    if (severity < 1 || severity > 5) throw ArgumentError('invalid_severity');
    return _db.insert('behavior_records', {
      'enrollment_id': enrollmentId, 'category_id': categoryId, 'record_date': date,
      'severity': severity, 'description': _clean(description),
      'action_taken': _clean(actionTaken), 'teacher_notes': _clean(teacherNotes),
    });
  }

  Future<List<Map<String, Object?>>> subjects() => _db.query('subjects', orderBy: "COALESCE(NULLIF(name_fr,''),name_ar)");
  Future<List<Map<String, Object?>>> assessmentTypes() => _db.query('assessment_types', where: 'is_active=1', orderBy: 'id');

  Future<List<Map<String, Object?>>> assessments(int classId) => _db.rawQuery('''
    SELECT a.*,s.name_ar AS subject_ar,s.name_fr AS subject_fr,t.label_ar AS type_ar,t.label_fr AS type_fr
    FROM assessments a JOIN subjects s ON s.id=a.subject_id JOIN assessment_types t ON t.id=a.type_id
    WHERE a.class_id=? ORDER BY a.assessment_date DESC,a.id DESC
  ''', [classId]);

  Future<int> addAssessment({required int classId, required int subjectId,
    required int typeId, required String title, required String date,
    required double maxScore, required double coefficient, int? period,
    String? description, String? notes}) async {
    if (title.trim().isEmpty) throw ArgumentError('title_required');
    if (!_validDate(date)) throw ArgumentError('invalid_date');
    if (!maxScore.isFinite || maxScore <= 0 || !coefficient.isFinite || coefficient <= 0) {
      throw ArgumentError('invalid_assessment_scale');
    }
    final rows = await _db.query('classes', where: 'id=? AND status=?', whereArgs: [classId,'active'], limit: 1);
    if (rows.isEmpty) throw StateError('class_not_found');
    final cls = rows.single;
    return _db.insert('assessments', {
      'institution_id': cls['institution_id'], 'academic_year_id': cls['academic_year_id'],
      'class_id': classId, 'subject_id': subjectId, 'type_id': typeId,
      'title': title.trim(), 'assessment_date': date, 'period': period,
      'max_score': maxScore, 'coefficient': coefficient,
      'description': _clean(description), 'notes': _clean(notes),
    });
  }

  Future<List<Map<String, Object?>>> resultsForAssessment(int assessmentId) => _db.rawQuery('''
    SELECT e.id AS enrollment_id,s.id AS student_id,s.matricule,s.full_name_original,
           s.full_name_ar,s.family_name_fr,s.given_name_fr,r.id AS result_id,
           r.status AS result_status,r.score
    FROM assessments a JOIN enrollments e ON e.class_id=a.class_id
    JOIN students s ON s.id=e.student_id
    LEFT JOIN assessment_results r ON r.assessment_id=a.id AND r.enrollment_id=e.id
    WHERE a.id=? AND e.start_date<=a.assessment_date
      AND (e.end_date IS NULL OR e.end_date>=a.assessment_date)
    ORDER BY COALESCE(NULLIF(s.family_name_fr,''),NULLIF(s.full_name_ar,''),s.full_name_original),s.given_name_fr
  ''', [assessmentId]);

  Future<void> saveResult({required int assessmentId, required int enrollmentId,
    required int classId, required String status, double? score}) async {
    const allowed = {'graded','pending','absent','exempt'};
    if (!allowed.contains(status)) throw ArgumentError('invalid_result_status');
    if ((status == 'graded') != (score != null)) throw ArgumentError('score_status_mismatch');
    if (score != null && (!score.isFinite || score < 0)) throw ArgumentError('invalid_score');
    final assessmentRows = await _db.query('assessments', columns: ['max_score', 'assessment_date'], where: 'id=? AND class_id=?', whereArgs: [assessmentId,classId], limit: 1);
    if (assessmentRows.isEmpty) throw StateError('assessment_not_found');
    final assessment = assessmentRows.single;
    final enrollmentRows = await _db.query(
      'enrollments', columns: ['id'],
      where: 'id=? AND class_id=? AND (date(start_date)<=date(?) OR end_date IS NULL) AND (end_date IS NULL OR date(end_date)>=date(?))',
      whereArgs: [enrollmentId, classId, assessment['assessment_date'], assessment['assessment_date']], limit: 1,
    );
    if (enrollmentRows.isEmpty) throw StateError('enrollment_not_in_class_on_assessment_date');
    final max = (assessment['max_score'] as num).toDouble();
    final setting = await _db.query('app_settings', columns: ['value'], where: 'key=?', whereArgs: ['allow_score_over_max'], limit: 1);
    if (score != null && score > max && (setting.isEmpty || setting.single['value'] != '1')) {
      throw ArgumentError('score_over_max');
    }
    final existing = await _db.query('assessment_results', columns: ['id'], where: 'assessment_id=? AND enrollment_id=?', whereArgs: [assessmentId,enrollmentId], limit: 1);
    final values = {'assessment_id': assessmentId, 'enrollment_id': enrollmentId,
      'class_id': classId, 'status': status, 'score': score,
      'updated_at': DateTime.now().toUtc().toIso8601String()};
    if (existing.isEmpty) {
      await _db.insert('assessment_results', values);
    } else {
      await _db.update('assessment_results', values, where: 'id=?', whereArgs: [existing.single['id']]);
    }
  }

  /// Weighted average on 20 per currently enrolled student and subject.
  /// Only graded results contribute; pending/absent/exempt marks are excluded.
  Future<List<Map<String, Object?>>> studentSubjectAverages(int classId) => _db.rawQuery('''
    SELECT e.id AS enrollment_id,s.id AS student_id,s.matricule,
      s.full_name_original,s.full_name_ar,s.family_name_fr,s.given_name_fr,
      sub.id AS subject_id,sub.name_ar AS subject_ar,sub.name_fr AS subject_fr,
      COUNT(r.id) AS graded_count,
      SUM((r.score/a.max_score)*20*a.coefficient)/SUM(a.coefficient) AS average20
    FROM assessments a
    JOIN assessment_results r ON r.assessment_id=a.id AND r.status='graded'
    JOIN enrollments e ON e.id=r.enrollment_id AND e.class_id=a.class_id
    JOIN students s ON s.id=e.student_id
    JOIN subjects sub ON sub.id=a.subject_id
    WHERE a.class_id=?
    GROUP BY e.id,s.id,sub.id,sub.name_ar,sub.name_fr
    ORDER BY COALESCE(NULLIF(s.family_name_fr,''),NULLIF(s.full_name_ar,''),s.full_name_original),
      COALESCE(NULLIF(sub.name_fr,''),sub.name_ar)
  ''', [classId]);

  String? _clean(String? v) { final x=v?.trim(); return x==null||x.isEmpty?null:x; }
  bool _validDate(String v) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return false;
    final d=DateTime.tryParse(v);
    return d!=null && d.toIso8601String().substring(0,10)==v;
  }
}
