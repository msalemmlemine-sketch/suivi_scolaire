import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/institutions/institutions_page.dart';
import '../features/students/students_page.dart';
import '../features/more/more_page.dart';
import '../widgets/empty_state.dart';
import 'strings.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.db,
    required this.s,
    required this.designer,
    required this.version,
    required this.reportLanguage,
    required this.onSetUiLanguage,
    required this.onSetReportLanguage,
  });
  final Database db;
  final S s;
  final String designer, version;
  final String reportLanguage;
  final ValueChanged<String> onSetUiLanguage, onSetReportLanguage;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _rev = 0;

  Widget _comingSoon(IconData icon) =>
      EmptyState(icon: icon, title: widget.s.t('coming_title'), body: widget.s.t('coming_body'));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final titles = [s.t('app_title'), s.t('institutions'), s.t('students'), s.t('timetable'), s.t('more')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(index: _tab, children: [
        DashboardPage(db: widget.db, s: s, onOpenTab: (i) => setState(() => _tab = i)),
        InstitutionsPage(db: widget.db, s: s, onChanged: () => setState(() => _rev++)),
        StudentsPage(
          db: widget.db,
          s: s,
          revision: _rev,
          onGoInstitutions: () => setState(() => _tab = 1),
        ),
        _comingSoon(Icons.calendar_view_week_outlined),
        MorePage(
          s: s,
          designer: widget.designer,
          version: widget.version,
          reportLanguage: widget.reportLanguage,
          onSetUiLanguage: widget.onSetUiLanguage,
          onSetReportLanguage: widget.onSetReportLanguage,
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard), label: s.t('home')),
          NavigationDestination(icon: const Icon(Icons.account_balance_outlined), selectedIcon: const Icon(Icons.account_balance), label: s.t('institutions')),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: s.t('students')),
          NavigationDestination(icon: const Icon(Icons.calendar_view_week_outlined), selectedIcon: const Icon(Icons.calendar_view_week), label: s.t('timetable_short')),
          NavigationDestination(icon: const Icon(Icons.menu), label: s.t('more')),
        ],
      ),
    );
  }
}
