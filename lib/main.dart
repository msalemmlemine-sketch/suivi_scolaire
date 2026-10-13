import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final adb = await AppDatabase.open(directory: dir.path);
  Future<String?> setting(String key) async {
    final rows = await adb.db.query('app_settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  final ui = await setting('ui_language');
  final report = await setting('report_language');
  runApp(SuiviApp(
    db: adb.db,
    initialLanguage: ui == 'fr' ? 'fr' : 'ar',
    initialReportLanguage: report == 'ar' ? 'ar' : 'fr',
  ));
}
