import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/repositories/institution_repository.dart';
import 'package:suivi_scolaire/repositories/student_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late InstitutionRepository institutions;
  late StudentRepository students;
  late int institutionId, yearId, classId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_repo_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(),
    );
    institutions = InstitutionRepository(adb.db);
    students = StudentRepository(adb.db);
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
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  test('institution saves Arabic and French names without rewriting them', () async {
    final row = (await adb.db.query('institutions', where: 'id = ?', whereArgs: [institutionId])).single;
    expect(row['name_ar'], 'مدرسة الاختبار');
    expect(row['name_fr'], 'École Test');
    await institutions.save(id: institutionId, nameAr: 'مدرسة جديدة', nameFr: 'Nouvelle école');
    final updated = (await adb.db.query('institutions', where: 'id = ?', whereArgs: [institutionId])).single;
    expect(updated['name_ar'], 'مدرسة جديدة');
    expect(updated['name_fr'], 'Nouvelle école');
  });

  test('archiving hides institution from active list but preserves the row', () async {
    await institutions.setArchived(institutionId, true);
    expect(await institutions.list(), isEmpty);
    expect((await institutions.list(includeArchived: true)).single['status'], 'archived');
  });

  test('student is created and enrolled atomically in the selected class', () async {
    final id = await students.createAndEnroll(
      classId: classId, originalName: '  Mohamed Salem  ',
      familyNameFr: 'Salem', givenNameFr: 'Mohamed', fullNameAr: 'محمد سالم', gender: 'M',
    );
    final row = (await students.activeStudents()).single;
    expect(row['id'], id);
    expect(row['full_name_original'], '  Mohamed Salem  '.trim());
    expect(row['institution_name_fr'], 'École Test');
    expect(row['class_name_fr'], '5AS');
    expect(await adb.db.query('enrollments', where: 'student_id = ? AND status = ?', whereArgs: [id, 'active']), hasLength(1));
  });

  test('same names are not automatically merged', () async {
    await students.createAndEnroll(classId: classId, originalName: 'Same Name');
    await students.createAndEnroll(classId: classId, originalName: 'Same Name');
    expect(await adb.db.query('students'), hasLength(2));
    expect(await students.activeStudents(), hasLength(2));
  });

  test('ending enrollment preserves the student and closes the active link', () async {
    final id = await students.createAndEnroll(classId: classId, originalName: 'Student One');
    final active = (await adb.db.query('enrollments', where: 'student_id = ?', whereArgs: [id])).single;
    await students.endEnrollment(active['id'] as int);
    expect(await students.activeStudents(), isEmpty);
    final history = (await adb.db.query('enrollments', where: 'student_id = ?', whereArgs: [id])).single;
    expect(history['status'], 'ended');
    expect(history['end_date'], isNotNull);
    expect((await adb.db.query('students', where: 'id = ?', whereArgs: [id])), hasLength(1));
  });
}
