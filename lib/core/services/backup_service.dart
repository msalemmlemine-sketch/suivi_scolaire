import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_migrations.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Full-database backup and restore. A backup is a plain copy of the SQLite
/// file, so it contains every table (students, enrollments, marks, ...).
class BackupService {
  /// Writes a copy of the live database to a temp file and opens the share
  /// sheet so the user can save it to Drive, WhatsApp, Downloads, etc.
  static Future<void> exportBackup(Database db) async {
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final out = File(p.join(dir.path, 'suivi_scolaire_backup_$stamp.db'));
    if (await out.exists()) await out.delete();
    await File(db.path).copy(out.path);
    await Share.shareXFiles([XFile(out.path)], subject: 'Suivi Scolaire backup $stamp');
  }

  /// Lets the user pick a backup file, validates it and replaces the live
  /// database. Returns false if the user cancelled. The database is closed on
  /// success, so the app must be restarted afterwards.
  static Future<bool> restoreBackup(Database db) async {
    final picked = await openFile();
    if (picked == null) return false;

    final dir = await getTemporaryDirectory();
    final candidate = File(p.join(dir.path, 'restore_candidate.db'));
    await candidate.writeAsBytes(await picked.readAsBytes(), flush: true);
    await _validate(candidate.path);

    final target = db.path;
    await db.close();
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$target$suffix');
      if (await f.exists()) await f.delete();
    }
    // Safety copy of the data being replaced.
    final safety = File('$target.before_restore');
    if (await safety.exists()) await safety.delete();
    await File(target).copy(safety.path);
    await candidate.copy(target);
    await candidate.delete();
    return true;
  }

  static Future<void> _validate(String path) async {
    final raf = await File(path).open();
    final header = await raf.read(15);
    await raf.close();
    if (String.fromCharCodes(header) != 'SQLite format 3') {
      throw const BackupException('invalid');
    }
    final d = await openDatabase(path, readOnly: true, singleInstance: false);
    try {
      final rows = await d.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final names = rows.map((r) => r['name']).toSet();
      for (final t in const ['students', 'enrollments', 'institutions', 'classes']) {
        if (!names.contains(t)) throw const BackupException('invalid');
      }
      final version = Sqflite.firstIntValue(await d.rawQuery('PRAGMA user_version')) ?? 0;
      if (version > kLatestSchemaVersion) throw const BackupException('too_new');
    } finally {
      await d.close();
    }
  }
}
