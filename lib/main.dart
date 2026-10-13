import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/database/app_database.dart';

/// Phase 1-2 skeleton: opens the SQLite database (running migrations) and
/// shows the schema version. Real screens come in the next phases.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(directory: dir.path);
  final v = await db.db.getVersion();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: Text('Suivi Scolaire — DB v$v'))),
  ));
}
