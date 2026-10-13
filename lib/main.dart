import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final adb = await AppDatabase.open(directory: dir.path);
  final rows = await adb.db.query('app_settings',
      columns: ['value'], where: 'key = ?', whereArgs: ['ui_language']);
  final lang = rows.isEmpty ? 'ar' : rows.first['value'] as String;
  runApp(SuiviApp(db: adb.db, initialLanguage: lang == 'fr' ? 'fr' : 'ar'));
}
