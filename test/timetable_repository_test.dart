import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/repositories/institution_repository.dart';
import 'package:suivi_scolaire/repositories/student_repository.dart';
import 'package:suivi_scolaire/repositories/timetable_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late InstitutionRepository institutions;
  late StudentRepository students;
  late TimetableRepository timetable;
  late int institutionId, yearId, classId, subjectId, entryId, studentId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_timetable_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(),
    );
    institutions = InstitutionRepository(adb.db);
    students = StudentRepository(adb.db);
    timetable = TimetableRepository(adb.db);
    institutionId = await institutions.save(nameAr: 'مدرسة الاختبار', nameFr: 'École Test');
    yearId = await adb.db.insert('academic_years', {
      'name': '2026-2027', 'start_date': '2026-09-01', 'end_date': '2027-06-30',
    });
    await adb.db.insert('institution_academic_years', {
      'institution_id': institutionId, 'academic_year_id': yearId, 'is_active': 1,
    });
    classId = await adb.db.insert('classes', {
      'institution_id': institutionId, 'academic_year_id': yearId,
      'name_fr': '5AS', 'name_ar': 'الخامسة ثانوي',
    });
    subjectId = await timetable.saveSubject(nameAr: 'الفيزياء', nameFr: 'Physique', code: 'PC');
    entryId = await timetable.saveEntry(classId: classId, subjectId: subjectId, dayOfWeek: 1, startTime: '08:00', endTime: '09:00');
    studentId = await students.createAndEnroll(classId: classId, originalName: 'Student One', familyNameFr: 'One', givenNameFr: 'Student');
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  test('subject preserves Arabic and French names', () async {
    final row = (await adb.db.query('subjects', where: 'id = ?', whereArgs: [subjectId])).single;
    expect(row['name_ar'], 'الفيزياء');
    expect(row['name_fr'], 'Physique');
  });

  test('rejects invalid time range before writing', () async {
    await expectLater(timetable.saveEntry(classId: classId, subjectId: subjectId, dayOfWeek: 2, startTime: '09:00', endTime: '08:00'), throwsArgumentError);
    expect(await adb.db.query('timetable_entries'), hasLength(1));
  });

  test('SQLite overlap trigger rejects a conflicting timetable slot', () async {
    await expectLater(
      timetable.saveEntry(classId: classId, subjectId: subjectId, dayOfWeek: 1, startTime: '08:30', endTime: '09:30'),
      throwsA(anything),
    );
    expect(await adb.db.query('timetable_entries'), hasLength(1));
  });

  test('adjacent timetable slots are accepted', () async {
    await timetable.saveEntry(classId: classId, subjectId: subjectId, dayOfWeek: 1, startTime: '09:00', endTime: '10:00');
    expect(await adb.db.query('timetable_entries'), hasLength(2));
  });

  test('creates one real lesson session and rejects duplicate entry/date', () async {
    final sessionId = await timetable.createSessionFromEntry(timetableEntryId: entryId, date: '2026-10-12');
    final rows = await timetable.sessionsForClass(classId);
    expect(rows, hasLength(1));
    expect(rows.single['id'], sessionId);
    expect(rows.single['status'], 'scheduled');
    expect(rows.single['actual_start'], '08:00');
    await expectLater(timetable.createSessionFromEntry(timetableEntryId: entryId, date: '2026-10-12'), throwsA(anything));
  });

  test('attendance is saved and edited without creating duplicate rows', () async {
    final sessionId = await timetable.createSessionFromEntry(timetableEntryId: entryId, date: '2026-10-12');
    final enrollment = (await adb.db.query('enrollments', where: 'student_id = ?', whereArgs: [studentId])).single;
    await timetable.saveAttendance(sessionId: sessionId, enrollmentId: enrollment['id'] as int, classId: classId, statusCode: 'present');
    await timetable.saveAttendance(sessionId: sessionId, enrollmentId: enrollment['id'] as int, classId: classId, statusCode: 'late', lateMinutes: 7);
    final rows = await adb.db.query('attendance_records', where: 'lesson_session_id = ?', whereArgs: [sessionId]);
    expect(rows, hasLength(1));
    expect(rows.single['status_code'], 'late');
    expect(rows.single['late_minutes'], 7);
  });

  test('attendance roster only contains students enrolled in the session class', () async {
    final sessionId = await timetable.createSessionFromEntry(timetableEntryId: entryId, date: '2026-10-12');
    final roster = await timetable.attendanceRoster(sessionId);
    expect(roster, hasLength(1));
    expect(roster.single['student_id'], studentId);
  });

  test('cancelled session cannot receive attendance', () async {
    final sessionId = await timetable.createSessionFromEntry(timetableEntryId: entryId, date: '2026-10-12');
    await timetable.updateSession(sessionId, status: 'cancelled');
    final enrollment = (await adb.db.query('enrollments', where: 'student_id = ?', whereArgs: [studentId])).single;
    await expectLater(
      timetable.saveAttendance(sessionId: sessionId, enrollmentId: enrollment['id'] as int, classId: classId, statusCode: 'present'),
      throwsA(anything),
    );
  });
}
