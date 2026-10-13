import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';

import 'app_shell.dart';
import 'strings.dart';
import 'theme.dart';

/// Change these two lines to change the credit shown in the app.
const String kDesignerName = 'MEDSALEM EBNOU OUMAR';
const String kAppVersion = '0.2.1';

class SuiviApp extends StatefulWidget {
  const SuiviApp({
    super.key,
    required this.db,
    required this.initialLanguage,
    this.initialReportLanguage = 'fr',
  });
  final Database db;
  final String initialLanguage, initialReportLanguage;

  @override
  State<SuiviApp> createState() => _SuiviAppState();
}

class _SuiviAppState extends State<SuiviApp> {
  late String _lang = widget.initialLanguage;

  late String _reportLang = widget.initialReportLanguage;

  Future<void> _saveSetting(String key, String value) => widget.db.insert(
        'app_settings',
        {'key': key, 'value': value, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // Only settings change; student data is never touched.
  Future<void> _setUiLanguage(String code) async {
    await _saveSetting('ui_language', code);
    if (mounted) setState(() => _lang = code);
  }

  Future<void> _setReportLanguage(String code) async {
    await _saveSetting('report_language', code);
    if (mounted) setState(() => _reportLang = code);
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
        reportLanguage: _reportLang,
        onSetUiLanguage: _setUiLanguage,
        onSetReportLanguage: _setReportLanguage,
      ),
    );
  }
}
