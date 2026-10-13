import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/repositories/followup_repository.dart';
import 'package:suivi_scolaire/repositories/institution_repository.dart';
import 'package:suivi_scolaire/repositories/student_repository.dart';
import 'package:suivi_scolaire/repositories/timetable_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late FollowupRepository followup;
  late int classId, studentId, enrollmentId, subjectId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_followup_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(),
    );
    final institutions = InstitutionRepository(adb.db);
    final students = StudentRepository(adb.db);
    final timetable = TimetableRepository(adb.db);
    final institutionId = await institutions.save(nameAr: 'مدرسة الاختبار', nameFr: 'École Test');
    final yearId = await adb.db.insert('academic_years', {
      'name': '2026-2027', 'start_date': '2026-09-01', 'end_date': '2027-06-30',
    });
    await adb.db.insert('institution_academic_years', {
      'institution_id': institutionId, 'academic_year_id': yearId, 'is_active': 1,
    });
    classId = await adb.db.insert('classes', {
      'institution_id': institutionId, 'academic_year_id': yearId,
      'name_fr': '5AS', 'name_ar': 'الخامسة ثانوي',
    });
    subjectId = await timetable.saveSubject(nameAr: 'الفيزياء', nameFr: 'Physique');
    studentId = await students.createAndEnroll(
      classId: classId, originalName: 'Student Test',
      familyNameFr: 'Test', givenNameFr: 'Student', fullNameAr: 'تلميذ الاختبار',
    );
    enrollmentId = (await adb.db.query('enrollments', where: 'student_id=?', whereArgs: [studentId])).single['id'] as int;
    followup = FollowupRepository(adb.db);
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  test('behaviour observation is saved with date, category and severity', () async {
    final category = (await followup.behaviorCategories()).first;
    await followup.addBehavior(
      enrollmentId: enrollmentId, categoryId: category['id'] as int,
      date: '2026-10-13', severity: 3, description: 'Participation observée',
    );
    final rows = await followup.behaviorRecords(classId);
    expect(rows, hasLength(1));
    expect(rows.single['record_date'], '2026-10-13');
    expect(rows.single['severity'], 3);
    expect(rows.single['description'], 'Participation observée');
  });

  test('assessment marks are upserted, zero is a real mark and history is retained', () async {
    final type = (await followup.assessmentTypes()).first;
    final assessmentId = await followup.addAssessment(
      classId: classId, subjectId: subjectId, typeId: type['id'] as int,
      title: 'Devoir 1', date: '2026-10-13', maxScore: 20, coefficient: 2,
    );
    await followup.saveResult(assessmentId: assessmentId, enrollmentId: enrollmentId, classId: classId, status: 'graded', score: 0);
    await followup.saveResult(assessmentId: assessmentId, enrollmentId: enrollmentId, classId: classId, status: 'graded', score: 15);
    final results = await adb.db.query('assessment_results', where: 'assessment_id=?', whereArgs: [assessmentId]);
    expect(results, hasLength(1));
    expect(results.single['score'], 15);
    expect(await adb.db.query('assessment_result_history', where: 'result_id=?', whereArgs: [results.single['id']]), hasLength(1));
  });

  test('weighted subject average is normalized to 20 for each student', () async {
    final type = (await followup.assessmentTypes()).first;
    final a1 = await followup.addAssessment(classId: classId, subjectId: subjectId, typeId: type['id'] as int, title: 'Devoir 1', date: '2026-10-10', maxScore: 20, coefficient: 1);
    final a2 = await followup.addAssessment(classId: classId, subjectId: subjectId, typeId: type['id'] as int, title: 'Devoir 2', date: '2026-10-12', maxScore: 40, coefficient: 3);
    await followup.saveResult(assessmentId: a1, enrollmentId: enrollmentId, classId: classId, status: 'graded', score: 10);
    await followup.saveResult(assessmentId: a2, enrollmentId: enrollmentId, classId: classId, status: 'graded', score: 30);
    final rows = await followup.studentSubjectAverages(classId);
    expect(rows, hasLength(1));
    // 10/20 -> 10/20, 30/40 -> 15/20; weighted by 1 and 3 => 13.75/20.
    expect((rows.single['average20'] as num).toDouble(), closeTo(13.75, 0.0001));
  });

  test('pending and absent results cannot carry a score', () async {
    final type = (await followup.assessmentTypes()).first;
    final assessmentId = await followup.addAssessment(classId: classId, subjectId: subjectId, typeId: type['id'] as int, title: 'Test', date: '2026-10-13', maxScore: 20, coefficient: 1);
    await expectLater(followup.saveResult(assessmentId: assessmentId, enrollmentId: enrollmentId, classId: classId, status: 'absent', score: 0), throwsArgumentError);
    expect(await adb.db.query('assessment_results'), isEmpty);
  });
}
