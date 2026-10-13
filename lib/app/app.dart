import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';

import 'app_shell.dart';
import 'strings.dart';
import 'theme.dart';

/// Change these two lines to change the credit shown in the app.
const String kDesignerName = 'MEDSALEM EBNOU OUMAR';
const String kAppVersion = '0.6.0';

class SuiviApp extends StatefulWidget {
  const SuiviApp({super.key, required this.db, required this.initialLanguage});
  final Database db;
  final String initialLanguage;

  @override
  State<SuiviApp> createState() => _SuiviAppState();
}

class _SuiviAppState extends State<SuiviApp> {
  late String _lang = widget.initialLanguage;

  Future<void> _toggleLanguage() async {
    final next = _lang == 'ar' ? 'fr' : 'ar';
    // Only the UI setting changes; student data is never touched.
    await widget.db.update(
      'app_settings',
      {'value': next, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'key = ?',
      whereArgs: ['ui_language'],
    );
    if (mounted) setState(() => _lang = next);
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: s.t('app_title'),
      theme: buildTheme(),
      locale: Locale(_lang),
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(
        db: widget.db,
        s: s,
        designer: kDesignerName,
        version: kAppVersion,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }
}
