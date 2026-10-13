import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:suivi_scolaire/core/database/app_database.dart';
import 'package:suivi_scolaire/core/errors/app_exception.dart';
import 'package:suivi_scolaire/repositories/institution_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late AppDatabase adb;
  late InstitutionRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('suivi_inst_test');
    adb = await AppDatabase.open(
      directory: tmp.path,
      factory: databaseFactoryFfi,
      loader: (path) => File(path).readAsString(),
    );
    repo = InstitutionRepository(adb.db);
  });

  tearDown(() async {
    await adb.close();
    await tmp.delete(recursive: true);
  });

  test('add + list + display name fallback', () async {
    await repo.add(nameAr: 'مدرسة المعارف', nameFr: '  ');
    final l = await repo.list(archived: false);
    expect(l, hasLength(1));
    expect(l.first.nameFr, isNull);
    expect(l.first.displayName(false), 'مدرسة المعارف');
  });

  test('a name in at least one language is required', () async {
    expect(
      () => repo.add(nameAr: ' ', nameFr: null),
      throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCodes.nameRequired)),
    );
  });

  test('archive and restore keep the record', () async {
    final id = await repo.add(nameFr: 'Dar Al-Maaref');
    await repo.setArchived(id, true);
    expect(await repo.list(archived: false), isEmpty);
    expect(await repo.list(archived: true), hasLength(1));
    await repo.setArchived(id, false);
    expect(await repo.list(archived: false), hasLength(1));
  });

  test('update changes fields', () async {
    final id = await repo.add(nameFr: 'A');
    await repo.update(id, nameFr: 'B', phone: '123');
    final r = (await repo.list(archived: false)).first;
    expect(r.nameFr, 'B');
    expect(r.phone, '123');
  });
}
