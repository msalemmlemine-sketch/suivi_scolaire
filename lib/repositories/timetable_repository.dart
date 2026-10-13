import 'package:sqflite/sqflite.dart';

/// Data access for weekly timetable, actual lessons, and attendance.
/// All operations use the local SQLite database; no network is required.
class TimetableRepository {
  TimetableRepository(this._db);
  final Database _db;

  Future<List<Map<String, Object?>>> activeClasses() => _db.rawQuery('''
    SELECT c.id, c.name_ar, c.name_fr, c.institution_id, c.academic_year_id,
           i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr,
           y.name AS year_name
    FROM classes c
    JOIN institutions i ON i.id = c.institution_id
    JOIN academic_years y ON y.id = c.academic_year_id
    JOIN institution_academic_years iy
      ON iy.institution_id = c.institution_id AND iy.academic_year_id = c.academic_year_id
    WHERE c.status = 'active' AND i.status = 'active' AND iy.is_active = 1
    ORDER BY i.id, c.name_fr
  ''');

  Future<List<Map<String, Object?>>> subjects() => _db.query(
        'subjects', orderBy: "COALESCE(NULLIF(name_fr,''), name_ar), id");

  Future<int> saveSubject({int? id, required String nameAr, required String nameFr, String? code}) async {
    final ar = nameAr.trim();
    final fr = nameFr.trim();
    if (ar.isEmpty && fr.isEmpty) throw ArgumentError('subject_name_required');
    final values = <String, Object?>{
      'name_ar': ar.isEmpty ? null : ar,
      'name_fr': fr.isEmpty ? null : fr,
      'code': _clean(code),
    };
    if (id == null) return _db.insert('subjects', values);
    await _db.update('subjects', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<List<Map<String, Object?>>> entriesForClass(int classId) => _db.rawQuery('''
    SELECT t.*, s.name_ar AS subject_name_ar, s.name_fr AS subject_name_fr,
           c.name_ar AS class_name_ar, c.name_fr AS class_name_fr,
           i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr,
           y.name AS year_name
    FROM timetable_entries t
    JOIN subjects s ON s.id = t.subject_id
    JOIN classes c ON c.id = t.class_id
    JOIN institutions i ON i.id = t.institution_id
    JOIN academic_years y ON y.id = t.academic_year_id
    WHERE t.class_id = ? AND t.is_active = 1
    ORDER BY t.day_of_week, t.start_time
  ''', [classId]);

  Future<List<Map<String, Object?>>> allActiveEntries() => _db.rawQuery('''
    SELECT t.*, s.name_ar AS subject_name_ar, s.name_fr AS subject_name_fr,
           c.name_ar AS class_name_ar, c.name_fr AS class_name_fr,
           i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr
    FROM timetable_entries t JOIN subjects s ON s.id=t.subject_id
    JOIN classes c ON c.id=t.class_id JOIN institutions i ON i.id=t.institution_id
    WHERE t.is_active=1 AND i.status='active'
    ORDER BY t.day_of_week,t.start_time
  ''');

  Future<int> saveEntry({
    int? id,
    required int classId,
    required int subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? notes,
  }) async {
    if (dayOfWeek < 1 || dayOfWeek > 7) throw ArgumentError('invalid_day');
    if (!_validTime(startTime) || !_validTime(endTime) || endTime.compareTo(startTime) <= 0) {
      throw ArgumentError('invalid_time_range');
    }
    final classes = await _db.query('classes', where: 'id = ? AND status = ?', whereArgs: [classId, 'active']);
    if (classes.isEmpty) throw StateError('class_not_found');
    final c = classes.single;
    final values = <String, Object?>{
      'institution_id': c['institution_id'],
      'academic_year_id': c['academic_year_id'],
      'class_id': classId,
      'subject_id': subjectId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': _clean(room),
      'notes': _clean(notes),
      'is_active': 1,
    };
    if (id == null) return _db.insert('timetable_entries', values);
    await _db.update('timetable_entries', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> deactivateEntry(int id) async {
    await _db.update('timetable_entries', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> sessionsForClass(int classId) => _db.rawQuery('''
    SELECT l.*, s.name_ar AS subject_name_ar, s.name_fr AS subject_name_fr,
           c.name_ar AS class_name_ar, c.name_fr AS class_name_fr
    FROM lesson_sessions l JOIN subjects s ON s.id=l.subject_id
    JOIN classes c ON c.id=l.class_id
    WHERE l.class_id = ? ORDER BY l.session_date DESC, COALESCE(l.actual_start,'') DESC, l.id DESC
  ''', [classId]);

  Future<List<Map<String, Object?>>> allSessions({String? date}) => _db.rawQuery('''
    SELECT l.*, s.name_ar AS subject_name_ar, s.name_fr AS subject_name_fr,
           c.name_ar AS class_name_ar, c.name_fr AS class_name_fr,
           i.name_ar AS institution_name_ar, i.name_fr AS institution_name_fr
    FROM lesson_sessions l JOIN subjects s ON s.id=l.subject_id
    JOIN classes c ON c.id=l.class_id JOIN institutions i ON i.id=l.institution_id
    WHERE i.status='active' AND (? IS NULL OR l.session_date = ?)
    ORDER BY l.session_date DESC, COALESCE(l.actual_start,'') DESC, l.id DESC
  ''', [date, date]);

  Future<int> createSessionFromEntry({required int timetableEntryId, required String date}) async {
    if (!_validDate(date)) throw ArgumentError('invalid_session_date');
    final rows = await _db.query('timetable_entries', where: 'id = ? AND is_active = 1', whereArgs: [timetableEntryId]);
    if (rows.isEmpty) throw StateError('timetable_entry_not_found');
    final e = rows.single;
    return _db.insert('lesson_sessions', {
      'timetable_entry_id': timetableEntryId,
      'institution_id': e['institution_id'],
      'academic_year_id': e['academic_year_id'],
      'class_id': e['class_id'],
      'subject_id': e['subject_id'],
      'session_date': date,
      'actual_start': e['start_time'],
      'actual_end': e['end_time'],
      'status': 'scheduled',
    });
  }

  Future<void> updateSession(int id, {required String status, String? topic, String? notes, String? actualStart, String? actualEnd}) async {
    const statuses = {'scheduled', 'done', 'cancelled', 'made_up'};
    if (!statuses.contains(status)) throw ArgumentError('invalid_session_status');
    if ((actualStart != null && actualStart.isNotEmpty && !_validTime(actualStart)) ||
        (actualEnd != null && actualEnd.isNotEmpty && !_validTime(actualEnd))) throw ArgumentError('invalid_actual_time');
    if (actualStart != null && actualStart.isNotEmpty && actualEnd != null && actualEnd.isNotEmpty && actualEnd.compareTo(actualStart) <= 0) {
      throw ArgumentError('invalid_actual_time_range');
    }
    await _db.update('lesson_sessions', {
      'status': status,
      'topic': _clean(topic),
      'notes': _clean(notes),
      'actual_start': _clean(actualStart),
      'actual_end': _clean(actualEnd),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> attendanceRoster(int sessionId) async {
    final sessions = await _db.query('lesson_sessions', where: 'id = ?', whereArgs: [sessionId]);
    if (sessions.isEmpty) throw StateError('session_not_found');
    final session = sessions.single;
    return _db.rawQuery('''
      SELECT e.id AS enrollment_id, s.id AS student_id, s.matricule,
             s.full_name_original, s.full_name_ar, s.family_name_fr, s.given_name_fr,
             ar.id AS attendance_id, ar.status_code, ar.late_minutes, ar.note,
             ast.label_ar AS status_label_ar, ast.label_fr AS status_label_fr
      FROM enrollments e JOIN students s ON s.id=e.student_id
      LEFT JOIN attendance_records ar ON ar.enrollment_id=e.id AND ar.lesson_session_id=?
      LEFT JOIN attendance_statuses ast ON ast.code=ar.status_code
      WHERE e.class_id=? AND e.start_date <= ? AND (e.end_date IS NULL OR e.end_date >= ?)
      ORDER BY COALESCE(NULLIF(s.family_name_fr,''),NULLIF(s.full_name_ar,''),s.full_name_original),s.given_name_fr
    ''', [sessionId, session['class_id'], session['session_date'], session['session_date']]);
  }

  Future<List<Map<String, Object?>>> attendanceStatuses() => _db.query('attendance_statuses', where: 'is_active = 1', orderBy: 'sort_order');

  Future<void> saveAttendance({required int sessionId, required int enrollmentId, required int classId, required String statusCode, int? lateMinutes, String? note}) async {
    if (lateMinutes != null && lateMinutes < 0) throw ArgumentError('invalid_late_minutes');
    final sessions = await _db.query('lesson_sessions', columns: ['status'], where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (sessions.isEmpty) throw StateError('session_not_found');
    if (sessions.single['status'] == 'cancelled') throw StateError('session_cancelled');
    final existing = await _db.query('attendance_records', where: 'lesson_session_id = ? AND enrollment_id = ?', whereArgs: [sessionId, enrollmentId], limit: 1);
    final values = <String, Object?>{
      'lesson_session_id': sessionId,
      'enrollment_id': enrollmentId,
      'class_id': classId,
      'status_code': statusCode,
      'late_minutes': statusCode == 'late' ? lateMinutes : null,
      'note': _clean(note),
    };
    if (existing.isEmpty) {
      await _db.insert('attendance_records', values);
    } else {
      await _db.update('attendance_records', values, where: 'id = ?', whereArgs: [existing.single['id']]);
    }
  }

  Future<Map<String, int>> attendanceSummary(int sessionId) async {
    final rows = await _db.rawQuery('''
      SELECT ast.kind, COUNT(*) AS n FROM attendance_records ar
      JOIN attendance_statuses ast ON ast.code=ar.status_code
      WHERE ar.lesson_session_id=? GROUP BY ast.kind
    ''', [sessionId]);
    return {for (final r in rows) r['kind'] as String: r['n'] as int};
  }

  bool _validTime(String value) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) return false;
    return true;
  }

  bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
