import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/core/errors/app_exception.dart';
import 'package:suivi_scolaire/models/enrollment.dart';
import 'package:suivi_scolaire/repositories/enrollment_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late EnrollmentRepository repo;
  late int inst1, inst2, y1, y2, a1, b1, a1next, student;

  Future<int> cls(int i, int y, String n) =>
      adb.db.insert('classes', {'institution_id': i, 'academic_year_id': y, 'name_fr': n});

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(), // tests run from project root
    );
    final d = adb.db;
    inst1 = await d.insert('institutions', {'name_fr': 'A'});
    inst2 = await d.insert('institutions', {'name_fr': 'B'});
    y1 = await d.insert('academic_years', {'name': '2025-2026', 'start_date': '2025-10-01', 'end_date': '2026-07-01'});
    y2 = await d.insert('academic_years', {'name': '2026-2027', 'start_date': '2026-10-01', 'end_date': '2027-07-01'});
    a1 = await cls(inst1, y1, '5SN1');
    b1 = await cls(inst2, y1, '5SN1');
    a1next = await cls(inst1, y2, '6SN1');
    student = await d.insert('students', {'full_name_original': 'Aissata Adama Ba'});
    repo = EnrollmentRepository(d);
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  test('second active enrollment in the same year (other institution) is refused', () async {
    await repo.enroll(studentId: student, classId: a1);
    expect(
      () => repo.enroll(studentId: student, classId: b1),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.studentAlreadyActive)),
    );
  });

  test('transfer between institutions keeps history, leaves exactly one active', () async {
    await repo.enroll(studentId: student, classId: a1);
    final moved = await repo.transfer(studentId: student, toClassId: b1, reason: 'move');
    expect(moved.institutionId, inst2);
    final h = await repo.historyOf(student);
    expect(h.map((e) => e.status), [EnrollmentStatus.active, EnrollmentStatus.transferred]);
    expect(h.last.endReason, 'move');
  });

  test('transfer without an active enrollment fails with notActive', () async {
    expect(
      () => repo.transfer(studentId: student, toClassId: b1),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.notActive)),
    );
  });

  test('a different institution in a later year is allowed', () async {
    await repo.enroll(studentId: student, classId: a1);
    await repo.end((await repo.activeFor(student, y1))!.id);
    final next = await repo.enroll(studentId: student, classId: a1next);
    expect(next.academicYearId, y2);
    expect((await repo.historyOf(student)).length, 2);
  });
}
