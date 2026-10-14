import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/institutions/institutions_page.dart';
import '../features/students/students_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/more/more_page.dart';
import '../features/followup/followup_page.dart';
import 'strings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.db, required this.s, required this.designer, required this.version, required this.onToggleLanguage});
  final Database db;
  final S s;
  final String designer, version;
  final VoidCallback onToggleLanguage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final titles = [s.t('app_title'), s.t('institutions'), s.t('students'), s.t('timetable'), s.t('more')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab], maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _tab, children: [
          DashboardPage(db: widget.db, s: s, onOpenTab: (i) => setState(() => _tab = i)),
          InstitutionsPage(db: widget.db, s: s),
          StudentsPage(db: widget.db, s: s),
          TimetablePage(db: widget.db, s: s),
          MorePage(
            db: widget.db, s: s, designer: widget.designer, version: widget.version,
            onToggleLanguage: widget.onToggleLanguage,
            onOpenFollowup: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar(title: Text(s.t('followup'))), body: FollowupPage(db: widget.db, s: s)),
            )),
          ),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: s.t('home')),
          NavigationDestination(icon: const Icon(Icons.account_balance_outlined), selectedIcon: const Icon(Icons.account_balance_rounded), label: s.t('institutions')),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups_rounded), label: s.t('students')),
          NavigationDestination(icon: const Icon(Icons.calendar_view_week_outlined), selectedIcon: const Icon(Icons.calendar_view_week_rounded), label: s.t('timetable')),
          NavigationDestination(icon: const Icon(Icons.tune_rounded), selectedIcon: const Icon(Icons.tune_rounded), label: s.t('more')),
        ],
      ),
    );
  }
}
