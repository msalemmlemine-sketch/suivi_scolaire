import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

typedef SqlLoader = Future<String> Function(String assetPath);

Future<String> _bundleLoader(String path) => rootBundle.loadString(path);

/// Opens the persistent SQLite file. Foreign keys are enabled on every
/// connection; migrations run inside sqflite's own transaction.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open({
    required String directory,
    String fileName = 'suivi_scolaire.db',
    SqlLoader? loader,
    DatabaseFactory? factory,
  }) async {
    final load = loader ?? _bundleLoader;
    final f = factory ?? databaseFactory;
    final path = p.join(directory, fileName);
    await Directory(directory).create(recursive: true);
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kLatestSchemaVersion,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) => _migrate(d, 0, v, load),
        onUpgrade: (d, from, to) => _migrate(d, from, to, load),
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database d, int from, int to, SqlLoader load) async {
    for (final m in kMigrations.where((m) => m.version > from && m.version <= to)) {
      for (final stmt in splitStatements(await load(m.asset))) {
        await d.execute(stmt);
      }
    }
  }

  Future<void> close() => db.close();
}
