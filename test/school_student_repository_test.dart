import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/core/errors/app_exception.dart';
import 'package:suivi_scolaire/models/enrollment.dart';
import 'package:suivi_scolaire/repositories/enrollment_repository.dart';
import 'package:suivi_scolaire/repositories/institution_repository.dart';
import 'package:suivi_scolaire/repositories/school_repository.dart';
import 'package:suivi_scolaire/repositories/student_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late SchoolRepository school;
  late StudentRepository students;
  late EnrollmentRepository enroll;
  late int instA, instB;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_school_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(),
    );
    school = SchoolRepository(adb.db);
    students = StudentRepository(adb.db);
    enroll = EnrollmentRepository(adb.db);
    final inst = InstitutionRepository(adb.db);
    instA = await inst.add(nameFr: 'A');
    instB = await inst.add(nameFr: 'B');
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  Future<int> year(int inst, [String name = '2026-2027']) =>
      school.addYear(inst, name: name, startDate: '${name.substring(0, 4)}-10-01', endDate: '${name.substring(5)}-07-01');

  test('first year becomes active, later ones do not; active can be switched', () async {
    final y1 = await year(instA, '2026-2027');
    final y2 = await year(instA, '2027-2028');
    expect(await school.activeYearId(instA), y1);
    await school.setActiveYear(instA, y2);
    expect(await school.activeYearId(instA), y2);
    final years = await school.yearsOf(instA);
    expect(years.where((y) => y.isActive), hasLength(1));
  });

  test('same year name is shared between institutions, institutions stay independent', () async {
    final a = await year(instA);
    final b = await year(instB);
    expect(a, b);
    expect(await school.activeYearId(instB), b);
  });

  test('invalid dates and empty fields are rejected', () async {
    expect(() => school.addYear(instA, name: 'X', startDate: '2027-01-01', endDate: '2026-01-01'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.invalidDates)));
    expect(() => school.addYear(instA, name: ' ', startDate: '', endDate: ''),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.requiredField)));
  });

  test('class names are unique per institution and year; archive hides class', () async {
    final y = await year(instA);
    final c = await school.addClass(instA, y, nameFr: '6AS-C');
    expect(() => school.addClass(instA, y, nameFr: '6AS-C'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.classExists)));
    await school.setClassArchived(c, true);
    expect(await school.classesOf(instA, y), isEmpty);
    expect(await school.classesOf(instA, y, archived: true), hasLength(1));
  });

  test('add student with enrollment, search, and list by class', () async {
    final y = await year(instA);
    final c1 = await school.addClass(instA, y, nameFr: 'C1');
    final c2 = await school.addClass(instA, y, nameFr: 'C2');
    await students.addAndEnroll(classId: c1, familyNameFr: 'Salem', givenNameFr: 'Ahmed', matricule: 'M1');
    await students.addAndEnroll(classId: c2, fullNameAr: 'محمد سالم');
    expect(await students.listEnrolled(institutionId: instA, yearId: y), hasLength(2));
    expect(await students.listEnrolled(institutionId: instA, yearId: y, classId: c1), hasLength(1));
    final byAr = await students.listEnrolled(institutionId: instA, yearId: y, query: 'سالم');
    expect(byAr, hasLength(1));
    expect(byAr.first.student.displayName(true), 'محمد سالم');
    final byMat = await students.listEnrolled(institutionId: instA, yearId: y, query: 'M1');
    expect(byMat.first.student.displayName(false), 'Salem Ahmed');
  });

  test('student needs at least one name', () async {
    final y = await year(instA);
    final c = await school.addClass(instA, y, nameFr: 'C1');
    expect(() => students.addAndEnroll(classId: c, familyNameFr: ' '),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.requiredField)));
  });

  test('transfer across institutions in the same year keeps history', () async {
    final y = await year(instA);
    await year(instB);
    final ca = await school.addClass(instA, y, nameFr: 'CA');
    final cb = await school.addClass(instB, y, nameFr: 'CB');
    final sid = await students.addAndEnroll(classId: ca, familyNameFr: 'X');
    await enroll.transfer(studentId: sid, toClassId: cb);
    expect(await students.listEnrolled(institutionId: instA, yearId: y), isEmpty);
    expect(await students.listEnrolled(institutionId: instB, yearId: y), hasLength(1));
    final hist = await enroll.historyOf(sid);
    expect(hist, hasLength(2));
    expect(hist.where((e) => e.status == EnrollmentStatus.transferred), hasLength(1));
  });

  test('later-year enrollment in another institution is allowed', () async {
    final y1 = await year(instA, '2026-2027');
    final y2 = await year(instB, '2027-2028');
    final ca = await school.addClass(instA, y1, nameFr: 'CA');
    final cb = await school.addClass(instB, y2, nameFr: 'CB');
    final sid = await students.addAndEnroll(classId: ca, familyNameFr: 'X');
    await enroll.enroll(studentId: sid, classId: cb);
    expect(await students.listEnrolled(institutionId: instA, yearId: y1), hasLength(1));
    expect(await students.listEnrolled(institutionId: instB, yearId: y2), hasLength(1));
  });
}
